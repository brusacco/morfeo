# frozen_string_literal: true

class AddContentFilterToSite < ActiveRecord::Migration[7.0]
  def change
    add_column :sites, :content_filter, :string
  end
end
