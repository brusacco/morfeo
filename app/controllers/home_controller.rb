# frozen_string_literal: true

class HomeController < ApplicationController
  # caches_action :index, expires_in: 1.hour
  before_action :authenticate_user!, except: :deploy
  skip_before_action :verify_authenticity_token

  def index
    # Chart Multiple Interacciones x DIA x TOPICO
    @interacciones_dia_topico = @topicos.map do |topic|
      {
        name: topic.name,
        data: topic.topic_stat_dailies.group_by_day(:topic_date).sum(:total_count)
      }
    end

    @notas_dia_topico = @topicos.map do |topic|
      {
        name: topic.name,
        data: topic.topic_stat_dailies.group_by_day(:topic_date).sum(:entry_count)
      }
    end

    @interacciones_ultimo_dia_topico = @topicos.joins(:topic_stat_dailies)
                                      .where(topic_stat_dailies: { topic_date: 1.day.ago.. })
                                      .group('topics.name').order('sum_topic_stat_dailies_total_count DESC').limit(10)
                                      .sum('topic_stat_dailies.total_count')

    @notas_ultimo_dia_topico = @topicos.joins(:topic_stat_dailies)
                                      .where(topic_stat_dailies: { topic_date: 1.day.ago.. })
                                      .group('topics.name').order('sum_topic_stat_dailies_entry_count DESC').limit(10)
                                      .sum('topic_stat_dailies.entry_count')

    # Tags Cloud
    tags_list = []
    @topicos.each do |topic|
      tags_list << topic.tags.map(&:name)
    end

    @topics_entries = Entry.order(published_at: :desc).limit(100).tagged_with(tags_list.flatten.join(", "), any: true)
    @tags_cloud = @topics_entries.tag_counts_on(:tags).order(count: :desc)
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
    Dir.chdir('/home/rails/morfeo') do
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
