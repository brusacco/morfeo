ENV["ELASTICSEARCH_URL"] = "https://localhost:9200" if Rails.env.development?
ENV["ELASTICSEARCH_URL"] = "https://74.222.1.105/:9200" if Rails.env.production?