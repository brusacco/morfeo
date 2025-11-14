# frozen_string_literal: true

class InstagramProfile < ApplicationRecord
  # Relationships
  belongs_to :site, optional: true
  has_many :instagram_posts, dependent: :destroy

  # Tagging
  acts_as_taggable_on :tags

  # Validations
  # validates :uid, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true

  # Callbacks
  before_validation :fetch_uid_from_api, if: :new_record?
  after_create :update_profile_data
  after_update :update_site_image
  after_save :download_profile_image, if: :should_download_avatar?

  # Scopes
  scope :active, -> { where('last_synced_at >= ?', 7.days.ago) }
  scope :verified, -> { where(is_verified: true) }
  scope :business_accounts, -> { where(is_business_account: true) }
  scope :public_profiles, -> { where(is_private: false) }
  scope :by_engagement, -> { order(engagement_rate: :desc) }
  scope :by_followers, -> { order(followers: :desc) }

  # Instance Methods

  # Calculate engagement rate
  # Formula: (total_interactions / (total_posts * followers)) * 100
  def calculate_engagement_rate
    return 0 if total_posts.zero? || followers.zero?

    ((total_interactions_count.to_f / (total_posts * followers)) * 100).round(2)
  end

  # Get Instagram profile URL
  def instagram_url
    "https://www.instagram.com/#{username}/"
  end

  # Check if profile needs sync (older than 24 hours)
  def needs_sync?
    last_synced_at.nil? || last_synced_at < 24.hours.ago
  end

  # Check if profile data is incomplete (only has uid/username, missing other fields)
  def incomplete?
    return false if last_synced_at.present? # If synced at least once, consider it complete
    return true if full_name.blank? && followers.zero? # Missing basic data
    false
  end

  # Get recent posts (from has_many relationship)
  def recent_posts(limit = 10)
    instagram_posts.order(posted_at: :desc).limit(limit)
  end

  # Get average engagement per post
  def average_engagement
    return 0 if total_posts.zero?

    (total_interactions_count.to_f / total_posts).round(2)
  end

  # Get total reach
  def total_reach
    estimated_reach
  end

  # Display name (full_name or username)
  def display_name
    full_name.presence || username
  end

  # Get local profile image path (for serving from public directory)
  def local_profile_image_path
    return nil unless uid.present?

    "/images/instagram/#{uid.to_s}/avatar.jpg"
  end

  # Check if local image exists
  def local_image_exists?
    return false unless uid.present?

    file_path = Rails.root.join('public', 'images', 'instagram', uid.to_s, 'avatar.jpg')
    File.exist?(file_path)
  end

  # Get profile image URL (local if available, otherwise Instagram URL)
  # ALWAYS prefers local file if it exists to avoid CORS and improve performance
  def profile_image_url
    return nil unless uid.present?

    # Always check for local file first
    if local_image_exists?
      return local_profile_image_path
    end

    # Fallback to API URLs only if local file doesn't exist
    avatar_image_url.presence || profile_pic_url_hd.presence || profile_pic_url
  end

  # Public method to sync profile data from API (callable from admin/controllers)
  def sync_from_api
    update_profile_data
  end

  private

  # Fetches uid from API before validation (on create only)
  # This ensures uid is present when validation runs
  def fetch_uid_from_api
    return if uid.present? # Skip if uid already set
    return unless username.present? # Need username to fetch

    # Use UpdateProfile service which formats data correctly and includes uid
    result = InstagramServices::UpdateProfile.call(username)

    if result.success? && result.data.present?
      # Try both symbol and string keys for uid
      fetched_uid = result.data[:uid] || result.data['uid']

      if fetched_uid.present?
        self.uid = fetched_uid.to_s
      else
        errors.add(:username, "Instagram API did not return a user ID. The profile may not exist or may be private.")
      end
    elsif result.success? && result.data.blank?
      errors.add(:username, "Instagram API returned empty data. The profile may not exist.")
    else
      error_message = result.error || "Unknown error"
      errors.add(:username, "could not fetch profile data from Instagram API: #{error_message}")
    end
  rescue StandardError => e
    errors.add(:username, "error connecting to Instagram API: #{e.message}")
  end

  # Updates the Instagram profile's attributes from API
  def update_profile_data
    result = InstagramServices::UpdateProfile.call(username)

    if result.success? && result.data.present?
      begin
        update!(result.data)
        update_site_image
        download_profile_image # Always download image on sync
      rescue ActiveRecord::RecordInvalid, StandardError
        raise if Rails.env.development?
      end
    else
      error_msg = result.error || "Unknown error - result.data is blank"
      raise "Failed to fetch profile data: #{error_msg}" if Rails.env.development?
    end
  rescue StandardError
    raise if Rails.env.development?
  end

  # Updates the associated site's image from Instagram profile picture
  # Only updates if the site does NOT have a Facebook page assigned (FB has priority)
  def update_site_image
    # Use avatar_image_url as primary source (from API), fallback to other fields if needed
    image_url = avatar_image_url.presence || profile_pic_url_hd.presence || profile_pic_url.presence
    return unless site.present? && image_url.present?

    # Check if site has a Facebook page - if so, skip (Facebook updates the image)
    return if site.page.present?

    # Only update if no Facebook page exists
    site.save_image(image_url)
  rescue StandardError
    # Silently fail - image update is not critical
  end

  # Check if avatar image should be downloaded
  # Triggers when any of the avatar URL fields change
  def should_download_avatar?
    saved_change_to_avatar_image_url? ||
    saved_change_to_profile_pic_url_hd? ||
    saved_change_to_profile_pic_url?
  end

  # Downloads profile image from Instagram and saves locally
  # Avoids CORS issues by serving from local public directory
  # NOTE: Always downloads and overwrites existing image (profile pictures can change)
  def download_profile_image
    return unless uid.present?

    # Use avatar_image_url as the primary source (new API field)
    # Fallback to profile_pic_url_hd or profile_pic_url if not available
    image_url = avatar_image_url.presence || profile_pic_url_hd.presence || profile_pic_url.presence

    return unless image_url.present?

    # Create directory if it doesn't exist (ensure uid is string)
    directory = Rails.root.join('public', 'images', 'instagram', uid.to_s)
    FileUtils.mkdir_p(directory)

    # Download and save image as avatar.jpg (overwrites if exists)
    file_path = directory.join('avatar.jpg')

    response = HTTParty.get(image_url, timeout: 30, follow_redirects: true)

    if response.success?
      File.open(file_path, 'wb') do |file|
        file.write(response.body)
      end
      true
    else
      false
    end
  rescue StandardError
    false
  end
end
