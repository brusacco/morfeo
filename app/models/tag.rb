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

  def list_entries
    filtered_entries = RecentEntry.where(published_at: DAYS_RANGE.days.ago..)
                            .tagged_with(name)

    Entry.where(id: filtered_entries.map(&:id)).joins(:site).order(published_at: :desc)
  end

  def list_entries_old
    tag_list = name
    result = Entry.search(
      where: {
        published_at: { gte: DAYS_RANGE.days.ago },
        tags: { in: tag_list }
      },
      order: { published_at: :desc },
      load: false
    )
    Entry.enabled.where(id: result.map(&:id)).joins(:site)
  end

  private

  def tag_entries
    Tags::TagEntriesJob.perform_later(id, 1.month.ago..Time.current)
  end
end
