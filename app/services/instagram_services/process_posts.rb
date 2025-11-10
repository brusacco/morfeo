# frozen_string_literal: true

require 'httparty'
require 'json'

module InstagramServices
  # Service to process and save Instagram posts from API
  # Similar to TwitterServices::ProcessPosts
  class ProcessPosts < ApplicationService
    def initialize(username, update_existing: false)
      @username = username
      @update_existing = update_existing
      @token = ENV['INFLUENCERS_TOKEN']
    end

    def call
      return handle_error('Missing INFLUENCERS_TOKEN') if @token.blank?
      return handle_error('Missing username') if @username.blank?

      profile = InstagramProfile.find_by!(username: @username)

      # Get posts from API
      response = InstagramServices::GetPostsData.call(@username)

      return handle_error(response.error) unless response.success?

      data = response.data
      posts_data = data['posts'] || []
      
      return handle_success({ posts: [], count: 0, message: 'No posts found' }) if posts_data.empty?

      saved_posts = []
      
      posts_data.each do |post_data|
        saved_post = persist_post(profile, post_data, @update_existing)
        saved_posts << saved_post if saved_post
      end

      handle_success({ posts: saved_posts, count: saved_posts.count, message: 'Completed' })
    rescue ActiveRecord::RecordNotFound => e
      handle_error("Profile not found: #{e.message}")
    rescue StandardError => e
      handle_error("Unexpected error: #{e.message}")
    end

    private

    def persist_post(profile, post_data, update_existing = false)
      shortcode = post_data['shortcode']
      return unless shortcode.present?

      instagram_post = InstagramPost.find_or_initialize_by(shortcode: shortcode)

      # Return nil if this post already exists and we're not updating
      return unless instagram_post.new_record? || update_existing

      instagram_post.assign_attributes(
        instagram_profile: profile,
        shortcode: shortcode,
        url: post_data['url'],
        caption: post_data['caption'],
        media_type: post_data['media'],
        product_type: post_data['product_type'],
        post_image_url: post_data['post_image_url'], # New direct image URL from API
        posted_at: parse_timestamp(post_data['posted_at']),
        likes_count: post_data['likes_count'] || 0,
        comments_count: post_data['comments_count'] || 0,
        video_view_count: post_data['video_view_count'],
        total_count: post_data['total_count'] || 0,
        fetched_at: Time.current
      )

      instagram_post.save!
      
      # Link to Entry if matching URL is found
      link_to_entry(instagram_post)
      
      # Tag the post using ExtractTags service
      tag_post(instagram_post)
      
      instagram_post
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[InstagramServices::ProcessPosts] Unable to persist post #{shortcode}: #{e.message}")
      nil
    end

    def link_to_entry(instagram_post)
      # Skip if already linked or no URL in caption
      return if instagram_post.entry_id.present?
      return unless instagram_post.has_external_url?

      primary_url = instagram_post.primary_url
      return unless primary_url

      # Try exact match first
      entry = Entry.find_by(url: primary_url)

      # If no exact match, try without query parameters or fragments
      unless entry
        clean_url = primary_url.split('?').first.split('#').first
        entry = Entry.find_by(url: clean_url)
      end

      # Link if found
      if entry
        instagram_post.update(entry: entry)
        Rails.logger.info("[InstagramServices::ProcessPosts] Linked post #{instagram_post.shortcode} to entry #{entry.id} (#{entry.url})")
      else
        Rails.logger.debug("[InstagramServices::ProcessPosts] No matching entry found for URL: #{primary_url}")
      end
    rescue StandardError => e
      # Log linking errors but don't fail the crawl
      Rails.logger.error("[InstagramServices::ProcessPosts] Error linking post #{instagram_post.shortcode}: #{e.message}")
    end

    def tag_post(instagram_post)
      # Use ExtractTags service for consistent tagging logic
      result = InstagramServices::ExtractTags.call(instagram_post.id)
      
      if result.success?
        tags = result.data
        Rails.logger.info("[InstagramServices::ProcessPosts] Tagged post #{instagram_post.shortcode} with tags: #{tags.join(', ')}")
      else
        Rails.logger.debug("[InstagramServices::ProcessPosts] No tags found for post #{instagram_post.shortcode}")
      end
    rescue StandardError => e
      # Log tagging errors but don't fail the crawl
      Rails.logger.error("[InstagramServices::ProcessPosts] Error tagging post #{instagram_post.shortcode}: #{e.message}")
    end

    def parse_timestamp(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end
  end
end

