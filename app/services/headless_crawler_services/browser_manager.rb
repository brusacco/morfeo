# frozen_string_literal: true

module HeadlessCrawlerServices
  # Manages Selenium WebDriver lifecycle and configuration
  # Handles browser initialization, timeout configuration, and cleanup
  #
  # NOTE: This service uses a custom call pattern to support blocks
  class BrowserManager
    # Browser timeouts (in seconds)
    PAGE_LOAD_TIMEOUT = 30
    SCRIPT_TIMEOUT = 30
    IMPLICIT_WAIT = 5

    # Page stabilization wait (in seconds)
    STABILIZATION_WAIT = 3

    def initialize
      @driver = nil
    end

    # Override self.call to support block passing
    def self.call(&block)
      new.call(&block)
    end

    def call(&block)
      Rails.logger.info("BrowserManager: Starting initialization")
      initialize_driver
      Rails.logger.info("BrowserManager: Driver initialized, yielding to block")

      if block
        block.call(@driver)
        Rails.logger.info("BrowserManager: Block execution completed")
      else
        Rails.logger.warn("BrowserManager: No block given!")
      end

      OpenStruct.new(success?: true, driver: @driver)
    rescue StandardError => e
      puts "\n❌ BrowserManager error: #{e.message}"
      puts "Backtrace:"
      puts e.backtrace.first(10).join("\n")

      Rails.logger.error("BrowserManager error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      OpenStruct.new(success?: false, error: e.message)
    ensure
      cleanup_driver
    end

    private

    def initialize_driver
      options = build_chrome_options
      @driver = Selenium::WebDriver.for(:chrome, options: options)
      configure_timeouts
      Rails.logger.info("Chrome driver initialized successfully")
    end

    def build_chrome_options
      options = Selenium::WebDriver::Chrome::Options.new

      # Performance and stability arguments
      options.add_argument('--headless=new')  # Use new headless mode (less detectable)
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--disable-gpu')
      options.add_argument('--disable-prompt-on-repost')
      options.add_argument('--ignore-certificate-errors')
      options.add_argument('--disable-popup-blocking')
      options.add_argument('--disable-translate')
      options.add_argument('--disable-blink-features=AutomationControlled')
      options.add_argument('--disable-extensions')
      options.add_argument('--dns-prefetch-disable')
      options.add_argument('--disable-web-security')
      options.add_argument('--disable-features=IsolateOrigins,site-per-process')
      options.add_argument('--window-size=1920,1080')

      # Anti-detection: Remove navigator.webdriver flag
      options.add_argument('--disable-blink-features=AutomationControlled')
      options.add_preference('excludeSwitches', ['enable-automation'])
      options.add_preference('useAutomationExtension', false)

      # User agent to avoid detection (real Chrome on Windows)
      user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' \
                   '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      options.add_argument("--user-agent=#{user_agent}")

      options
    end

    def configure_timeouts
      # Set page load timeout to prevent hanging
      @driver.manage.timeouts.page_load = PAGE_LOAD_TIMEOUT

      # Set script timeout for JavaScript execution
      @driver.manage.timeouts.script_timeout = SCRIPT_TIMEOUT

      # Set implicit wait for element finding
      @driver.manage.timeouts.implicit_wait = IMPLICIT_WAIT

      # Remove webdriver property to avoid Cloudflare detection
      @driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    rescue StandardError => e
      Rails.logger.warn("Could not remove webdriver property: #{e.message}")
    end

    def cleanup_driver
      return unless @driver

      @driver.quit
      Rails.logger.info("Chrome driver closed successfully")
    rescue StandardError => e
      Rails.logger.error("Error closing driver: #{e.message}")
    ensure
      @driver = nil
    end

    class << self
      # Navigate to URL with retry logic and Cloudflare bypass waiting
      def navigate_to(driver, url, retries: 3, wait_for_cloudflare: true)
        attempt = 0
        begin
          attempt += 1
          driver.navigate.to(url)

          # Wait for page to stabilize
          sleep(STABILIZATION_WAIT)

          # Check if Cloudflare challenge is present and wait if needed
          if wait_for_cloudflare && cloudflare_detected?(driver)
            puts "\n🛡️  Cloudflare protection detected!"
            Rails.logger.info("Cloudflare challenge detected, waiting...")

            unless wait_for_cloudflare_clearance(driver)
              puts "   ⚠️  WARNING: Could not bypass Cloudflare automatically"
              puts "   Site may require manual whitelisting or may be in 'Under Attack' mode"
            end
          end

          true
        rescue Net::ReadTimeout, Selenium::WebDriver::Error::TimeoutError => e
          if attempt < retries
            Rails.logger.warn("Navigation timeout (attempt #{attempt}/#{retries}): #{url}")
            sleep(2 ** attempt) # Exponential backoff
            retry
          else
            Rails.logger.error("Navigation failed after #{retries} attempts: #{url}")
            raise
          end
        end
      end

      private

      def cloudflare_detected?(driver)
        # Check for common Cloudflare challenge indicators
        page_source = driver.page_source
        page_source.include?('Checking your browser') ||
        page_source.include?('cloudflare') ||
        page_source.include?('cf-browser-verification')
      rescue StandardError
        false
      end

      def wait_for_cloudflare_clearance(driver, max_wait: 30)
        # Wait up to max_wait seconds for Cloudflare to clear
        puts "   ⏳ Waiting for Cloudflare (max #{max_wait}s)..."

        max_wait.times do |i|
          sleep(1)

          unless cloudflare_detected?(driver)
            puts "   ✓ Cloudflare cleared after #{i + 1}s"
            Rails.logger.info("Cloudflare cleared after #{i + 1}s")
            return true
          end

          # Show progress every 5 seconds
          if (i + 1) % 5 == 0
            puts "   ... still waiting (#{i + 1}s elapsed)"
          end
        end

        puts "   ✗ Cloudflare challenge still present after #{max_wait}s"
        Rails.logger.warn("Cloudflare challenge still present after #{max_wait}s")
        false
      end
    end
  end
end

