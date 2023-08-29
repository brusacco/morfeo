# frozen_string_literal: true

if Rails.env.production?
  ENV['ELASTICSEARCH_URL'] = 'http://http://74.222.1.105:9200'
elsif Rails.env.development?
  ENV['ELASTICSEARCH_URL'] = 'http://localhost:9200'
end
