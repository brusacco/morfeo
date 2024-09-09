namespace :scraping do
  desc "Scrape a web page using Chrome Headless"
  task headless_crawler: :environment do
    require 'selenium-webdriver'
    require 'webdrivers'

    # Configuración de Selenium con Chrome en modo Headless
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    # Inicializar el driver de Chrome
    driver = Selenium::WebDriver.for :chrome, options: options

    # URL de la web a scrapear
    url = 'https://delparaguay.com.py/'
    driver.navigate.to url

    # Esperar a que la página se cargue completamente (si es necesario)
    sleep 30 # Ajusta el tiempo de espera según la página

    # Obtener el contenido de la página
    content = driver.page_source

    # Procesar el contenido (por ejemplo, guardar en un archivo)
    File.write('scraped_content.html', content)

    # Cerrar el navegador
    driver.quit

    puts "Scraping complete. Content saved to scraped_content.html."
  end
end
