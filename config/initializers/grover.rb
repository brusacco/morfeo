if defined?(Grover)
  Grover.configure do |config|
    config.options = {
      format: 'A4',
      margin: {
        top: '2.5cm',
        bottom: '2.5cm',
        left: '2cm',
        right: '2cm'
      },
      user_agent: 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0',
      display_url: Rails.application.routes.default_url_options[:host] || 'http://localhost:6500',
      
      # Professional PDF settings for CEO-level reports
      prefer_css_page_size: true,
      emulate_media: 'screen',
      print_background: true,
      
      # Quality settings for professional output
      scale: 1.0,
      display_header_footer: false, # Using custom headers/footers in HTML
      
      # Font rendering optimization
      launch_args: [
        '--font-render-hinting=medium',
        '--enable-font-antialiasing',
        '--disable-font-subpixel-positioning'
      ],
      
      # Performance and reliability
      cache: false,
      timeout: 60000, # 60 seconds for complex reports with charts
      request_timeout: 30000,
      convert_timeout: 30000,
      
      # Wait for all resources to load (especially charts)
      wait_until: 'networkidle0',
      
      # Language settings
      extra_http_headers: { 
        'Accept-Language': 'es-ES,es;q=0.9'
      }
    }
  end
end
