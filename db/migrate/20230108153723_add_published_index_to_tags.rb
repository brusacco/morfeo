# frozen_string_literal: true

class AddPublishedIndexToTags < ActiveRecord::Migration[7.0]
  def change
    add_index :tags, :published_at
  end
end
