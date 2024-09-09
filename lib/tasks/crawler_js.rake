# lib/tasks/scraping.rake
namespace :scraping do
  desc "Scrape articles including metadata and content from a JS-rendered website"
  task crawler_js: :environment do
    require 'selenium-webdriver'
    require 'nokogiri'
    require 'open-uri'
    require 'webdrivers'
    
    # Configuración de Selenium con Chrome en modo Headless
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    # Inicializar el driver de Chrome
    driver = Selenium::WebDriver.for :chrome, options: options
    
    # URL del sitio que deseas scrapear
    url = 'https://delparaguay.com.py/nota/hincha-de-millonarios-murio-tras-someterse-a-la-eutanasia'
    puts url

    # Navegar a la página
    driver.navigate.to url
    
    # Esperar un tiempo para que la página cargue completamente
    sleep(10) # Ajusta el tiempo según lo necesario
    
    # Obtener el HTML renderizado
    html = driver.page_source
    puts html
    
    puts ''
    puts '------------------------------------------------------------------------------------'
    puts ''
    
    # Utilizar Nokogiri para analizar el HTML
    doc = Nokogiri::HTML(html)
    puts doc

    # Ejemplo: Extraer títulos de artículos
    doc.css('.titulo-articulo').each do |article|
      title = article.text.strip
      puts "Título: #{title}"
    end
    
    # Cerrar el navegador
    driver.quit
        
  end
end
