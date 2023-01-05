# frozen_string_literal: true

class AddImageUrlToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :image_url, :text
  end
end
