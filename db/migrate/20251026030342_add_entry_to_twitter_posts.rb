class AddEntryToTwitterPosts < ActiveRecord::Migration[7.0]
  def change
    add_reference :twitter_posts, :entry, null: true, foreign_key: true, index: true
  end
end
