# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :authenticate_user!, except: :deploy
  skip_before_action :verify_authenticity_token

  def index
    @sites = Site.where(total_count: 1..).order(total_count: :desc)
    @entries = Entry.includes(:site).order(published_at: :desc).limit(100)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    @tags = @tags.select { |tag| tag.count > 1 }

    @tags_interactions = {}
    @tags.each do |tag|
      @entries.each do |entry|
        tag.interactions ||= 0
        tag.interactions += entry.total_count if entry.tag_list.include?(tag.name)

        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.total_count if entry.tag_list.include?(tag.name)
      end
    end

    @tags_interactions = @tags_interactions.select { |_k, v| v > 1 }
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
      system('export RAILS_ENV=production')

      # Check out the latest code from the Git repository
      system('git pull')

      # Install dependencies
      system('bundle install')

      # Migrate the database
      system('RAILS_ENV=production rails db:migrate')

      # Precompile assets
      system('RAILS_ENV=production rake assets:precompile')

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
