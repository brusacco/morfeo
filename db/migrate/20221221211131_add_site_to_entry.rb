# frozen_string_literal: true

class AddSiteToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :site_id, :integer
    add_index :entries, :site_id
  end
end
