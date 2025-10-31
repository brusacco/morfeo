# frozen_string_literal: true

class AddSentimentAnalysisToFacebookEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :facebook_entries, :sentiment_score, :decimal, precision: 5, scale: 2
    add_column :facebook_entries, :sentiment_label, :integer, default: 0
    add_column :facebook_entries, :sentiment_positive_pct, :decimal, precision: 5, scale: 2
    add_column :facebook_entries, :sentiment_negative_pct, :decimal, precision: 5, scale: 2
    add_column :facebook_entries, :sentiment_neutral_pct, :decimal, precision: 5, scale: 2
    add_column :facebook_entries, :controversy_index, :decimal, precision: 5, scale: 4
    add_column :facebook_entries, :emotional_intensity, :decimal, precision: 8, scale: 4
    
    add_index :facebook_entries, :sentiment_score
    add_index :facebook_entries, :sentiment_label
  end
end

