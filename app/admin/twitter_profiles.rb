# frozen_string_literal: true

ActiveAdmin.register TwitterProfile do
  menu parent: 'Settings', label: 'Twitter Profiles'
  permit_params :uid, :name, :username, :picture, :followers, :description, :verified, :site_id

  filter :uid, as: :string
  filter :name, as: :string
  filter :username, as: :string
  filter :verified, as: :boolean

  index do
    id_column
    column 'Image' do |profile|
      if profile.picture.present?
        image_tag profile.picture, size: 50
      else
        image_tag 'default-entry.svg', size: 50
      end
    end

    column :name
    column :username do |profile|
      "@#{profile.username}" if profile.username.present?
    end
    column :followers do |profile|
      number_with_delimiter(profile.followers)
    end
    column :verified do |profile|
      if profile.verified
        status_tag('Verified', class: 'ok')
      else
        status_tag('Not Verified', class: 'error')
      end
    end
    column :site
    actions
  end

  show do
    attributes_table do
      row 'Image' do |profile|
        if profile.picture.present?
          image_tag profile.picture, size: 200
        else
          image_tag 'default-entry.svg', size: 200
        end
      end
      row :uid
      row :name
      row :username do |profile|
        "@#{profile.username}" if profile.username.present?
      end
      row :description
      row :followers do |profile|
        number_with_delimiter(profile.followers)
      end
      row :verified do |profile|
        if profile.verified
          status_tag('Verified', class: 'ok')
        else
          status_tag('Not Verified', class: 'error')
        end
      end
      row :site
      row :created_at
      row :updated_at
    end
  end

  # Custom action to manually update profile data from Twitter API
  member_action :update_profile, method: :post do
    result = resource.update_from_api
    if result[:success]
      redirect_to resource_path(resource), notice: result[:message]
    else
      redirect_to resource_path(resource), alert: result[:message]
    end
  end

  action_item :update_profile, only: :show do
    link_to 'Update from Twitter API',
            update_profile_admin_twitter_profile_path(twitter_profile),
            method: :post,
            class: 'button'
  end

  form do |f|
    unless f.object.new_record?
      panel 'Twitter Profile' do
        "<h2>#{f.object.name}</h2>".html_safe
      end
    end
    f.inputs 'Twitter Profile' do
      f.input :uid, required: true, hint: 'Twitter User ID (numeric)'
      f.input :site, required: false
      f.actions
    end
  end
end
