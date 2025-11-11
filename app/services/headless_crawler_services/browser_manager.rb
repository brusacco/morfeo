# frozen_string_literal: true

require 'httparty'
require 'uri'

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

    # Scrape.do proxy configuration
    PROXY_SERVER = 'proxy.scrape.do:8080'

    def initialize(use_proxy: false)
      @driver = nil
      @use_proxy = use_proxy
    end

    # Override self.call to support block passing
    def self.call(use_proxy: false, &block)
      new(use_proxy: use_proxy).call(&block)
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
      
      # Add proxy configuration if enabled
      if @use_proxy
        configure_proxy(options)
      end
      
      @driver = Selenium::WebDriver.for(:chrome, options: options)
      configure_timeouts
      
      proxy_status = @use_proxy ? " with scrape.do proxy" : ""
      Rails.logger.info("Chrome driver initialized successfully#{proxy_status}")
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

    def configure_proxy(options)
      token = ENV['SCRAPE_DO_API_TOKEN']
      
      unless token.present?
        Rails.logger.warn("SCRAPE_DO_API_TOKEN not found, proxy disabled")
        puts "⚠️  Warning: SCRAPE_DO_API_TOKEN not set, running without proxy"
        @use_proxy = false
        return
      end

      # Configure proxy using scrape.do
      proxy = Selenium::WebDriver::Proxy.new(
        http: "http://#{token}:@#{PROXY_SERVER}",
        ssl: "http://#{token}:@#{PROXY_SERVER}"
      )
      
      options.proxy = proxy
      Rails.logger.info("Proxy configured: #{PROXY_SERVER}")
      puts "🌐 Using scrape.do proxy (#{PROXY_SERVER})"
    rescue StandardError => e
      Rails.logger.error("Failed to configure proxy: #{e.message}")
      puts "❌ Failed to configure proxy: #{e.message}"
      @use_proxy = false
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
      # Navigate to URL with retry logic and Cloudflare bypass using scrape.do API
      def navigate_to(driver, url, retries: 3, wait_for_cloudflare: true, site: nil)
        attempt = 0
        begin
          attempt += 1
          driver.navigate.to(url)

          # Wait for page to stabilize
          sleep(STABILIZATION_WAIT)

          # Check if Cloudflare challenge is present
          if wait_for_cloudflare && cloudflare_detected?(driver)
            puts "\n🛡️  Cloudflare protection detected!"
            Rails.logger.info("Cloudflare challenge detected, switching to scrape.do API...")
            
            # Switch to scrape.do API to bypass Cloudflare
            if fetch_via_scrape_do_api(driver, url, site)
              puts "   ✓ Successfully bypassed Cloudflare using scrape.do API"
              Rails.logger.info("Successfully bypassed Cloudflare using scrape.do API")
              return true
            else
              puts "   ⚠️  WARNING: Could not bypass Cloudflare with scrape.do API"
              puts "   Site may require manual whitelisting or may be in 'Under Attack' mode"
              Rails.logger.warn("Failed to bypass Cloudflare with scrape.do API")
            end
          end

          true
        rescue Net::ReadTimeout, Selenium::WebDriver::Error::TimeoutError => e
          if attempt < retries
            Rails.logger.warn("Navigation timeout (attempt #{attempt}/#{retries}): #{url}")
            sleep(2 ** attempt) # Exponential backoff
            retry
          else
            # After all retries failed, try scrape.do API as fallback
            Rails.logger.warn("Navigation failed after #{retries} attempts, trying scrape.do API as fallback: #{url}")
            puts "\n⚠️  Navigation timeout after #{retries} attempts, switching to scrape.do API..."
            
            if fetch_via_scrape_do_api(driver, url, site)
              puts "   ✓ Successfully fetched via scrape.do API (timeout fallback)"
              Rails.logger.info("Successfully fetched via scrape.do API after timeout")
              return true
            else
              Rails.logger.error("Navigation failed after #{retries} attempts and scrape.do fallback: #{url}")
              raise
            end
          end
        rescue StandardError => e
          # For any other navigation error, try scrape.do API as fallback
          Rails.logger.warn("Navigation error, trying scrape.do API as fallback: #{e.message}")
          puts "\n⚠️  Navigation error, switching to scrape.do API..."
          
          if fetch_via_scrape_do_api(driver, url, site)
            puts "   ✓ Successfully fetched via scrape.do API (error fallback)"
            Rails.logger.info("Successfully fetched via scrape.do API after error")
            return true
          else
            Rails.logger.error("Navigation failed and scrape.do fallback also failed: #{url} - #{e.message}")
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

      # Fetch page via scrape.do API when Cloudflare is detected
      # Uses the same parameters as proxy_crawler for consistency
      def fetch_via_scrape_do_api(driver, url, site = nil)
        token = ENV['SCRAPE_DO_API_TOKEN']
        
        unless token.present?
          Rails.logger.warn("SCRAPE_DO_API_TOKEN not found, cannot use scrape.do API")
          return false
        end

        begin
          Rails.logger.info("Fetching via scrape.do API: #{url}")
          
          # Build scrape.do API URL with headless browser parameters
          # Same parameters as proxy_crawler for consistency
          params = {
            token: token,
            url: url,
            render: 'true',                    # Use headless browser (Chromium)
            blockResources: 'false',           # Don't block resources (helps avoid blocks)
            customWait: '2000',                # Wait 2 seconds for page to load
            waitUntil: 'networkidle2'          # Wait until max 2 network connections
          }
          
          # Add waitSelector if site has content_filter configured
          if site&.content_filter.present?
            params[:waitSelector] = site.content_filter
            Rails.logger.info("Using waitSelector: #{site.content_filter}")
          end
          
          api_url = "https://api.scrape.do?" + URI.encode_www_form(params)
          
          # Fetch via API
          response = HTTParty.get(api_url, timeout: 90)
          
          unless response.success?
            Rails.logger.error("scrape.do API returned HTTP #{response.code}")
            return false
          end
          
          # Inject HTML into driver's page source
          # This allows the rest of the code to work with Selenium as normal
          escaped_html = response.body.to_json
          driver.execute_script("document.open(); document.write(#{escaped_html}); document.close();")
          
          # Wait for page to stabilize
          sleep(STABILIZATION_WAIT)
          
          Rails.logger.info("Successfully fetched via scrape.do API (body size: #{response.body.size} bytes)")
          true
        rescue StandardError => e
          Rails.logger.error("Failed to fetch via scrape.do API: #{e.message}")
          Rails.logger.error(e.backtrace.first(5).join("\n"))
          false
        end
      end
    end
  end
end

