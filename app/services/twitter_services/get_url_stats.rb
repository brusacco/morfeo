# frozen_string_literal: true

module TwitterServices
  class GetUrlStats < ApplicationService
    def initialize(id)
      @entry_id = id
    end

    def call
      client =
        Twitter::REST::Client.new do |config|
          config.consumer_key = 'PhGZrGYL9VBxhMX3kD6WTQ'
          config.consumer_secret     = 'u3ZZJtHYvtxUprX9FuKf7A02CGf2YBa8qKN3yUWaegY'
          config.access_token        = '90261721-0dDKFNJzxuvuKGd7dDMonN5S2rHQJxs8HU2pedeQU'
          config.access_token_secret = 'LvGiOfdRGTsRxC4QLPN8Jl5AOId2wML8OJCgNQ46jsSeV'
        end

      entry = Entry.find(@entry_id)

      rt = 0
      fav = 0
      total = 0

      result = client.search("#{entry.url} -rt filter:links", result_type: 'recent', count: 100, tweet_mode: 'extended')
      result.attrs[:search_metadata][:next_results] = nil

      result.take(100).map do |tweet|
        rt += tweet.retweet_count
        fav += tweet.favorite_count
        total += rt + fav
      end

      data = { tw_rt: rt, tw_fav: fav, tw_total: total }
      handle_success(data)
    rescue StandardError => e
      handle_error(e.message)
    end
  end
end
