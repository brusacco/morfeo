# frozen_string_literal: true

class AddDescriptionToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :description, :text
    add_column :entries, :content, :text
  end
end
