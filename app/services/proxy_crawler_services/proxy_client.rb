# frozen_string_literal: true

module ProxyCrawlerServices
  # Handles HTTP requests through scrape.do proxy service
  # Manages retries, timeouts, and error handling
  class ProxyClient
    MAX_RETRIES = 3
    BASE_DELAY = 2 # seconds
    REQUEST_TIMEOUT = 60 # seconds
    
    class ProxyRequestError < StandardError; end
    
    def initialize
      @api_token = fetch_api_token
      validate_token!
    end
    
    # Fetch URL through proxy with retry logic
    def fetch(url)
      api_url = build_api_url(url)
      
      MAX_RETRIES.times do |attempt|
        begin
          response = HTTParty.get(api_url, timeout: REQUEST_TIMEOUT)
          
          if response.code == 200
            Rails.logger.info("Proxy request successful: #{url}")
            return OpenStruct.new(success?: true, body: response.body, code: response.code)
          end
          
          Rails.logger.warn("Proxy request returned #{response.code} (attempt #{attempt + 1}/#{MAX_RETRIES})")
          
          # Exponential backoff before retry
          sleep(BASE_DELAY ** attempt) unless attempt == MAX_RETRIES - 1
        rescue StandardError => e
          Rails.logger.error("Proxy request error (attempt #{attempt + 1}/#{MAX_RETRIES}): #{e.message}")
          
          # Retry on network errors
          sleep(BASE_DELAY ** attempt) unless attempt == MAX_RETRIES - 1
        end
      end
      
      # All retries failed
      error_msg = "Proxy request failed after #{MAX_RETRIES} attempts: #{url}"
      Rails.logger.error(error_msg)
      OpenStruct.new(success?: false, error: error_msg, code: nil)
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
    
    def build_api_url(target_url)
      # Use HTTPS for security
      "https://api.scrape.do?token=#{@api_token}&url=#{CGI.escape(target_url)}&render=True"
    end
  end
end

