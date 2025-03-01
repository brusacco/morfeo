Grover.configure do |config|
  config.options = {
    format: 'A4',
    margin: {
      top: '1cm',
      bottom: '1cm',
      left: '1cm',
      right: '1cm'
    },
    user_agent: 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0',
    display_url: Rails.application.routes.default_url_options[:host] || 'http://localhost:6500',
    # launch_options: {
    #   args: ['--no-sandbox', '--disable-setuid-sandbox']
    # },    
    # viewport: {
    #   width: 640,
    #   height: 480
    # },
    # prefer_css_page_size: true,
    emulate_media: 'screen',
    # bypass_csp: true,
    # media_features: [{ name: 'prefers-color-scheme', value: 'dark' }],
    # timezone: 'America/Asuncion',
    # vision_deficiency: 'deuteranopia',
    # extra_http_headers: { 'Accept-Language': 'es-ES' },
    # focus: '#some-element',
    # hover: '#another-element',
    cache: false,
    print_background: true,
    # timeout: 0, # Timeout in ms. A value of `0` means 'no timeout'
    # request_timeout: 5000, # Timeout when fetching the content (overloads the `timeout` option)
    # convert_timeout: 10000, # Timeout when converting the content (overloads the `timeout` option, only applies to PDF conversion)
    # launch_args: ['--font-render-hinting=medium'],
    # wait_until: 'domcontentloaded'
  }
end