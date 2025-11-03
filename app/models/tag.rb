# frozen_string_literal: true

class Tag < ApplicationRecord
  has_and_belongs_to_many :topics
  accepts_nested_attributes_for :topics

  has_many :taggings, dependent: :destroy
  
  # NEW: Direct entry associations through taggings (optimized query)
  # This provides a faster alternative to .tagged_with() for performance-critical queries
  has_many :entries, -> { where(taggings: { taggable_type: 'Entry', context: 'tags' }) },
           through: :taggings,
           source: :taggable,
           source_type: 'Entry'
  
  has_many :title_entries, -> { where(taggings: { taggable_type: 'Entry', context: 'title_tags' }) },
           through: :taggings,
           source: :taggable,
           source_type: 'Entry',
           class_name: 'Entry'
  
  validates :name, uniqueness: true

  after_create :tag_entries
  after_update :tag_entries

  attr_accessor :interactions

  def belongs_to_any_topic?
    Topic.all.any? { |topic| topic.tag_ids.include?(id) }
  end

  def list_entries_test
    filtered_entries = RecentEntry.tagged_with(name).order(published_at: :desc)
    RecentEntry.tagged_with('Honor Colorado').order(published_at: :desc)
    filtered_entries.joins(:site)
  end

  def list_entries
    cache_key = "tag_#{id}_list_entries_#{ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true' ? 'v2' : 'v1'}"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
        # NEW: Use direct association through taggings (much faster!)
        # This avoids the overhead of acts_as_taggable_on's .tagged_with() method
        entries.enabled
               .includes(:site, :tags)
               .joins(:site)
               .where('entries.published_at >= ?', DAYS_RANGE.days.ago)
               .order('entries.published_at DESC')
      else
        # OLD: Elasticsearch
        tag_list = name
        result = Entry.search(
          where: {
            published_at: { gte: DAYS_RANGE.days.ago },
            tags: { in: tag_list }
          },
          order: { published_at: :desc },
          fields: ['id'] # Only return the ids to reduce payload
        )
        Entry.enabled.where(id: result.map(&:id)).includes(:site, :tags).joins(:site)
      end
    end
  end

  def title_list_entries
    cache_key = "tag_#{id}_title_list_entries_#{ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true' ? 'v2' : 'v1'}"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
        # NEW: Use direct association through taggings (much faster!)
        title_entries.enabled
                     .joins(:site)
                     .where('entries.published_at >= ?', DAYS_RANGE.days.ago)
                     .order('entries.published_at DESC')
      else
        # OLD: Elasticsearch
        tag_list = name
        result = Entry.search(
          where: {
            published_at: { gte: DAYS_RANGE.days.ago },
            title_tags: { in: tag_list }
          },
          order: { published_at: :desc },
          fields: ['id']
        )
        Entry.enabled.where(id: result.map(&:id)).joins(:site)
      end
    end
  end

  private

  def tag_entries
    # Tag entries from last 60 days to match PDF report requirements
    Tags::TagEntriesJob.perform_later(id, 60.days.ago..Time.current)
  end
end
