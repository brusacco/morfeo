# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_10_13_144237) do
  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.integer "resource_id"
    t.string "author_type"
    t.integer "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.string "uid"
    t.datetime "created_time"
    t.text "message"
    t.integer "entry_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_comments_on_entry_id"
    t.index ["uid"], name: "index_comments_on_uid"
  end

  create_table "entries", force: :cascade do |t|
    t.string "url"
    t.string "title"
    t.boolean "enabled", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "site_id"
    t.text "description"
    t.text "content"
    t.datetime "published_at", precision: nil
    t.text "image_url"
    t.integer "reaction_count", default: 0
    t.integer "comment_count", default: 0
    t.integer "share_count", default: 0
    t.integer "comment_plugin_count", default: 0
    t.integer "total_count", default: 0
    t.integer "tw_fav", default: 0
    t.integer "tw_rt", default: 0
    t.integer "tw_total", default: 0
    t.date "published_date"
    t.string "uid"
    t.integer "polarity"
    t.integer "delta", default: 0
    t.index ["published_date"], name: "index_entries_on_published_date"
    t.index ["site_id"], name: "index_entries_on_site_id"
    t.index ["url"], name: "index_entries_on_url", unique: true
  end

  create_table "pages", force: :cascade do |t|
    t.string "uid"
    t.string "name"
    t.string "username"
    t.text "picture"
    t.integer "followers", default: 0
    t.string "category"
    t.text "description"
    t.string "website"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "site_id"
    t.index ["site_id"], name: "index_pages_on_site_id"
  end

  create_table "reports", force: :cascade do |t|
    t.integer "topic_id", null: false
    t.text "report_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["topic_id"], name: "index_reports_on_topic_id"
  end

  create_table "sites", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "filter"
    t.integer "reaction_count", default: 0
    t.integer "comment_count", default: 0
    t.integer "share_count", default: 0
    t.integer "comment_plugin_count", default: 0
    t.integer "total_count", default: 0
    t.string "content_filter"
    t.string "negative_filter"
    t.integer "entries_count", default: 0
    t.text "image64"
    t.index ["name"], name: "index_sites_on_name", unique: true
    t.index ["url"], name: "index_sites_on_url", unique: true
  end

  create_table "taggings", force: :cascade do |t|
    t.integer "tag_id"
    t.string "taggable_type"
    t.integer "taggable_id"
    t.string "tagger_type"
    t.integer "tagger_id"
    t.string "context", limit: 128
    t.datetime "created_at", precision: nil
    t.string "tenant", limit: 128
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "taggings_taggable_context_idx"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable_type_and_taggable_id"
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
    t.index ["tagger_type", "tagger_id"], name: "index_taggings_on_tagger_type_and_tagger_id"
    t.index ["tenant"], name: "index_taggings_on_tenant"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "taggings_count", default: 0
    t.string "variations"
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "tags_topics", id: false, force: :cascade do |t|
    t.integer "tag_id"
    t.integer "topic_id"
    t.index ["tag_id"], name: "index_tags_topics_on_tag_id"
    t.index ["topic_id"], name: "index_tags_topics_on_topic_id"
  end

  create_table "topics", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "positive_words"
    t.text "negative_words"
  end

  create_table "user_topics", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "topic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["topic_id"], name: "index_user_topics_on_topic_id"
    t.index ["user_id"], name: "index_user_topics_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.boolean "status", default: true, null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["name"], name: "index_users_on_name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "reports", "topics"
  add_foreign_key "taggings", "tags"
  add_foreign_key "user_topics", "topics"
  add_foreign_key "user_topics", "users"
end
