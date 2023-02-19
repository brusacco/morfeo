# frozen_string_literal: true

class AddPublishedDateToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :published_date, :date
    add_index :entries, :published_date
  end
end
