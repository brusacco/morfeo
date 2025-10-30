# frozen_string_literal: true

class FacebookTopicController < ApplicationController
  before_action :authenticate_user!
  before_action :set_topic
  before_action :authorize_topic!

  def show
    @tag_list = @topic.tags.pluck(:name)
    @entries = FacebookEntry.for_topic(@topic)
    @chart_posts = FacebookEntry.grouped_counts(@entries)
    @chart_interactions = FacebookEntry.grouped_interactions(@entries)

    @total_posts = @entries.size
    @total_interactions = FacebookEntry.total_interactions(@entries)
    @total_views = FacebookEntry.total_views(@entries)
    @average_interactions = @total_posts.zero? ? 0 : (Float(@total_interactions) / @total_posts).round(1)

    @top_posts = @entries.sort_by(&:total_interactions).reverse.first(20)

    @word_occurrences = FacebookEntry.word_occurrences(@entries)
    @bigram_occurrences = FacebookEntry.bigram_occurrences(@entries)

    @tag_counts = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    tag_interaction_totals = Hash.new(0)
    @entries.includes(:tags).each do |entry|
      entry.tags.each do |tag|
        tag_interaction_totals[tag.name] += entry.total_interactions
      end
    end
    @tag_interactions = tag_interaction_totals.sort_by { |_, value| -value }
                                              .to_h

    pages_group = @entries.includes(page: :site).group_by { |entry| entry.page&.name || 'Sin página' }
    @pages_count = pages_group.transform_values(&:size).sort_by { |_, count| -count }
                              .to_h
    @pages_interactions = pages_group.transform_values { |posts| posts.sum(&:total_interactions) }
                                     .sort_by { |_, value| -value }
                                     .to_h

    # Site data for media analysis
    @site_top_counts = @entries.joins(page: :site).reorder(nil).group('sites.id').order(Arel.sql('COUNT(*) DESC')).limit(12).count
    @site_counts = @entries.joins(page: :site).reorder(nil).group('sites.name').count
    @site_sums = @entries.joins(page: :site).reorder(nil).group('sites.name').sum(Arel.sql('facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count'))
  end

  def entries_data
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    entries = FacebookEntry.for_topic(@topic, start_time: date.beginning_of_day, end_time: date.end_of_day)

    render partial: 'facebook_topic/chart_entries', locals: { entries:, entries_date: date, topic_name: @topic.name }
  end

  def pdf
    @tag_list = @topic.tags.pluck(:name)
    @entries = FacebookEntry.for_topic(@topic)
    @chart_posts = FacebookEntry.grouped_counts(@entries)
    @chart_interactions = FacebookEntry.grouped_interactions(@entries)

    @total_posts = @entries.size
    @total_interactions = FacebookEntry.total_interactions(@entries)
    @total_views = FacebookEntry.total_views(@entries)
    @average_interactions = @total_posts.zero? ? 0 : (Float(@total_interactions) / @total_posts).round(1)

    @top_posts = @entries.sort_by(&:total_interactions).reverse.first(10)

    @word_occurrences = FacebookEntry.word_occurrences(@entries)
    @bigram_occurrences = FacebookEntry.bigram_occurrences(@entries)

    @tag_counts = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    tag_interaction_totals = Hash.new(0)
    @entries.includes(:tags).each do |entry|
      entry.tags.each do |tag|
        tag_interaction_totals[tag.name] += entry.total_interactions
      end
    end
    @tag_interactions = tag_interaction_totals.sort_by { |_, value| -value }
                                              .to_h

    pages_group = @entries.includes(page: :site).group_by { |entry| entry.page&.name || 'Sin página' }
    @pages_count = pages_group.transform_values(&:size).sort_by { |_, count| -count }
                              .to_h
    @pages_interactions = pages_group.transform_values { |posts| posts.sum(&:total_interactions) }
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
