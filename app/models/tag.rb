# frozen_string_literal: true

class Tag < ApplicationRecord
  has_and_belongs_to_many :topics
  accepts_nested_attributes_for :topics

  has_many :taggings, dependent: :destroy
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
    tag_list = name
    result = Entry.search(
      where: {
        published_at: { gte: DAYS_RANGE.days.ago },
        tags: { in: tag_list }
      },
      order: { published_at: :desc },
      fields: ['id'] # Only return the ids to reduce payload
    )
    Entry.enabled.where(id: result.map(&:id)).joins(:site)
  end

  def title_list_entries
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

  private

  def tag_entries
    Tags::TagEntriesJob.perform_later(id, 1.month.ago..Time.current)
  end
end
