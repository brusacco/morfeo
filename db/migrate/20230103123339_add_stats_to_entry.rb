# frozen_string_literal: true

class AddStatsToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :reaction_count, :integer, default: 0
    add_column :entries, :comment_count, :integer, default: 0
    add_column :entries, :share_count, :integer, default: 0
    add_column :entries, :comment_plugin_count, :integer, default: 0
    add_column :entries, :total_count, :integer, default: 0
  end
end
