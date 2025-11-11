# frozen_string_literal: true

module ProxyCrawlerServices
  # Handles HTTP requests through scrape.do proxy service
  # Manages retries, timeouts, and error handling
  class ProxyClient
    MAX_RETRIES = 3
    BASE_DELAY = 2 # seconds
    REQUEST_TIMEOUT = 90 # seconds (increased for JS rendering)
    
    class ProxyRequestError < StandardError; end
    
    def initialize
      @api_token = fetch_api_token
      validate_token!
    end
    
    # Fetch URL through proxy with retry logic
    # @param url [String] Target URL to fetch
    # @param wait_selector [String, nil] Optional CSS selector to wait for (e.g., '.article-content')
    def fetch(url, wait_selector: nil)
      api_url = build_api_url(url, wait_selector: wait_selector)
      last_error = nil
      last_code = nil
      
      Rails.logger.info("ProxyClient: Starting fetch for #{url}")
      Rails.logger.debug("ProxyClient: API URL: #{api_url.gsub(@api_token, 'TOKEN_HIDDEN')}")
      
      MAX_RETRIES.times do |attempt|
        begin
          Rails.logger.info("ProxyClient: Attempt #{attempt + 1}/#{MAX_RETRIES}")
          response = HTTParty.get(api_url, timeout: REQUEST_TIMEOUT)
          last_code = response.code
          
          if response.code == 200
            Rails.logger.info("ProxyClient: Success! Status #{response.code}, Body size: #{response.body.size} bytes")
            return OpenStruct.new(success?: true, body: response.body, code: response.code)
          end
          
          # Log non-200 responses with body preview
          body_preview = response.body[0..200] rescue "N/A"
          Rails.logger.warn("ProxyClient: Status #{response.code} (attempt #{attempt + 1}/#{MAX_RETRIES})")
          Rails.logger.warn("ProxyClient: Response preview: #{body_preview}")
          last_error = "HTTP #{response.code}: #{body_preview}"
          
          # Exponential backoff before retry
          sleep_time = BASE_DELAY ** attempt
          Rails.logger.info("ProxyClient: Waiting #{sleep_time}s before retry...")
          sleep(sleep_time) unless attempt == MAX_RETRIES - 1
          
        rescue Net::ReadTimeout => e
          last_error = "Timeout after #{REQUEST_TIMEOUT}s: #{e.message}"
          Rails.logger.error("ProxyClient: #{last_error} (attempt #{attempt + 1}/#{MAX_RETRIES})")
          
          sleep_time = BASE_DELAY ** attempt
          sleep(sleep_time) unless attempt == MAX_RETRIES - 1
          
        rescue StandardError => e
          last_error = "#{e.class}: #{e.message}"
          Rails.logger.error("ProxyClient: #{last_error} (attempt #{attempt + 1}/#{MAX_RETRIES})")
          Rails.logger.error("ProxyClient: Backtrace: #{e.backtrace.first(3).join(', ')}")
          
          # Retry on network errors
          sleep_time = BASE_DELAY ** attempt
          sleep(sleep_time) unless attempt == MAX_RETRIES - 1
        end
      end
      
      # All retries failed
      error_msg = "Failed after #{MAX_RETRIES} attempts. Last error: #{last_error}"
      error_msg += " (HTTP #{last_code})" if last_code
      Rails.logger.error("ProxyClient: #{error_msg}")
      OpenStruct.new(success?: false, error: error_msg, code: last_code)
    end
    
    private
    
    def fetch_api_token
      # Read from environment variable (recommended)
      token = ENV['SCRAPE_DO_API_TOKEN']
      
      # Fallback to Rails credentials if ENV not set
      token ||= Rails.application.credentials.dig(:scrape_do, :api_token) rescue nil
      
      # Last resort: hardcoded (only for development)
      token ||= 'ed138ed418924138923ced2b81e04d53' if Rails.env.development?
      
      token
    end
    
    def validate_token!
      return if @api_token.present?
      
      raise ProxyRequestError, 
            "Scrape.do API token not found. Set SCRAPE_DO_API_TOKEN environment variable"
    end
    
    def build_api_url(target_url, wait_selector: nil)
      # Build API URL with scrape.do's headless browser parameters
      # Documentation: https://www.scrape.do/docs/
      #
      # Headless Browser Configuration:
      # - render=true: Use headless browser (Chromium) to render JavaScript
      # - blockResources=false: Don't block resources (helps avoid blocks)
      # - customWait=2000: Wait 2 seconds for page to load (customizable)
      # - waitUntil=networkidle2: Wait until max 2 network connections
      # - waitSelector: (optional) Wait for specific element to appear
      params = {
        token: @api_token,
        url: target_url,
        render: 'true',                    # Use headless browser network
        blockResources: 'false',          # Don't block resources (helps avoid blocks)
        customWait: '2000',                # Wait 2 seconds for page to load
        waitUntil: 'networkidle2'          # Wait until max 2 network connections
      }
      
      # Add waitSelector if provided (wait for specific element)
      params[:waitSelector] = wait_selector if wait_selector.present?
      
      # waitUntil options:
      # - domcontentloaded: DOM parsed (fast, default)
      # - networkidle2: Max 2 connections for 500ms (good for dynamic content)
      # - networkidle0: No connections for 500ms (slowest, most complete)
      # - load: All resources loaded (images, CSS, JS)
      
      "https://api.scrape.do?" + URI.encode_www_form(params)
    end
  end
end

