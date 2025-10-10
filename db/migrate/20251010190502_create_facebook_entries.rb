class CreateFacebookEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :facebook_entries do |t|
      t.references :page, null: false, foreign_key: true
      t.string :facebook_post_id, null: false
      t.datetime :posted_at, null: false
      t.datetime :fetched_at

      t.text :message
      t.string :permalink_url

      t.string :attachment_type
      t.string :attachment_title
      t.text :attachment_description
      t.string :attachment_url
      t.string :attachment_target_url
      t.text :attachment_media_src
      t.integer :attachment_media_width
      t.integer :attachment_media_height
      t.json :attachments_raw

      t.integer :reactions_like_count, null: false, default: 0
      t.integer :reactions_love_count, null: false, default: 0
      t.integer :reactions_wow_count, null: false, default: 0
      t.integer :reactions_haha_count, null: false, default: 0
      t.integer :reactions_sad_count, null: false, default: 0
      t.integer :reactions_angry_count, null: false, default: 0
      t.integer :reactions_thankful_count, null: false, default: 0
      t.integer :reactions_total_count, null: false, default: 0
      t.integer :comments_count, null: false, default: 0
      t.integer :share_count, null: false, default: 0

      t.json :payload

      t.timestamps
    end

    add_index :facebook_entries, :facebook_post_id, unique: true
    add_index :facebook_entries, %i[page_id posted_at]
  end
end
