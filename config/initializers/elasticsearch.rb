ENV["ELASTICSEARCH_URL"] = "http://localhost:9200" if Rails.env.development?
ENV["ELASTICSEARCH_URL"] = "http://74.222.1.105/:9200" if Rails.env.production?