# frozen_string_literal: true

class AddNegativeWordsToTopic < ActiveRecord::Migration[7.0]
  def change
    add_column :topics, :negative_words, :text
  end
end
