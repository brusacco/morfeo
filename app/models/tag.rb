# frozen_string_literal: true

class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  validates :name, uniqueness: true

  after_create :tag_entries
  after_destroy :untag_entries

  private

  def tag_entries
    Tags::TagEntriesJob.perform_later(id, 1.month.ago..)
  end

  def untag_entries
    Tags::UntagEntriesJob.perform_later(id)
  end
end
