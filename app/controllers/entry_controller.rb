# frozen_string_literal: true

class EntryController < ApplicationController
  before_action :authenticate_user!

  caches_action :popular, expires_in: 1.hour
  caches_action :commented, expires_in: 1.hour
  caches_action :week, expires_in: 1.hour
  def show; end

  def popular
    @entries = Entry.enabled.joins(:site).where(total_count: 1..).a_day_ago.order(total_count: :desc).limit(50)
    # Separate query for grouping operations to avoid MySQL strict mode issues
    @entries_for_grouping = Entry.enabled.joins(:site).where(total_count: 1..).a_day_ago
    
    # Get all tags from user's topics
    user_topic_tags = @topicos.flat_map(&:tags).uniq
    user_topic_tag_names = user_topic_tags.map(&:name)
    
    # Filter tags to only show those from user's topics
    @tags = @entries.tag_counts_on(:tags).select { |tag| user_topic_tag_names.include?(tag.name) }.sort_by(&:count).reverse

    # Cosas nuevas
    @word_occurrences = @entries.word_occurrences
    @bigram_occurrences = @entries.bigram_occurrences

    @comments = Comment.where(entry_id: @entries.pluck(:id)).order(created_time: :desc)
    @comments_word_occurrences = @comments.word_occurrences
    # @comments_bigram_occurrences = @comments.bigram_occurrences

    @tags_interactions = Entry.joins(:tags)
                              .where(id: @entries.pluck(:id), tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .order(Arel.sql('SUM(total_count) DESC'))
                              .sum(:total_count)

    @tags_count = {}
    @tags.each do |tag|
      @tags_count[tag.name] = tag.count
      # Assign interactions to each tag object - capture value, not reference
      interaction_count = @tags_interactions[tag.name] || 0
      tag.define_singleton_method(:interactions) { interaction_count }
    end
  end

  def twitter
    @entries = Entry.enabled.joins(:site).a_day_ago.where.not(image_url: nil).order(tw_total: :desc)
    @entries_for_grouping = Entry.enabled.joins(:site).a_day_ago.where.not(image_url: nil)
    @tags = @entries.tag_counts_on(:tags).order(count: :desc)

    @tags_interactions = Entry.joins(:tags)
                              .where(id: @entries.pluck(:id), tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .order(Arel.sql('SUM(tw_total) DESC'))
                              .sum(:tw_total)

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end

  def commented
    @entries = Entry.enabled.joins(:site).a_day_ago.where.not(image_url: nil).order(comment_count: :desc).limit(50)
    # Separate query for grouping operations to avoid MySQL strict mode issues
    @entries_for_grouping = Entry.enabled.joins(:site).a_day_ago.where.not(image_url: nil)

    # Get all tags from user's topics
    user_topic_tags = @topicos.flat_map(&:tags).uniq
    user_topic_tag_names = user_topic_tags.map(&:name)
    
    # Filter tags to only show those from user's topics
    @tags = @entries.tag_counts_on(:tags).select { |tag| user_topic_tag_names.include?(tag.name) }.sort_by(&:count).reverse

    # Cosas nuevas
    @word_occurrences = @entries.word_occurrences
    @bigram_occurrences = @entries.bigram_occurrences

    @tags_interactions =
      Rails.cache.fetch('tags_interactions_commented', expires_in: 1.hour) do
        Entry.joins(:tags)
             .where(id: @entries.pluck(:id), tags: { id: @tags.map(&:id) })
             .group('tags.name')
             .order(Arel.sql('SUM(total_count) DESC'))
             .sum(:total_count)
      end

    @tags_count = {}
    @tags.each do |tag|
      @tags_count[tag.name] = tag.count
      # Assign interactions to each tag object - capture value, not reference
      interaction_count = @tags_interactions[tag.name] || 0
      tag.define_singleton_method(:interactions) { interaction_count }
    end
  end

  def week
    @entries = Entry.enabled.joins(:site).a_week_ago.where.not(image_url: nil).order(published_at: :desc)
    @today = Time.zone.today
    @a_week_ago = @today - 7
  end

  def similar
    @entry = Entry.find_by(url: params[:url])
    @entries = Entry.enabled.tagged_with(@entry.tags, any: true).order(published_at: :desc).limit(10)
    render json: @entries
  end

  def search
    tag = params[:query]
    @entries = Entry.enabled.includes(:site).tagged_with(tag).order(published_at: :desc).limit(50)
  end
end
