# frozen_string_literal: true

class AddEntriesCountToSite < ActiveRecord::Migration[7.0]
  def change
    add_column :sites, :entries_count, :integer, default: 0
  end
end
