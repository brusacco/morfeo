# frozen_string_literal: true

class CreateInstagramPosts < ActiveRecord::Migration[7.0]
  def change
    create_table :instagram_posts do |t|
      # Post Identifiers
      t.string :shortcode, null: false          # Shortcode (igual al instagram_post_id)
      t.string :url                             # URL del post en Instagram

      # Content
      t.text :caption                           # Caption del post

      # Media Information
      t.string :media_type                      # GraphImage, GraphVideo, GraphSidecar
      t.string :product_type                    # feed, clips, igtv

      # Engagement Metrics
      t.integer :likes_count, default: 0
      t.integer :comments_count, default: 0
      t.bigint :video_view_count               # Nullable, solo para videos
      t.integer :total_count, default: 0       # likes + comments

      # Timestamps
      t.datetime :posted_at, null: false
      t.datetime :fetched_at                   # Last time data was fetched

      # Relationships
      t.references :instagram_profile, null: false, foreign_key: true
      t.references :entry, null: true, foreign_key: true  # Cross-link to news entries

      t.timestamps
    end

    # Indexes
    add_index :instagram_posts, :shortcode, unique: true
    add_index :instagram_posts, :posted_at
    add_index :instagram_posts, :media_type
    add_index :instagram_posts, :product_type
    add_index :instagram_posts, [:instagram_profile_id, :posted_at]
  end
end
