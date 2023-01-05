# frozen_string_literal: true

class CreateEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :entries do |t|
      t.string :url
      t.string :title
      t.boolean :enabled, default: false

      t.timestamps
    end
    add_index :entries, :url, unique: true
  end
end
