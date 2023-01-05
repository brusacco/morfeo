# frozen_string_literal: true

class AddFilterToSite < ActiveRecord::Migration[7.0]
  def change
    add_column :sites, :filter, :string
  end
end
