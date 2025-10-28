# frozen_string_literal: true

ActiveAdmin.register FacebookEntry do
  menu parent: 'Entries Listing', label: 'Facebook Entries'
  includes :page, :entry

  actions :all, except: %i[new edit destroy]

  filter :facebook_post_id
  filter :page, collection: proc { Page.order(:name) }
  filter :posted_at
  filter :created_at
  filter :entry_id, as: :select, collection: proc { Entry.order(published_at: :desc).limit(100) }

  scope :all, default: true
  scope :linked
  scope :unlinked
  scope :with_url

  index do
    selectable_column
    id_column
    column :facebook_post_id
    column :page
    column :linked, sortable: :entry_id do |facebook_entry|
      if facebook_entry.entry_id.present?
        status_tag('Yes', class: 'ok')
      else
        status_tag('No', class: 'error')
      end
    end
    column :entry do |facebook_entry|
      if facebook_entry.entry.present?
        link_to truncate(facebook_entry.entry.title, length: 40), admin_entry_path(facebook_entry.entry)
      end
    end
    column :posted_at
    column :attachment_type
    column :tags
    column :message do |entry|
      truncate(entry.message, length: 120)
    end
    column :permalink_url do |entry|
      link_to 'Link', entry.permalink_url, target: '_blank', rel: 'noopener' if entry.permalink_url.present?
    end
    column :reactions_total_count
    column :comments_count
    column :share_count
    actions
  end

  show do
    attributes_table do
      row :facebook_post_id
      row :page
      row :entry do |facebook_entry|
        if facebook_entry.entry.present?
          link_to facebook_entry.entry.title, admin_entry_path(facebook_entry.entry)
        else
          status_tag('Not Linked', class: 'error')
        end
      end
      row :posted_at
      row :fetched_at
      row :permalink_url do |entry|
        if entry.permalink_url.present?
          link_to entry.permalink_url, entry.permalink_url, target: '_blank', rel: 'noopener'
        end
      end
      row :message
      row :attachment_type
      row :attachment_title
      row :attachment_description
      row :attachment_url do |entry|
        if entry.attachment_url.present?
          link_to entry.attachment_url, entry.attachment_url, target: '_blank', rel: 'noopener'
        end
      end
      row :attachment_target_url do |entry|
        if entry.attachment_target_url.present?
          link_to entry.attachment_target_url, entry.attachment_target_url, target: '_blank', rel: 'noopener'
        end
      end
      row :attachment_media_src do |entry|
        image_tag entry.attachment_media_src, width: 200 if entry.attachment_media_src.present?
      end
      row :reactions_like_count
      row :reactions_love_count
      row :reactions_wow_count
      row :reactions_haha_count
      row :reactions_sad_count
      row :reactions_angry_count
      row :reactions_thankful_count
      row :reactions_total_count
      row :comments_count
      row :share_count
      row :attachments_raw do |entry|
        pre JSON.pretty_generate(entry.attachments_raw || [])
      end
      row :payload do |entry|
        pre JSON.pretty_generate(entry.payload || {})
      end
      row :created_at
      row :updated_at
    end
  end
end
