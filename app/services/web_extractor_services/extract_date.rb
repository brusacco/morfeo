# frozen_string_literal: true

module WebExtractorServices
  class ExtractDate < ApplicationService
    def initialize(doc)
      @doc = doc
      @parsed = false
      @date = nil
    end

    def call
      if @doc.at('meta[property="article:published_time"]')
        @date = @doc.at('meta[property="article:published_time"]')[:content]
        @parsed = true
      elsif @doc.at('meta[property="article:modified_time"]') && @date.nil?
        @date = @doc.at('meta[property="article:modified_time"]')[:content]
        @parsed = true
      elsif @doc.at('script[type="application/ld+json"]') && @date.nil?
        @date = date_from_ld(@doc.at('script[type="application/ld+json"]').text)
        @parsed = true
      elsif @doc.at_css('.entry-date') && @date.nil?
        @date = @doc.at_css('.entry-date')[:datetime]
        @parsed = false
      elsif @doc.at_css('time.date') && @date.nil?
        @date = @doc.at_css('time.date').text
        @parsed = false
      elsif @doc.at_css('.date') && @date.nil?
        @date = @doc.at_css('.date').text
        @parsed = false
      elsif @doc.at_css('time') && @date.nil?
        @date = @doc.at_css('time')[:datetime]
        @parsed = true
      elsif @doc.at_css('#fusion-app > div > section.sec-m.container > div > article > header > div.bl > div.dt') && @date.nil?
        @date = @doc.at_css('#fusion-app > div > section.sec-m.container > div > article > header > div.bl > div.dt').text
        @parsed = false
      elsif @doc.at_css('#container > section > div > div > div.col-sm-8 > div > div > div.title-post > ul > li:nth-child(1)') && @date.nil?
        @date = @doc.at_css('#container > section > div > div > div.col-sm-8 > div > div > div.title-post > ul > li:nth-child(1)').text
        @parsed = false
      elsif @doc.at('.publish-date') && @date.nil?
        @date = @doc.at('.publish-date').text
        @parsed = false
      elsif @doc.at('.Leer_cat') && @date.nil?
        @date = @doc.at('.Leer_cat').text
        @parsed = false
      elsif @doc.at('.NotasFecha') && @date.nil?
        @date = @doc.at('.NotasFecha').text
        @parsed = false
      elsif @doc.at('.post-date') && @date.nil?
        @date = @doc.at('.post-date').text
        @parsed = false
      elsif @doc.at('.LeerNoticiasTopFecha') && @date.nil?
        @date = @doc.at('.LeerNoticiasTopFecha').text
        @parsed = false
      elsif @doc.at('.mono-caps-condensed--md') && @date.nil?
        @date = @doc.at('.mono-caps-condensed--md').text
        @parsed = false
      elsif @doc.at('.fecha_detalle') && @date.nil?
        @date = @doc.at('.fecha_detalle').text
        @parsed = false
      elsif @doc.at('.title-post li:nth-child(1)') && @date.nil?
        @date = @doc.at('.title-post li:nth-child(1)').text
        @parsed = false
      elsif @doc.at('.Leer_img+ .Leer_redes') && @date.nil?
        @date = @doc.at('.Leer_img+ .Leer_redes').text
        @parsed = false
      elsif @doc.at('.news_category_and_date') && @date.nil?
        @date = @doc.at('.news_category_and_date').text
        @parsed = false
      elsif @doc.at('.conteindo__texto p:nth-child(1)') && @date.nil?
        @date = @doc.at('.conteindo__texto p:nth-child(1)').text
        @parsed = false
      else
        @date = nil
      end

      if @date.nil?
        handle_error('Fecha no encontrada')
      else
        unless @parsed
          @date = translate_crawled_date(@date)
          @date = Chronic.parse(@date, endian_precedence: :little)
        end
        handle_success({ published_at: @date })
      end
    end

    #------------------------------------------------------------------------------------
    # Parse ld+json data
    #------------------------------------------------------------------------------------
    def date_from_ld(json_ld)
      data = JSON.parse(json_ld)
      find_key(data, 'datePublished')
    end

    #------------------------------------------------------------------------------------
    # Fins a key in a JSON structure at any level
    #------------------------------------------------------------------------------------
    def find_key(data, key)
      case data
      when Array
        data.each do |item|
          result = find_key(item, key)
          return result if result
        end
      when Hash
        return data[key] if data.key?(key)

        data.each_value do |value|
          result = find_key(value, key)
          return result if result
        end
      end
      nil
    end

    #------------------------------------------------------------------------------------
    # TRANSLATE DATESs
    #------------------------------------------------------------------------------------
    def translate_crawled_date(date)
      date.strip!
      date.gsub!('Fecha de publicacion:', '')
      date.gsub!('Publicado /', '')
      date.gsub!(/de enero|enero|ene/i, 'January')
      date.gsub!(/de febrero|febrero|feb/i, 'February')
      date.gsub!(/de marzo|marzo|mar/i, 'March')
      date.gsub!(/de abril|abril|abr/i, 'April')
      date.gsub!(/de mayo|mayo|may/i, 'May')
      date.gsub!(/de junio|junio|jun/i, 'Jun')
      date.gsub!(/de julio|julio|kul/i, 'July')
      date.gsub!(/de agosto|agosto|ago/i, 'August')
      date.gsub!(/de septiembre|septiembre|sep/i, 'September')
      date.gsub!(/de octubre|octubre|oct/i, 'October')
      date.gsub!(/de noviembre|noviembre|nov/i, 'November')
      date.gsub!(/de diciembre|diciembre|dic/i, 'December')
      date.gsub!(' de ', ' of ')
      date.gsub!(' del ', ' of ')
      date.gsub!(/Hace/i, '')
      date.gsub!(/semanas/i, 'weeks ago')
      date.gsub!(/semana/i, 'week ago')
      date.gsub!(/horas/i, 'hours ago')
      date.gsub!(/horas/i, 'hours ago')
      date.gsub!(/días/i, 'days ago')
      date.gsub!(/día/i, 'day ago')
      date.gsub!(/min/i, 'minutes ago')
      date.gsub!(' - ', ' ')
      date
    end
  end
end
