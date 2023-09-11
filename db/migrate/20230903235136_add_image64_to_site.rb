# frozen_string_literal: true

class AddImage64ToSite < ActiveRecord::Migration[7.0]
  def change
    add_column :sites, :image64, :text
  end
end
