# frozen_string_literal: true

class AddPositiveWordsToTopic < ActiveRecord::Migration[7.0]
  def change
    add_column :topics, :positive_words, :text
  end
end
