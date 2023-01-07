# frozen_string_literal: true

class AddAltsToTag < ActiveRecord::Migration[7.0]
  def change
    add_column :tags, :variations, :string
  end
end
