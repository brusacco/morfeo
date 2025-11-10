# frozen_string_literal: true

class InstagramPost < ApplicationRecord
  # Relationships
  belongs_to :instagram_profile
  belongs_to :entry, optional: true
  acts_as_taggable_on :tags

  # Validations
  validates :shortcode, presence: true, uniqueness: true
  validates :instagram_profile, presence: true
  validates :posted_at, presence: true

  # Callbacks
  after_save :download_post_image, if: :should_download_image?

  # Scopes
  scope :recent, -> { order(posted_at: :desc) }
  scope :for_profile, lambda { |profile_username|
    joins(:instagram_profile).where(instagram_profiles: { username: profile_username })
  }
  scope :within_range, lambda { |start_time, end_time|
    where(posted_at: start_time..end_time)
  }
  scope :for_tags, lambda { |tag_names|
    tag_names.present? ? tagged_with(tag_names, any: true) : all
  }
  scope :videos, -> { where(media_type: 'GraphVideo') }
  scope :images, -> { where(media_type: 'GraphImage') }
  scope :carousels, -> { where(media_type: 'GraphSidecar') }
  scope :reels, -> { where(product_type: 'clips') }
  scope :feed_posts, -> { where(product_type: 'feed') }

  # Class methods for topic filtering
  def self.for_topic(topic, start_time: DAYS_RANGE.days.ago.beginning_of_day, end_time: Time.zone.now.end_of_day)
    tag_names = topic.tags.pluck(:name)
    for_tags(tag_names).within_range(start_time, end_time).includes(instagram_profile: :site).recent
  end

  # Grouped counts by date
  def self.grouped_counts(scope = all, format: '%d/%m')
    scope.except(:includes).reorder(nil).group_by_day(:posted_at, format:).count(:id)
  end

  # Grouped interactions by date
  def self.grouped_interactions(scope = all, format: '%d/%m')
    scope.except(:includes).reorder(nil).group_by_day(:posted_at, format:).sum(Arel.sql('likes_count + comments_count'))
  end

  # Total interactions for scope
  def self.total_interactions(scope = all)
    scope.except(:includes).reorder(nil).sum(Arel.sql('likes_count + comments_count'))
  end

  # Total views for scope (video posts only)
  def self.total_views(scope = all)
    scope.except(:includes).reorder(nil).sum(:video_view_count)
  end

  # Word occurrences analysis
  def self.word_occurrences(scope = all, limit = 100)
    occurrences = Hash.new(0)
    scope.find_each do |post|
      post.words.each { |word| occurrences[word] += 1 }
    end
    occurrences.select { |_word, count| count > 1 }
               .sort_by { |_, count| -count }
               .first(limit)
  end

  # Bigram occurrences analysis
  def self.bigram_occurrences(scope = all, limit = 100)
    occurrences = Hash.new(0)
    scope.find_each do |post|
      post.bigrams.each { |bigram| occurrences[bigram] += 1 if bigram.present? }
    end
    occurrences.select { |_bigram, count| count > 1 }
               .sort_by { |_, count| -count }
               .first(limit)
  end

  # Instance Methods

  # Total interactions (likes + comments)
  def total_interactions
    likes_count + comments_count
  end

  # Instagram post URL
  def instagram_url
    return unless shortcode.present?

    "https://www.instagram.com/p/#{shortcode}/"
  end

  # Get site through profile relationship
  def site
    instagram_profile&.site
  end

  # Get post type for display
  def post_type
    return 'Reel' if product_type == 'clips'
    return 'Video' if media_type == 'GraphVideo'
    return 'Carrusel' if media_type == 'GraphSidecar'
    return 'Imagen' if media_type == 'GraphImage'
    'Post'
  end

  # Check if post has video
  def has_video?
    media_type == 'GraphVideo' || product_type == 'clips'
  end

  # Check if post is a carousel
  def is_carousel?
    media_type == 'GraphSidecar'
  end

  # Check if post is a reel
  def is_reel?
    product_type == 'clips'
  end

  # Extract words from caption for analysis
  def words
    tokens = caption.to_s.downcase.scan(/[[:alpha:]]+/)
    tokens.reject { |word| word.length <= 2 || STOP_WORDS.include?(word) }
  end

  # Extract bigrams from caption
  def bigrams
    words_array = words
    words_array.each_cons(2).map do |word1, word2|
      bigram = "#{word1} #{word2}"
      # Filter out bigrams where either word is a stop word or too short
      next if STOP_WORDS.include?(word1) || STOP_WORDS.include?(word2)
      next if word1.length <= 2 || word2.length <= 2

      bigram
    end.compact
  end

  # Extract external URLs from caption
  def external_urls
    return [] if caption.blank?

    # Simple URL extraction
    uri_pattern = URI::DEFAULT_PARSER.make_regexp(%w[http https])
    caption.scan(uri_pattern).flatten.compact.uniq
  end

  # Get the first external URL
  def primary_url
    external_urls.first
  end

  # Check if post has external URLs
  def has_external_url?
    external_urls.any?
  end

  # Try to find a matching Entry based on the primary URL
  def find_matching_entry
    return unless has_external_url?

    Entry.find_by(url: primary_url)
  end

  # Link this post to an Entry if a match is found
  def link_to_entry!
    return false unless has_external_url?

    matching_entry = find_matching_entry
    return false unless matching_entry

    update(entry: matching_entry)
  end

  # Estimated reach based on engagement
  # Conservative estimate: total_interactions * 10 (similar to Twitter)
  def estimated_reach
    return 0 if total_interactions.zero?

    # Base: 10x engagement (conservative)
    base_reach = total_interactions * 10

    # Video/Reel multiplier (they get more reach)
    multiplier = has_video? ? 1.5 : 1.0

    (base_reach * multiplier).round
  end

  # Engagement rate (interactions / follower count of profile)
  def engagement_rate
    return 0 if instagram_profile.nil? || instagram_profile.followers.zero?

    ((total_interactions.to_f / instagram_profile.followers) * 100).round(2)
  end

  # Get local post image path (for serving from public directory)
  # Format: /images/instagram/{uid}/{year}/{month}/{day}/{shortcode}.jpg
  def local_post_image_path
    return nil unless instagram_profile&.uid.present? && posted_at.present? && shortcode.present?

    year = posted_at.strftime('%Y')
    month = posted_at.strftime('%m')
    day = posted_at.strftime('%d')

    "/images/instagram/#{instagram_profile.uid}/#{year}/#{month}/#{day}/#{shortcode}.jpg"
  end

  # Check if local post image exists
  def local_image_exists?
    return false unless instagram_profile&.uid.present? && posted_at.present? && shortcode.present?

    year = posted_at.strftime('%Y')
    month = posted_at.strftime('%m')
    day = posted_at.strftime('%d')

    file_path = Rails.root.join('public', 'images', 'instagram', instagram_profile.uid, year, month, day, "#{shortcode}.jpg")
    File.exist?(file_path)
  end

  # Get the best available image URL for display
  # Prefers local image if available, otherwise uses the stored post_image_url field from API
  def display_image_url
    if local_image_exists?
      local_post_image_path
    elsif post_image_url.present?
      # Use the URL from API (could be influencers.com.py or Instagram direct)
      post_image_url
    else
      # Fallback to Instagram media URL pattern (may not always work due to CORS)
      "https://www.instagram.com/p/#{shortcode}/media/?size=l"
    end
  end

  # Download post image from Instagram
  # Uses the new post_image_url field from API as primary source
  # Falls back to constructed Instagram URL if not available
  # NOTE: Only downloads once - skips if image already exists (posts are immutable)
  def download_post_image
    return unless instagram_profile&.uid.present?
    return unless posted_at.present?
    return unless shortcode.present?

    # Use post_image_url as primary source (new API field)
    # Fallback to Instagram's media URL pattern
    image_url = post_image_url.presence || "https://www.instagram.com/p/#{shortcode}/media/?size=l"

    # Create directory structure: public/images/instagram/{uid}/{year}/{month}/{day}/
    year = posted_at.strftime('%Y')
    month = posted_at.strftime('%m')
    day = posted_at.strftime('%d')

    directory = Rails.root.join('public', 'images', 'instagram', instagram_profile.uid, year, month, day)
    FileUtils.mkdir_p(directory) unless File.directory?(directory)

    # Download and save image
    file_path = directory.join("#{shortcode}.jpg")

    # Skip if already exists (posts don't change, no need to re-download)
    return if File.exist?(file_path)

    Rails.logger.info "Attempting to download Instagram post image for #{shortcode} from: #{image_url}"

    response = HTTParty.get(image_url, timeout: 30, follow_redirects: true)

    if response.success?
      File.open(file_path, 'wb') do |file|
        file.write(response.body)
      end
      Rails.logger.info "Successfully downloaded Instagram post image for #{shortcode} (@#{instagram_profile.username}) to: #{file_path}"
      true
    else
      Rails.logger.warn "Could not download Instagram post image for #{shortcode}: HTTP #{response.code}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "Error downloading Instagram post image for #{shortcode}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  private

  # Determine if we should download the image
  # Only download for new posts (not on updates)
  def should_download_image?
    return false unless instagram_profile&.uid.present?
    return false unless posted_at.present?
    return false unless shortcode.present?

    # Only download if this is a new record (just created)
    saved_change_to_id?
  end
end
