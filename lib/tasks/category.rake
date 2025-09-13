# frozen_string_literal: true

desc 'Update categories for entries based on site content'
task category: :environment do
  # ENTRENAMOS EL CLASIFICADOR CON SITIOS NECOGIOS
  Site.where(id: [89, 127, 72]).each do |site| # 5Dias, Revista Plus, MarketData
    puts "#{site.name} - #{site.url}"
    puts '----------------------------------------------------------------------'

    site.entries.where(category: nil).limit(10_000).order("created_at DESC").find_each do |entry|
      puts "NEGOCIOS #{entry.url}"
      entry.update_attribute(:category, 'NEGOCIOS') if entry.category.nil?
    end
  end

  # ENTRENAMOS EL CLASIFICADOR CON SITIOS ESPECTACULOS
  Site.where(id: [84, 129]).each do |site| # Epa, TeleShow
    puts "#{site.name} - #{site.url}"
    puts '----------------------------------------------------------------------'

    site.entries.where(category: nil).limit(10_000).order('created_at DESC').find_each do |entry|
      begin
        puts "ESPECTACULOS #{entry.url}"
        entry.update_attribute(:category, 'ESPECTACULOS') if entry.category.nil?
      rescue
        next
      end
    end
  end

  # ENTRENAMOS EL CLASIFICADOR CON SITIOS DEPORTES
  Site.where(id: [65, 110, 61]).each do |site| # D10, APF, Versus. Obs.: Tigo Sports ya no trackeamos (id 13 en Moopio)
    puts "#{site.name} - #{site.url}"
    puts '----------------------------------------------------------------------'

    site.entries.where(category: nil).limit(10_000).order('created_at DESC').find_each do |entry|
      begin
        puts "DEPORTES " + entry.url
        entry.update_attribute(:category, 'DEPORTES') if entry.category.nil?
      rescue
        next
      end
    end
  end

  # ENTRENAMOS EL CLASIFICADOR CON SITIOS JUDICIALES
  Site.where(id: [133]).each do |site| # Judiciales Paraguay. Obs.: Corte Suprema ya no trackeamos (id 119 en Moopio)
    puts "#{site.name} - #{site.url}"
    puts '----------------------------------------------------------------------'

    site.entries.where(category: nil).limit(10_000).order('created_at DESC').find_each do |entry|
      begin
        puts "JUDICIALES " + entry.url
        entry.update_attribute(:category, 'JUDICIALES') if entry.category.nil?
      rescue
        next
      end
    end
  end

  Site.where(id: [55, 54, 52, 58, 106, 76, 100, 59, 74, 69, 81, 68, 63, 66, 77, 123, 99]).each do |site|
    # Diario Extra, Diario HOY, ABC, La Nación, Paraguay.com, SNT, Mas Encarnacion, C9N, Amambay News, Radio Monumental, CdeHot, Red Chaqueña, NPY, Trece, Unicanal, El Poder, La Tribuna.

    puts "MASS UPDATE: #{site.name} - #{site.url}"
    puts '----------------------------------------------------------------------'

    # Define a mapping of URL patterns to categories
    category_mappings = {
      'JUDICIALES' => ['/judiciales/', '/judiciales-y-policiales/'],
      'NEGOCIOS' => ['/negocios/', '/economia/'],
      'POLITICA' => ['/politica/'],
      'DEPORTES' => ['/deportes/', '/deporte/', '/futbol/', '/tenis/'],
      'NACIONALES' => [
        '/nacionales/',
        '/pais/',
        '/actualidad/',
        '/interior/',
        '/locales/',
        '/chaco/'
      ],
      'ESPECTACULOS' => [
        '/espectaculos/',
        '/lnpop/',
        '/artes-espectaculos/',
        '/teatro/',
        '/musica/',
        '/fama/',
        '/cultural/'
      ],
      'INTERNACIONALES' => ['/internacionales/', '/mundo/']
    }

    # Iterate over each category and its URL patterns to update entries in bulk
    category_mappings.each do |category, patterns|
      patterns.each do |pattern|
        puts "MASS UPDATE: #{site.name} - #{site.url} - #{pattern}"
        # Find entries with URLs that include the pattern and have a nil category
        site.entries.where('url LIKE ? AND category IS NULL', "%#{pattern}%").update_all(category: category)
      end
    end
    puts '----------------------------------------------------------------------'
  end
end
