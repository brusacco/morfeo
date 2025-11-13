# frozen_string_literal: true

ActiveAdmin.register InstagramProfile do
  menu parent: 'Settings', label: 'Instagram Profiles'
  permit_params :username, :site_id

  filter :username, as: :string
  filter :full_name, as: :string
  filter :is_verified, as: :boolean
  filter :is_business_account, as: :boolean
  filter :profile_type, as: :select, collection: %w[marca persona influencer]

  index do
    id_column
    column 'Image' do |profile|
      if profile.profile_image_url.present?
        image_tag profile.profile_image_url, size: 50
      else
        image_tag 'default-entry.svg', size: 50
      end
    end

    column :full_name
    column :username do |profile|
      "@#{profile.username}" if profile.username.present?
    end
    column :followers do |profile|
      number_with_delimiter(profile.followers)
    end
    column :engagement_rate do |profile|
      "#{profile.engagement_rate}%" if profile.engagement_rate.present?
    end
    column :is_verified do |profile|
      if profile.is_verified
        status_tag('Verified', class: 'ok')
      else
        status_tag('Not Verified', class: 'error')
      end
    end
    column :profile_type do |profile|
      status_tag(profile.profile_type) if profile.profile_type.present?
    end
    column :site
    column :last_synced_at do |profile|
      if profile.last_synced_at.present?
        time_ago_in_words(profile.last_synced_at) + ' ago'
      elsif profile.incomplete?
        status_tag('Never synced - Incomplete', class: 'error')
      else
        status_tag('Never synced', class: 'warning')
      end
    end
    actions
  end

  show do
    attributes_table do
      row 'Image' do |profile|
        if profile.profile_image_url.present?
          image_tag profile.profile_image_url, size: 200
        else
          image_tag 'default-entry.svg', size: 200
        end
      end
      row :uid
      row :username do |profile|
        link_to "@#{profile.username}", profile.instagram_url, target: '_blank'
      end
      row :full_name
      row :biography
      row :profile_type do |profile|
        status_tag(profile.profile_type) if profile.profile_type.present?
      end
      row :followers do |profile|
        number_with_delimiter(profile.followers)
      end
      row :following do |profile|
        number_with_delimiter(profile.following)
      end
      row :is_verified do |profile|
        if profile.is_verified
          status_tag('Verified', class: 'ok')
        else
          status_tag('Not Verified', class: 'error')
        end
      end
      row :is_business_account do |profile|
        profile.is_business_account ? status_tag('Yes', class: 'ok') : status_tag('No')
      end
      row :is_professional_account do |profile|
        profile.is_professional_account ? status_tag('Yes', class: 'ok') : status_tag('No')
      end
      row :is_private do |profile|
        profile.is_private ? status_tag('Private', class: 'warning') : status_tag('Public', class: 'ok')
      end
      row :country_string
      row :category_name
      row :business_category_name
    end

    panel 'Analytics & Metrics' do
      attributes_table_for instagram_profile do
        row :engagement_rate do |profile|
          "#{profile.engagement_rate}%"
        end
        row :total_posts do |profile|
          number_with_delimiter(profile.total_posts)
        end
        row :total_videos do |profile|
          number_with_delimiter(profile.total_videos)
        end
        row :total_likes_count do |profile|
          number_with_delimiter(profile.total_likes_count)
        end
        row :total_comments_count do |profile|
          number_with_delimiter(profile.total_comments_count)
        end
        row :total_video_view_count do |profile|
          number_with_delimiter(profile.total_video_view_count)
        end
        row :total_interactions_count do |profile|
          number_with_delimiter(profile.total_interactions_count)
        end
        row :median_interactions do |profile|
          number_with_delimiter(profile.median_interactions)
        end
        row :median_video_views do |profile|
          number_with_delimiter(profile.median_video_views)
        end
        row :average_engagement do |profile|
          number_with_delimiter(profile.average_engagement.round(2))
        end
      end
    end

    panel 'Reach Estimation' do
      attributes_table_for instagram_profile do
        row :estimated_reach do |profile|
          number_with_delimiter(profile.estimated_reach)
        end
        row :estimated_reach_percentage do |profile|
          "#{profile.estimated_reach_percentage}%"
        end
      end
    end

    panel 'System Information' do
      attributes_table_for instagram_profile do
        row :site
        row :last_synced_at do |profile|
          if profile.last_synced_at.present?
            "#{time_ago_in_words(profile.last_synced_at)} ago (#{profile.last_synced_at.strftime('%Y-%m-%d %H:%M:%S')})"
          else
            'Never synced'
          end
        end
        row :needs_sync do |profile|
          if profile.needs_sync?
            status_tag('Yes - needs update', class: 'warning')
          else
            status_tag('No - up to date', class: 'ok')
          end
        end
        row :sync_status do |profile|
          if profile.incomplete?
            status_tag('Incomplete - Sync failed', class: 'error')
          elsif profile.last_synced_at.present?
            status_tag('Complete', class: 'ok')
          else
            status_tag('Pending initial sync', class: 'warning')
          end
        end
        row :created_at
        row :updated_at
      end
    end

    panel 'Instagram Profile Link' do
      para do
        link_to "Visit @#{instagram_profile.username} on Instagram",
                instagram_profile.instagram_url,
                target: '_blank',
                class: 'button'
      end
    end
  end

  form do |f|
    unless f.object.new_record?
      panel 'Instagram Profile' do
        div do
          if f.object.profile_image_url.present?
            image_tag f.object.profile_image_url, size: 100
          end
        end
        div do
          "<h2>#{f.object.full_name || f.object.username}</h2>".html_safe
        end
        div do
          "@#{f.object.username}"
        end
      end
    end

    f.inputs 'Instagram Profile' do
      if f.object.new_record?
        f.input :username,
                required: true,
                hint: 'Instagram username (without @). Data will be fetched automatically from API.'
      else
        f.input :username,
                required: true,
                hint: 'Instagram username (without @)',
                input_html: { disabled: true }
        para 'Note: Username cannot be changed after creation. Create a new profile if needed.'
      end

      f.input :site,
              required: false,
              hint: 'Optional: Associate with a Site for image sync'
    end

    f.actions do
      if f.object.new_record?
        f.action :submit, label: 'Create Profile & Fetch Data'
      else
        f.action :submit, label: 'Update'
      end
      f.action :cancel, label: 'Cancel'
    end
  end

  # Custom action to manually sync profile data
  member_action :sync, method: :post do
    resource.sync_from_api
    redirect_to resource_path(resource), notice: 'Profile synced successfully!'
  end

  action_item :sync, only: :show do
    link_to 'Sync from API', sync_admin_instagram_profile_path(instagram_profile), method: :post
  end

  # Batch action to sync multiple profiles
  batch_action :sync_profiles do |ids|
    batch_action_collection.find(ids).each do |profile|
      profile.sync_from_api
    end
    redirect_to collection_path, notice: "#{ids.count} profiles synced successfully!"
  end
end

