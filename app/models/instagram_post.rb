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
    scope.except(:includes).reorder(nil).group_by_day(:posted_at, format:).sum(:total_count)
  end

  # Total interactions for scope
  def self.total_interactions(scope = all)
    scope.except(:includes).reorder(nil).sum(:total_count)
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
  # Conservative estimate: total_count * 10 (similar to Twitter)
  def estimated_reach
    return 0 if total_count.zero?
    
    # Base: 10x engagement (conservative)
    base_reach = total_count * 10
    
    # Video/Reel multiplier (they get more reach)
    multiplier = has_video? ? 1.5 : 1.0
    
    (base_reach * multiplier).round
  end

  # Engagement rate (interactions / follower count of profile)
  def engagement_rate
    return 0 if instagram_profile.nil? || instagram_profile.followers.zero?
    
    ((total_interactions.to_f / instagram_profile.followers) * 100).round(2)
  end
end
