# frozen_string_literal: true

class AddStatsToSite < ActiveRecord::Migration[7.0]
  def change
    add_column :sites, :reaction_count, :integer, default: 0
    add_column :sites, :comment_count, :integer, default: 0
    add_column :sites, :share_count, :integer, default: 0
    add_column :sites, :comment_plugin_count, :integer, default: 0
    add_column :sites, :total_count, :integer, default: 0
  end
end
