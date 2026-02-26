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
    @entries = Entry.enabled.includes(
      :site,
      :tags
    ).where(total_count: 1..).a_day_ago.order(total_count: :desc).limit(POPULAR_ENTRIES_LIMIT)
    # Separate query for grouping operations to avoid MySQL strict mode issues
    @entries_for_grouping = Entry.enabled.joins(:site).where(total_count: 1..).a_day_ago

    # Get all tags from user's topics
    user_topic_tags = @topicos.flat_map(&:tags).uniq
    user_topic_tag_names = user_topic_tags.map(&:name)

    # Filter tags to only show those from user's topics
    @tags = @entries.tag_counts_on(:tags).select do |tag|
      user_topic_tag_names.include?(tag.name)
    end
.sort_by(&:count).reverse

    # Cosas nuevas
    @word_occurrences = @entries.word_occurrences
    @bigram_occurrences = @entries.bigram_occurrences

    # Use pluck for comments to avoid LIMIT in subquery issue with find_each
    entry_ids = @entries.pluck(:id)
    @comments = Comment.where(entry_id: entry_ids).order(created_time: :desc)
    @comments_word_occurrences = @comments.word_occurrences

    @tags_interactions =
      Rails.cache.fetch("tags_interactions_popular_#{Date.current}", expires_in: CACHE_DURATION) do
        # Use entry_ids array instead of subquery with LIMIT
        Entry.joins(:tags)
             .where(id: entry_ids, tags: { id: @tags.map(&:id) })
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

    # Prepare site data in format for list display (similar to topic/tag controllers)
    site_counts_by_name = @entries_for_grouping.reorder(nil).group('sites.name').count
    site_sums_by_name = @entries_for_grouping.reorder(nil).group('sites.name').sum(:total_count)

    # Get top sites
    site_name_counts = site_counts_by_name.sort_by { |_, count| -count }
                                          .first(12)
    site_name_interactions = site_sums_by_name.sort_by { |_, sum| -sum }
                                              .first(12)

    # Load Site objects with their data
    site_names = (site_name_counts.map(&:first) + site_name_interactions.map(&:first)).uniq
    sites_by_name = Site.where(name: site_names).index_by(&:name)

    # Build arrays with site objects (format: [{ site: site_object, name: site_name, count: count }])
    @site_top_counts =
      site_name_counts.map do |site_name, count|
        { site: sites_by_name[site_name], name: site_name, count: count }
      end

    @site_top_interactions =
      site_name_interactions.map do |site_name, interactions|
        { site: sites_by_name[site_name], name: site_name, interactions: interactions }
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
    @entries = Entry.enabled.includes(
      :site,
      :tags
    ).a_day_ago.where.not(image_url: nil).order(comment_count: :desc).limit(COMMENTED_ENTRIES_LIMIT)
    # Separate query for grouping operations to avoid MySQL strict mode issues
    @entries_for_grouping = Entry.enabled.joins(:site).a_day_ago.where.not(image_url: nil)

    # Get all tags from user's topics
    user_topic_tags = @topicos.flat_map(&:tags).uniq
    user_topic_tag_names = user_topic_tags.map(&:name)

    # Filter tags to only show those from user's topics
    @tags = @entries.tag_counts_on(:tags).select do |tag|
      user_topic_tag_names.include?(tag.name)
    end
.sort_by(&:count).reverse

    # Cosas nuevas
    @word_occurrences = @entries.word_occurrences
    @bigram_occurrences = @entries.bigram_occurrences

    # Use pluck for entry_ids to avoid LIMIT in subquery issue
    entry_ids = @entries.pluck(:id)

    @tags_interactions =
      Rails.cache.fetch("tags_interactions_commented_#{Date.current}", expires_in: CACHE_DURATION) do
        # Use entry_ids array instead of subquery with LIMIT
        Entry.joins(:tags)
             .where(id: entry_ids, tags: { id: @tags.map(&:id) })
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

    # Prepare site data in format for list display (similar to topic/tag controllers)
    site_counts_by_name = @entries_for_grouping.reorder(nil).group('sites.name').count
    site_sums_by_name = @entries_for_grouping.reorder(nil).group('sites.name').sum(:total_count)

    # Get top sites
    site_name_counts = site_counts_by_name.sort_by { |_, count| -count }
                                          .first(12)
    site_name_interactions = site_sums_by_name.sort_by { |_, sum| -sum }
                                              .first(12)

    # Load Site objects with their data
    site_names = (site_name_counts.map(&:first) + site_name_interactions.map(&:first)).uniq
    sites_by_name = Site.where(name: site_names).index_by(&:name)

    # Build arrays with site objects (format: [{ site: site_object, name: site_name, count: count }])
    @site_top_counts =
      site_name_counts.map do |site_name, count|
        { site: sites_by_name[site_name], name: site_name, count: count }
      end

    @site_top_interactions =
      site_name_interactions.map do |site_name, interactions|
        { site: sites_by_name[site_name], name: site_name, interactions: interactions }
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
