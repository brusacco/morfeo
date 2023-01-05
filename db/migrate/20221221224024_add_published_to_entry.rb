# frozen_string_literal: true

class AddPublishedToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :published_at, :timestamp
  end
end
