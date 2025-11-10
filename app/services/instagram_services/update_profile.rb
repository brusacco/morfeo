# frozen_string_literal: true

require 'httparty'
require 'json'

module InstagramServices
  # Service to update an Instagram profile with fresh data from API
  # Called automatically by InstagramProfile model after create/update
  class UpdateProfile < ApplicationService
    include HTTParty

    base_uri 'https://www.influencers.com.py/api/v1'

    def initialize(username)
      @username = username
      @token = ENV['INFLUENCERS_TOKEN']
    end

    def call
      return handle_error('Missing INFLUENCERS_TOKEN') if @token.blank?
      return handle_error('Missing username') if @username.blank?

      response = self.class.get(
        "/profiles/#{@username}",
        query: { token: @token },
        headers: { 'Content-Type' => 'application/json' },
        timeout: 30
      )

      if response.success?
        data = JSON.parse(response.body)
        handle_success(format_profile_data(data))
      else
        handle_error("API Error: #{response.code} - #{response.message}")
      end
    rescue JSON::ParserError => e
      handle_error("JSON parsing error: #{e.message}")
    rescue HTTParty::Error => e
      handle_error("HTTP error: #{e.message}")
    rescue StandardError => e
      handle_error("Unexpected error: #{e.message}")
    end

    private

    # Format API response data for ActiveRecord update
    def format_profile_data(data)
      {
        uid: data['uid'],
        username: data['username'],
        full_name: data['full_name'],
        biography: data['biography'],
        profile_type: data['profile_type'],
        followers: data['followers'],
        following: data['following'],
        is_verified: data['is_verified'],
        is_business_account: data['is_business_account'],
        is_professional_account: data['is_professional_account'],
        is_private: data['is_private'],
        country_string: data['country_string'],
        category_name: data['category_name'],
        business_category_name: data['business_category_name'],
        profile_pic_url: data['profile_pic_url'],
        profile_pic_url_hd: data['profile_pic_url_hd'],
        engagement_rate: data['engagement_rate'],
        total_posts: data['total_posts'],
        total_videos: data['total_videos'],
        total_likes_count: data['total_likes_count'],
        total_comments_count: data['total_comments_count'],
        total_video_view_count: data['total_video_view_count'],
        total_interactions_count: data['total_interactions_count'],
        median_interactions: data['median_interactions'],
        median_video_views: data['median_video_views'],
        estimated_reach: data['estimated_reach'],
        estimated_reach_percentage: data['estimated_reach_percentage'],
        last_synced_at: Time.current
      }
    end
  end
end

