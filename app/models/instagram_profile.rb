# frozen_string_literal: true

class InstagramProfile < ApplicationRecord
  # Relationships
  belongs_to :site, optional: true
  has_many :instagram_posts, dependent: :destroy

  # Tagging
  acts_as_taggable_on :tags

  # Validations
  validates :uid, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true

  # Callbacks
  before_validation :fetch_uid_from_api, on: :create
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
    
    "/images/instagram/#{uid}/avatar.jpg"
  end

  # Check if local image exists
  def local_image_exists?
    return false unless uid.present?
    
    File.exist?(Rails.root.join('public', 'images', 'instagram', uid, 'avatar.jpg'))
  end

  # Get profile image URL (local if available, otherwise Instagram URL)
  def profile_image_url
    if local_image_exists?
      local_profile_image_path
    else
      profile_pic_url_hd.presence || profile_pic_url
    end
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

    result = InstagramServices::GetProfileData.call(username)
    
    if result.success?
      self.uid = result.data['uid']
    else
      Rails.logger.error "Failed to fetch UID for @#{username}: #{result.error}"
      errors.add(:username, "could not fetch profile data from Instagram API: #{result.error}")
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching UID for @#{username}: #{e.message}"
    errors.add(:username, "error connecting to Instagram API: #{e.message}")
  end

  # Updates the Instagram profile's attributes from API
  def update_profile_data
    result = InstagramServices::UpdateProfile.call(username)
    
    if result.success?
      update!(result.data)
      update_site_image
      download_profile_image # Always download image on sync
    else
      Rails.logger.error "Failed to update Instagram profile @#{username}: #{result.error}"
    end
  rescue StandardError => e
    Rails.logger.error "Error in update_profile_data for @#{username}: #{e.message}"
  end

  # Updates the associated site's image from Instagram profile picture
  def update_site_image
    return unless site.present? && profile_pic_url_hd.present?
    
    site.save_image(profile_pic_url_hd)
  rescue StandardError => e
    Rails.logger.error "Error updating site image for Instagram profile @#{username}: #{e.message}"
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

    # Create directory if it doesn't exist
    directory = Rails.root.join('public', 'images', 'instagram', uid)
    FileUtils.mkdir_p(directory)
    
    # Download and save image as avatar.jpg (overwrites if exists)
    file_path = directory.join('avatar.jpg')
    
    Rails.logger.info "Attempting to download Instagram profile image for @#{username} from: #{image_url}"
    
    response = HTTParty.get(image_url, timeout: 30, follow_redirects: true)
    
    if response.success?
      File.open(file_path, 'wb') do |file|
        file.write(response.body)
      end
      Rails.logger.info "Successfully downloaded Instagram profile image for @#{username} to: #{file_path}"
      true
    else
      Rails.logger.error "Failed to download Instagram profile image for @#{username}: HTTP #{response.code}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "Error downloading Instagram profile image for @#{username}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end
end
