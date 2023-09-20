# frozen_string_literal: true

class EntryController < ApplicationController
  def show; end

  def popular
    @entries = Entry.joins(:site).where(total_count: 1..).a_day_ago.where.not(image_url: nil).order(total_count: :desc).limit(50)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    # Cosas nuevas
    @word_occurrences = word_occurrences(@entries)
    @bigram_occurrences = bigram_occurrences(@entries)

    @comments = Comment.where(entry_id: @entries.pluck(:id)).order(created_time: :desc)
    @comments_word_occurrences = @comments.word_occurrences
    @comments_bigram_occurrences = @comments.bigram_occurrences

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

  def twitter
    @entries = Entry.joins(:site).a_day_ago.where.not(image_url: nil).order(tw_total: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    # Sets counters and values
    @tags_interactions = {}
    @tags.each do |tag|
      @entries.each do |entry|
        tag.interactions ||= 0
        tag.interactions += entry.tw_total if entry.tag_list.include?(tag.name)

        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.tw_total if entry.tag_list.include?(tag.name)
      end
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
    @tags_interactions.reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end

  def commented
    @entries = Entry.joins(:site).a_day_ago.where.not(image_url: nil).order(comment_count: :desc)

    @tags = @entries.tag_counts_on(:tags).order('count desc')

    # Sets counters and values
    @tags_interactions = Rails.cache.read('tags_interactions_commented')

    # Cosas nuevas
    @word_occurrences = word_occurrences(@entries)
    @bigram_occurrences = bigram_occurrences(@entries)

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
      Rails.cache.write('tags_interactions_commented', @tags_interactions, expires_in: 1.hour)
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
    @tags_interactions.reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end

  def week
    @entries = Entry.joins(:site).a_week_ago.where.not(image_url: nil).order(published_at: :desc)
    @today = Time.zone.today
    @a_week_ago = @today - 7
  end

  def similar
    @entry = Entry.find_by(url: params[:url])
    @entries = Entry.tagged_with(@entry.tags, any: true).order(published_at: :desc).limit(10)
    render json: @entries
  end

  def search
    tag = params[:query]
    @entries = Entry.includes(:site).tagged_with(tag).order(published_at: :desc).limit(50)
  end
end
