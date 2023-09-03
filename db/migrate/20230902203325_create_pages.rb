# frozen_string_literal: true

class CreatePages < ActiveRecord::Migration[7.0]
  def change
    create_table :pages do |t|
      t.string :uid
      t.string :name
      t.string :username
      t.text :picture
      t.integer :followers, default: 0
      t.string :category
      t.text :description
      t.string :website

      t.timestamps
    end
  end
end
