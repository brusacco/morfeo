# frozen_string_literal: true

if Rails.env.production?
  ENV['ELASTICSEARCH_URL'] = "http://elastic:7TXB9YP5h6aJn8KrGA8V@morfero.com.py:9200"
elsif Rails.env.development?
  ENV['ELASTICSEARCH_URL'] = 'http://localhost:9200'
end
