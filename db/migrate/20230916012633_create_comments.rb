# frozen_string_literal: true

class CreateComments < ActiveRecord::Migration[7.0]
  def change
    create_table :comments do |t|
      t.string :uid
      t.datetime :created_time
      t.text :message
      t.integer :entry_id

      t.timestamps
    end
    add_index :comments, :entry_id
    add_index :comments, :uid
  end
end
