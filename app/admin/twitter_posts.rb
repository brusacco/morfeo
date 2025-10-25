# frozen_string_literal: true

ActiveAdmin.register TwitterPost do
  menu parent: 'Entries Listing', label: 'Twitter Posts'
  includes :twitter_profile

  actions :all, except: %i[new edit destroy]

  filter :tweet_id
  filter :twitter_profile, collection: proc { TwitterProfile.order(:name) }
  filter :posted_at
  filter :lang
  filter :is_retweet
  filter :is_quote
  filter :created_at

  index do
    selectable_column
    id_column
    column :tweet_id
    column :twitter_profile
    column :posted_at
    column :lang
    column :tags
    column :text do |post|
      truncate(post.text, length: 120)
    end
    column :permalink_url do |post|
      link_to 'Link', post.permalink_url, target: '_blank', rel: 'noopener' if post.permalink_url.present?
    end
    column :favorite_count
    column :retweet_count
    column :reply_count
    actions
  end

  show do
    attributes_table do
      row :tweet_id
      row :twitter_profile
      row :posted_at
      row :fetched_at
      row :permalink_url do |post|
        link_to post.permalink_url, post.permalink_url, target: '_blank', rel: 'noopener' if post.permalink_url.present?
      end
      row :text
      row :lang
      row :source
      row :is_retweet
      row :is_quote
      row :favorite_count
      row :retweet_count
      row :reply_count
      row :quote_count
      row :views_count
      row :bookmark_count
      row :total_interactions
      row :tags
      row :payload do |post|
        pre JSON.pretty_generate(post.payload || {})
      end
      row :created_at
      row :updated_at
    end
  end
end
