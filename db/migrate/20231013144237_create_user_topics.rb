# frozen_string_literal: true

class CreateUserTopics < ActiveRecord::Migration[7.0]
  def change
    create_table :user_topics do |t|
      t.references :user, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true

      t.timestamps
    end
  end
end
