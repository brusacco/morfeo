# frozen_string_literal: true

class EntryController < ApplicationController
  before_action :authenticate_user!

  # Constants for limits and cache duration
  POPULAR_ENTRIES_LIMIT = 50
  COMMENTED_ENTRIES_LIMIT = 50
  TAG_LIMIT = 20
  SEARCH_LIMIT = 50
  CACHE_DURATION = 30.minutes

  caches_action :popular, expires_in: CACHE_DURATION, cache_path: proc { |c| { user_id: c.current_user.id } }
  caches_action :commented, expires_in: CACHE_DURATION, cache_path: proc { |c| { user_id: c.current_user.id } }
  caches_action :week, expires_in: CACHE_DURATION, cache_path: proc { |c| { user_id: c.current_user.id } }

  def show
    # Renders default template - no additional logic needed
    # Template: app/views/entry/show.html.erb
  end

  def popular
    @entries = FacebookEntry.includes(
      :page,
      :tags
    ).within_range(1.day.ago, Time.zone.now).order(reactions_total_count: :desc).limit(POPULAR_ENTRIES_LIMIT)
    # Separate query for grouping operations to avoid MySQL strict mode issues
    @entries_for_grouping = FacebookEntry.joins(:page).within_range(1.day.ago, Time.zone.now)

    # Get all tags from user's topics
    user_topic_tags = @topicos.flat_map(&:tags).uniq
    user_topic_tag_names = user_topic_tags.map(&:name)

    # Filter tags to only show those from user's topics
    @tags = @entries.tag_counts_on(:tags).select do |tag|
      user_topic_tag_names.include?(tag.name)
    end
