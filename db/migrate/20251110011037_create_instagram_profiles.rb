# frozen_string_literal: true

class CreateInstagramProfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :instagram_profiles do |t|
      # Basic Profile Info
      t.string :uid, null: false
      t.string :username, null: false
      t.string :full_name
      t.text :biography
      t.string :profile_type

      # Follower/Following Counts
      t.integer :followers, default: 0
      t.integer :following, default: 0

      # Profile Status Flags
      t.boolean :is_verified, default: false
      t.boolean :is_business_account, default: false
      t.boolean :is_professional_account, default: false
      t.boolean :is_private, default: false

      # Profile Metadata
      t.string :country_string
      t.string :category_name
      t.string :business_category_name

      # Profile Images
      t.text :profile_pic_url
      t.text :profile_pic_url_hd

      # Analytics & Metrics
      t.decimal :engagement_rate, precision: 10, scale: 2
      t.integer :total_posts, default: 0
      t.integer :total_videos, default: 0
      t.integer :total_likes_count, default: 0
      t.integer :total_comments_count, default: 0
      t.bigint :total_video_view_count, default: 0
      t.integer :total_interactions_count, default: 0
      t.integer :median_interactions, default: 0
      t.integer :median_video_views, default: 0

      # Reach Estimation
      t.integer :estimated_reach, default: 0
      t.decimal :estimated_reach_percentage, precision: 10, scale: 2

      # System Fields
      t.datetime :last_synced_at
      t.references :site, null: true, foreign_key: true

      t.timestamps
    end

    # Indexes
    add_index :instagram_profiles, :uid, unique: true
    add_index :instagram_profiles, :username, unique: true
    add_index :instagram_profiles, :last_synced_at
  end
end
