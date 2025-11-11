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
      options.add_argument('--headless')
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
      
      # User agent to avoid detection
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
      # Navigate to URL with retry logic
      def navigate_to(driver, url, retries: 3)
        attempt = 0
        begin
          attempt += 1
          driver.navigate.to(url)
          sleep(STABILIZATION_WAIT) # Wait for page to stabilize
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
    end
  end
end

