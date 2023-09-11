# frozen_string_literal: true

class AddSiteIdToPages < ActiveRecord::Migration[7.0]
  def change
    add_column :pages, :site_id, :integer
    add_index :pages, :site_id
  end
end
