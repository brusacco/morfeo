class CreateTwitterPosts < ActiveRecord::Migration[7.0]
  def change
    create_table :twitter_posts do |t|
      t.references :twitter_profile, null: false, foreign_key: true
      t.string :tweet_id, null: false
      t.datetime :posted_at, null: false
      t.datetime :fetched_at
      t.text :text
      t.string :permalink_url
      t.integer :quote_count, default: 0, null: false
      t.integer :reply_count, default: 0, null: false
      t.integer :retweet_count, default: 0, null: false
      t.integer :favorite_count, default: 0, null: false
      t.integer :views_count, default: 0, null: false
      t.integer :bookmark_count, default: 0, null: false
      t.string :lang
      t.string :source
      t.boolean :is_retweet, default: false
      t.boolean :is_quote, default: false
      t.json :payload

      t.timestamps
    end

    add_index :twitter_posts, :tweet_id, unique: true
    add_index :twitter_posts, %i[twitter_profile_id posted_at]
  end
end
