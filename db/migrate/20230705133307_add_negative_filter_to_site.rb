# frozen_string_literal: true

class AddNegativeFilterToSite < ActiveRecord::Migration[7.0]
  def change
    add_column :sites, :negative_filter, :string
  end
end
