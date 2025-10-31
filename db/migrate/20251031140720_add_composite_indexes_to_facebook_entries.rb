class AddCompositeIndexesToFacebookEntries < ActiveRecord::Migration[7.0]
  def change
    # Composite index for sentiment queries with ordering
    add_index :facebook_entries, [:sentiment_label, :sentiment_score], 
              name: 'index_fb_entries_on_sentiment_label_and_score'
    
    # Composite index for controversy queries with ordering
    add_index :facebook_entries, [:controversy_index, :sentiment_score], 
              name: 'index_fb_entries_on_controversy_and_score'
    
    # Composite index for temporal sentiment analysis
    add_index :facebook_entries, [:posted_at, :sentiment_score], 
              name: 'index_fb_entries_on_posted_at_and_sentiment'
    
    # Composite index for emotional intensity queries
    add_index :facebook_entries, [:emotional_intensity, :posted_at], 
              name: 'index_fb_entries_on_emotion_and_posted_at'
  end
end
