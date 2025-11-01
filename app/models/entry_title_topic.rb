# frozen_string_literal: true

class EntryTitleTopic < ApplicationRecord
  belongs_to :entry
  belongs_to :topic
  
  validates :entry_id, uniqueness: { scope: :topic_id }
  
  # Useful for debugging
  scope :recent, -> { order(created_at: :desc) }
end

