# frozen_string_literal: true

class TwitterTopicController < ApplicationController
  before_action :authenticate_user!
  before_action :set_topic
  before_action :authorize_topic!

  def show
    @tag_list = @topic.tags.pluck(:name)
    @posts = TwitterPost.for_topic(@topic)
    @chart_posts = TwitterPost.grouped_counts(@posts)
    @chart_interactions = TwitterPost.grouped_interactions(@posts)

    @total_posts = @posts.size
    @total_interactions = TwitterPost.total_interactions(@posts)
    @total_views = TwitterPost.total_views(@posts)
    @average_interactions = @total_posts.zero? ? 0 : (Float(@total_interactions) / @total_posts).round(1)

    @top_posts = @posts.sort_by(&:total_interactions).reverse.first(12)

    @word_occurrences = TwitterPost.word_occurrences(@posts)
    @bigram_occurrences = TwitterPost.bigram_occurrences(@posts)

    @tag_counts = @posts.tag_counts_on(:tags).order('count desc').limit(20)

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    tag_interaction_totals = Hash.new(0)
    @posts.includes(:tags).each do |post|
      post.tags.each do |tag|
        tag_interaction_totals[tag.name] += post.total_interactions
      end
    end
    @tag_interactions = tag_interaction_totals.sort_by { |_, value| -value }
                                              .to_h

    profiles_group =
      @posts.includes(twitter_profile: :site).group_by do |post|
        post.twitter_profile&.name || 'Sin perfil'
      end
    @profiles_count = profiles_group.transform_values(&:size).sort_by { |_, count| -count }
                                    .to_h
    @profiles_interactions = profiles_group.transform_values { |posts| posts.sum(&:total_interactions) }
                                           .sort_by { |_, value| -value }
                                           .to_h

    # Site data for media analysis
    @site_top_counts = @posts.joins(twitter_profile: :site).reorder(nil).group('sites.id').order(Arel.sql('COUNT(*) DESC')).limit(12).count
    @site_counts = @posts.joins(twitter_profile: :site).reorder(nil).group('sites.name').count
    @site_sums = @posts.joins(twitter_profile: :site).reorder(nil).group('sites.name').sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count'))
  end

  def entries_data
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    posts = TwitterPost.for_topic(@topic, start_time: date.beginning_of_day, end_time: date.end_of_day)

    render partial: 'twitter_topic/chart_entries', locals: { posts:, entries_date: date, topic_name: @topic.name }
  end

  def pdf
    @tag_list = @topic.tags.pluck(:name)
    @posts = TwitterPost.for_topic(@topic)
    @chart_posts = TwitterPost.grouped_counts(@posts)
    @chart_interactions = TwitterPost.grouped_interactions(@posts)

    @total_posts = @posts.size
    @total_interactions = TwitterPost.total_interactions(@posts)
    @total_views = TwitterPost.total_views(@posts)
    @average_interactions = @total_posts.zero? ? 0 : (Float(@total_interactions) / @total_posts).round(1)

    @top_posts = @posts.sort_by(&:total_interactions).reverse.first(10)

    @word_occurrences = TwitterPost.word_occurrences(@posts)
    @bigram_occurrences = TwitterPost.bigram_occurrences(@posts)

    @tag_counts = @posts.tag_counts_on(:tags).order('count desc').limit(20)

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    tag_interaction_totals = Hash.new(0)
    @posts.includes(:tags).each do |post|
      post.tags.each do |tag|
        tag_interaction_totals[tag.name] += post.total_interactions
      end
    end
    @tag_interactions = tag_interaction_totals.sort_by { |_, value| -value }
                                              .to_h

    profiles_group =
      @posts.includes(twitter_profile: :site).group_by do |post|
        post.twitter_profile&.name || 'Sin perfil'
      end
    @profiles_count = profiles_group.transform_values(&:size).sort_by { |_, count| -count }
                                    .to_h
    @profiles_interactions = profiles_group.transform_values { |posts| posts.sum(&:total_interactions) }
                                           .sort_by { |_, value| -value }
                                           .to_h

    # Render with specific layout for PDF
    render layout: false
  end

  private

  def set_topic
    topic_id = params[:id] || params[:topic_id]
    @topic = Topic.find(topic_id)
  end

  def authorize_topic!
    return if @topic.status && @topic.users.exists?(current_user.id)

    redirect_to root_path,
                alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado'
  end
end
