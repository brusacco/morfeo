# frozen_string_literal: true

class HomeController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    @tag_interacions = []
    @sites = Site.where(total_count: 1..).order(total_count: :desc)
    # @entries = Entry.has_interactions.has_image.includes(:site).order(published_at: :desc).limit(300)
    @entries = Entry.has_image.includes(:site).order(published_at: :desc).limit(300)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    # Sets counters and values
    @tags_interactions = Rails.cache.read("tags_interactions")

    # Cache tags interactions
    if @tags_interactions.nil?
      @tags_interactions = {}
      @tags.each do |tag|
        @entries.each do |entry|
          tag.interactions ||= 0
          tag.interactions += entry.total_count if entry.tag_list.include?(tag.name)

          @tags_interactions[tag.name] ||= 0
          @tags_interactions[tag.name] += entry.total_count if entry.tag_list.include?(tag.name)
        end
      end
      Rails.cache.write("tags_interactions", @tags_interactions, expires_in: 1.hour)
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
    @tags_interactions.reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end

  def topic
    tags = 'Horacio Cartes, santiago Peña'
    @entries = Entries.tagged_with(tags).limit(250)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    # Sets counters and values
    @tags_interactions = {}
    @tags.each do |tag|
      @entries.each do |entry|
        tag.interactions ||= 0
        tag.interactions += entry.total_count if entry.tag_list.include?(tag.name)

        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.total_count if entry.tag_list.include?(tag.name)
      end
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
    @tags_interactions.reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end

  def deploy
    Dir.chdir('/home/morfeo') do
      # Check out the latest code from the Git repository
      system('git pull')

      # Install dependencies
      system('bundle install')

      # Migrate the database
      system('RAILS_ENV=development rails db:migrate')

      # Restart the Puma server
      system('touch tmp/restart.txt')
    end

    render plain: 'Deployment complete!'
  end

  def check
    @url = params[:url]
    @doc = Nokogiri::HTML(URI.parse(@url).open)
    @result = WebExtractorServices::ExtractDate.call(@doc)
  end
end