.sort_by(&:count).reverse

    # Word/bigram analysis
    @word_occurrences = FacebookEntry.word_occurrences(@entries)
    @bigram_occurrences = FacebookEntry.bigram_occurrences(@entries)

    entry_ids = @entries.pluck(:id)

    @tags_interactions =
      Rails.cache.fetch("tags_interactions_fb_popular_#{Date.current}", expires_in: CACHE_DURATION) do
        FacebookEntry.joins(:tags)
                     .where(id: entry_ids, tags: { id: @tags.map(&:id) })
                     .group('tags.name')
                     .order(Arel.sql('SUM(reactions_total_count) DESC'))
                     .sum(:reactions_total_count)
      end

    @tags_count = {}
    @tags.each do |tag|
      @tags_count[tag.name] = tag.count
      # Assign interactions to each tag object - capture value, not reference
      interaction_count = @tags_interactions[tag.name] || 0
      tag.define_singleton_method(:interactions) { interaction_count }
    end

    # Prepare page data in format for list display
    page_counts_by_name = @entries_for_grouping.reorder(nil).group('pages.name').count
    page_sums_by_name = @entries_for_grouping.reorder(nil).group('pages.name').sum(:reactions_total_count)

    # Get top pages
    page_name_counts = page_counts_by_name.sort_by { |_, count| -count }
                                          .first(12)
    page_name_interactions = page_sums_by_name.sort_by { |_, sum| -sum }
                                              .first(12)

    # Load Page objects with their data
    page_names = (page_name_counts.map(&:first) + page_name_interactions.map(&:first)).uniq
    pages_by_name = Page.where(name: page_names).index_by(&:name)

    # Build arrays with page objects (format: [{ page: page_object, name: page_name, count: count }])
    @page_top_counts =
      page_name_counts.map do |page_name, count|
        { page: pages_by_name[page_name], name: page_name, count: count }
      end

    @page_top_interactions =
      page_name_interactions.map do |page_name, interactions|
        { page: pages_by_name[page_name], name: page_name, interactions: interactions }
      end
  end

  def twitter
    @entries = Entry.enabled.includes(:site, :tags).a_day_ago.where.not(image_url: nil).order(tw_total: :desc)
    @entries_for_grouping = Entry.enabled.joins(:site).a_day_ago.where.not(image_url: nil)
    @tags = @entries.tag_counts_on(:tags).order(count: :desc)

    # Use pluck for entry_ids to avoid LIMIT in subquery issue
    entry_ids = @entries.pluck(:id)

    @tags_interactions = Entry.joins(:tags)
                              .where(id: entry_ids, tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .order(Arel.sql('SUM(tw_total) DESC'))
                              .sum(:tw_total)

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end

  def commented
    @entries = FacebookEntry.includes(
      :page,
      :tags
    ).within_range(1.day.ago, Time.zone.now).order(comments_count: :desc).limit(COMMENTED_ENTRIES_LIMIT)
    # Separate query for grouping operations to avoid MySQL strict mode issues
    @entries_for_grouping = FacebookEntry.joins(:page).within_range(1.day.ago, Time.zone.now)

    # Get all tags from user's topics
    user_topic_tags = @topicos.flat_map(&:tags).uniq
    user_topic_tag_names = user_topic_tags.map(&:name)

    # Filter tags to only show those from user's topics
    @tags = @entries.tag_counts_on(:tags).select do |tag|
      user_topic_tag_names.include?(tag.name)
    end
.sort_by(&:count).reverse

    # Word/bigram analysis
    @word_occurrences = FacebookEntry.word_occurrences(@entries)
    @bigram_occurrences = FacebookEntry.bigram_occurrences(@entries)

    # Use pluck for entry_ids to avoid LIMIT in subquery issue
    entry_ids = @entries.pluck(:id)

    @tags_interactions =
      Rails.cache.fetch("tags_interactions_fb_commented_#{Date.current}", expires_in: CACHE_DURATION) do
        FacebookEntry.joins(:tags)
                     .where(id: entry_ids, tags: { id: @tags.map(&:id) })
                     .group('tags.name')
                     .order(Arel.sql('SUM(reactions_total_count) DESC'))
                     .sum(:reactions_total_count)
      end

    @tags_count = {}
    @tags.each do |tag|
      @tags_count[tag.name] = tag.count
      # Assign interactions to each tag object - capture value, not reference
      interaction_count = @tags_interactions[tag.name] || 0
      tag.define_singleton_method(:interactions) { interaction_count }
    end

    # Prepare page data in format for list display
    page_counts_by_name = @entries_for_grouping.reorder(nil).group('pages.name').count
    page_sums_by_name = @entries_for_grouping.reorder(nil).group('pages.name').sum(:reactions_total_count)

    # Get top pages
    page_name_counts = page_counts_by_name.sort_by { |_, count| -count }
                                          .first(12)
    page_name_interactions = page_sums_by_name.sort_by { |_, sum| -sum }
                                              .first(12)

    # Load Page objects with their data
    page_names = (page_name_counts.map(&:first) + page_name_interactions.map(&:first)).uniq
    pages_by_name = Page.where(name: page_names).index_by(&:name)

    # Build arrays with page objects (format: [{ page: page_object, name: page_name, count: count }])
    @page_top_counts =
      page_name_counts.map do |page_name, count|
        { page: pages_by_name[page_name], name: page_name, count: count }
      end

    @page_top_interactions =
      page_name_interactions.map do |page_name, interactions|
        { page: pages_by_name[page_name], name: page_name, interactions: interactions }
      end
  end

  def week
    @entries = Entry.enabled.includes(:site, :tags).a_week_ago.where.not(image_url: nil).order(published_at: :desc)
    @today = Time.zone.today
    @a_week_ago = @today - 7
  end

  def similar
    @entry = Entry.find_by(url: params[:url])
    @entries = Entry.enabled.includes(:site, :tags).tagged_with(
      @entry.tags,
      any: true
    ).order(published_at: :desc).limit(10)
    render json: @entries
  end

  def search
    tag = params[:query]
    @entries = Entry.enabled.includes(:site, :tags).tagged_with(tag).order(published_at: :desc).limit(SEARCH_LIMIT)
  end
end
