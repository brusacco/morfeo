# frozen_string_literal: true

ActiveAdmin.register InstagramPost do
  menu parent: 'Entries Listing', label: 'Instagram Posts'
  includes :instagram_profile

  actions :all, except: %i[new edit destroy]

  filter :shortcode
  filter :instagram_profile, collection: proc { InstagramProfile.order(:full_name) }
  filter :posted_at
  filter :media_type, as: :select, collection: %w[GraphImage GraphVideo GraphSidecar]
  filter :product_type, as: :select, collection: %w[feed clips igtv]
  filter :entry_id, label: 'Linked to Entry'
  filter :created_at

  index do
    selectable_column
    id_column
    column :shortcode do |post|
      link_to post.shortcode, admin_instagram_post_path(post)
    end
    column :instagram_profile do |post|
      link_to post.instagram_profile.display_name, admin_instagram_profile_path(post.instagram_profile)
    end
    column 'Type' do |post|
      status_tag(post.post_type)
    end
    column :posted_at do |post|
      post.posted_at.strftime('%Y-%m-%d %H:%M')
    end
    column 'Linked' do |post|
      if post.entry_id.present?
        status_tag('Yes', class: 'ok')
      else
        status_tag('No', class: 'warning')
      end
    end
    column :tags do |post|
      post.tag_list.map { |tag| status_tag(tag, class: 'info') }.join(' ').html_safe
    end
    column :caption do |post|
      truncate(post.caption, length: 100)
    end
    column :url do |post|
      link_to 'View', post.instagram_url, target: '_blank', rel: 'noopener' if post.instagram_url.present?
    end
    column :likes_count do |post|
      number_with_delimiter(post.likes_count)
    end
    column :comments_count do |post|
      number_with_delimiter(post.comments_count)
    end
    column :video_view_count do |post|
      post.video_view_count ? number_with_delimiter(post.video_view_count) : '-'
    end
    column :total_count do |post|
      number_with_delimiter(post.total_count)
    end
    actions
  end

  show do
    columns do
      column do
        panel 'Post Information' do
          attributes_table_for instagram_post do
            row :shortcode
            row :instagram_profile do |post|
              link_to post.instagram_profile.display_name, admin_instagram_profile_path(post.instagram_profile)
            end
            row :entry do |post|
              if post.entry
                link_to post.entry.title, admin_entry_path(post.entry)
              else
                status_tag('Not Linked', class: 'warning')
              end
            end
            row :posted_at
            row :fetched_at
            row :url do |post|
              link_to post.instagram_url, post.instagram_url, target: '_blank', rel: 'noopener' if post.instagram_url.present?
            end
            row :post_type do |post|
              status_tag(post.post_type)
            end
            row :media_type
            row :product_type
          end
        end

        panel 'Caption' do
          div class: 'whitespace-pre-wrap' do
            instagram_post.caption || '(No caption)'
          end
        end

        panel 'Tags' do
          if instagram_post.tag_list.any?
            div do
              instagram_post.tag_list.map { |tag| status_tag(tag, class: 'info') }.join(' ').html_safe
            end
          else
            status_tag('No tags', class: 'warning')
          end
        end
      end

      column do
        panel 'Engagement Metrics' do
          attributes_table_for instagram_post do
            row :likes_count do |post|
              "❤️ #{number_with_delimiter(post.likes_count)}"
            end
            row :comments_count do |post|
              "💬 #{number_with_delimiter(post.comments_count)}"
            end
            row :video_view_count do |post|
              if post.video_view_count.present?
                "👁️ #{number_with_delimiter(post.video_view_count)}"
              else
                '-'
              end
            end
            row :total_count do |post|
              "📊 #{number_with_delimiter(post.total_count)}"
            end
          end
        end

        panel 'Calculated Metrics' do
          attributes_table_for instagram_post do
            row :total_interactions do |post|
              number_with_delimiter(post.total_interactions)
            end
            row :engagement_rate do |post|
              "#{post.engagement_rate}%"
            end
            row :estimated_reach do |post|
              number_with_delimiter(post.estimated_reach)
            end
          end
        end

        panel 'Additional Info' do
          attributes_table_for instagram_post do
            row :has_video do |post|
              post.has_video? ? status_tag('Yes', class: 'ok') : status_tag('No')
            end
            row :is_carousel do |post|
              post.is_carousel? ? status_tag('Yes', class: 'ok') : status_tag('No')
            end
            row :is_reel do |post|
              post.is_reel? ? status_tag('Yes', class: 'ok') : status_tag('No')
            end
            row :has_external_url do |post|
              post.has_external_url? ? status_tag('Yes', class: 'ok') : status_tag('No')
            end
          end
        end

        if instagram_post.has_external_url?
          panel 'External URLs' do
            ul do
              instagram_post.external_urls.each do |url|
                li do
                  link_to truncate(url, length: 60), url, target: '_blank', rel: 'noopener'
                end
              end
            end
          end
        end

        panel 'System Info' do
          attributes_table_for instagram_post do
            row :id
            row :created_at
            row :updated_at
          end
        end
      end
    end
  end

  # Batch action to tag posts
  batch_action :tag_posts, form: {
    tag: :text
  } do |ids, inputs|
    tag = inputs['tag']
    
    if tag.present?
      InstagramPost.where(id: ids).find_each do |post|
        post.tag_list.add(tag)
        post.save
      end
      redirect_to collection_path, notice: "#{ids.count} posts tagged with '#{tag}'"
    else
      redirect_to collection_path, alert: 'Please provide a tag'
    end
  end

  # Batch action to link posts to entries
  batch_action :link_to_entries do |ids|
    linked = 0
    
    InstagramPost.where(id: ids).find_each do |post|
      if post.link_to_entry!
        linked += 1
      end
    end
    
    redirect_to collection_path, notice: "#{linked} out of #{ids.count} posts linked to entries"
  end
end

