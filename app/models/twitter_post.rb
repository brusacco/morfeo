# frozen_string_literal: true

class TwitterPost < ApplicationRecord
  belongs_to :twitter_profile
  belongs_to :entry, optional: true
  acts_as_taggable_on :tags

  validates :tweet_id, presence: true, uniqueness: true
  validates :twitter_profile, presence: true
  validates :posted_at, presence: true

  scope :recent, -> { order(posted_at: :desc) }
  scope :for_profile,
        lambda { |profile_uid|
          joins(:twitter_profile).where(twitter_profiles: { uid: profile_uid })
        }
  scope :within_range,
        lambda { |start_time, end_time|
          where(posted_at: start_time..end_time)
        }
  scope :for_tags,
        lambda { |tag_names|
          tag_names.present? ? tagged_with(tag_names, any: true) : all
        }

  def self.for_topic(topic, start_time: DAYS_RANGE.days.ago.beginning_of_day, end_time: Time.zone.now.end_of_day)
    tag_names = topic.tags.pluck(:name)
    for_tags(tag_names).within_range(start_time, end_time).includes(twitter_profile: :site).recent
  end

  def self.grouped_counts(scope = all, format: '%d/%m')
    scope.except(:includes).reorder(nil).group_by_day(:posted_at, format:).count(:id)
  end

  def self.grouped_interactions(scope = all, format: '%d/%m')
    scope.except(:includes).reorder(nil).group_by_day(
      :posted_at,
      format:
    ).sum(Arel.sql('favorite_count + retweet_count + reply_count'))
  end

  def self.total_interactions(scope = all)
    relation = scope.except(:includes).reorder(nil)
    relation.sum(:favorite_count) + relation.sum(:retweet_count) + relation.sum(:reply_count)
  end

  def self.total_views(scope = all)
    scope.except(:includes).reorder(nil).sum(:views_count)
  end

  def self.word_occurrences(scope = all, limit = 100)
    occurrences = Hash.new(0)
    scope.find_each do |post|
      post.words.each { |word| occurrences[word] += 1 }
    end
    occurrences.select { |_word, count| count > 1 }
               .sort_by { |_, count| -count }
               .first(limit)
  end

  def self.bigram_occurrences(scope = all, limit = 100)
    occurrences = Hash.new(0)
    scope.find_each do |post|
      post.bigrams.each { |bigram| occurrences[bigram] += 1 if bigram.present? }
    end
    occurrences.select { |_bigram, count| count > 1 }
               .sort_by { |_, count| -count }
               .first(limit)
  end

  def total_interactions
    favorite_count + retweet_count + reply_count + quote_count
  end

  def words
    tokens = text.to_s.downcase.scan(/[[:alpha:]]+/)
    tokens.reject { |word| word.length <= 2 || STOP_WORDS.include?(word) }
  end

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

  def tweet_url
    return unless twitter_profile&.username && tweet_id

    "https://twitter.com/#{twitter_profile.username}/status/#{tweet_id}"
  end

  def site
    twitter_profile&.site
  end

  # Get the post type for display
  def post_type
    return 'Retweet' if is_retweet
    return 'Quote' if is_quote
    return 'Video' if has_video?
    return 'Imagen' if has_images?
    return 'Link' if has_external_url?
    'Tweet'
  end

  # Check if tweet has video
  def has_video?
    return false unless payload

    parsed_payload = parse_payload
    return false unless parsed_payload

    media_array = parsed_payload.dig('legacy', 'extended_entities', 'media') ||
                  parsed_payload.dig('legacy', 'entities', 'media') ||
                  []
    
    media_array.any? { |m| m['type'] == 'video' || m['type'] == 'animated_gif' }
  rescue StandardError
    false
  end

  # Extract images from the tweet media
  def tweet_images
    return [] unless payload

    parsed_payload = parse_payload
    return [] unless parsed_payload

    images = []

    # Try extended_entities first (contains all media including multiple images)
    # Fall back to entities.media if extended_entities is not available
    media_array = parsed_payload.dig('legacy', 'extended_entities', 'media') ||
                  parsed_payload.dig('legacy', 'entities', 'media') ||
                  []

    # Filter for photos and extract their URLs
    photos = media_array.select { |m| m['type'] == 'photo' }
                        .map { |m| m['media_url_https'] || m['media_url'] }
                        .compact
    images.concat(photos)

    # If no photos found, check for link preview card images
    if images.empty?
      card_image = extract_card_image(parsed_payload)
      images << card_image if card_image
    end

    images
  rescue StandardError => e
    Rails.logger.error("[TwitterPost#tweet_images] Failed to parse media for tweet #{tweet_id}: #{e.message}")
    []
  end

  # Get the first image from the tweet
  def primary_image
    tweet_images.first
  end

  # Check if tweet has images
  def has_images?
    tweet_images.any?
  end

  # Extract card image from link preview
  def card_image
    return unless payload

    parsed_payload = parse_payload
    return unless parsed_payload

    extract_card_image(parsed_payload)
  rescue StandardError => e
    Rails.logger.error("[TwitterPost#card_image] Failed to parse card for tweet #{tweet_id}: #{e.message}")
    nil
  end

  # Extract external URLs from the tweet (news articles, etc.)
  def external_urls
    return [] unless payload

    parsed_payload = parse_payload
    return [] unless parsed_payload

    entities = parsed_payload.dig('legacy', 'entities')
    return [] unless entities

    urls = entities['urls'] || []
    urls.map { |url_obj| url_obj['expanded_url'] }
        .compact
  rescue StandardError => e
    Rails.logger.error("[TwitterPost#external_urls] Failed to parse payload for tweet #{tweet_id}: #{e.message}")
    []
  end

  # Get the first external URL (most common case for news tweets)
  def primary_url
    external_urls.first
  end

  # Check if tweet has external URLs
  def has_external_url?
    external_urls.any?
  end

  # Try to find a matching Entry based on the primary URL
  def find_matching_entry
    return unless has_external_url?

    Entry.find_by(url: primary_url)
  end

  # Link this tweet to an Entry if a match is found
  def link_to_entry!
    return false unless has_external_url?

    matching_entry = find_matching_entry
    return false unless matching_entry

    update(entry: matching_entry)
  end

  private

  # Parse payload handling different formats
  def parse_payload
    case payload
    when Hash
      payload
    when String
      if payload.include?('=>')
        # Ruby inspected hash string - convert to proper JSON first
        json_string = payload.gsub('=>', ':')
        JSON.parse(json_string)
      else
        # JSON string
        JSON.parse(payload)
      end
    else
      nil
    end
  end

  # Extract image from Twitter card (link preview)
  def extract_card_image(parsed_payload)
    # Check for card object in different possible locations
    card = parsed_payload['card'] ||
           parsed_payload.dig('legacy', 'card') ||
           parsed_payload.dig('tweet_card', 'legacy')

    return nil unless card

    # Get binding_values which contains the card data
    binding_values = card['binding_values'] || card.dig('legacy', 'binding_values')
    return nil unless binding_values

    # Try different image key patterns used by Twitter
    image_keys = [
      'photo_image_full_size_large',  # Large photo cards
      'photo_image_full_size',        # Standard photo cards
      'summary_photo_image_large',    # Summary cards with large image
      'summary_photo_image',          # Summary cards with image
      'thumbnail_image_large',        # Thumbnail large
      'thumbnail_image',              # Thumbnail
      'player_image_large',           # Player cards (videos)
      'player_image'                  # Player cards
    ]

    # Search through binding_values array for image
    image_keys.each do |key|
      image_data = binding_values.find { |bv| bv['key'] == key }
      next unless image_data

      # Extract URL from the value structure
      image_url = image_data.dig('value', 'image_value', 'url') ||
                  image_data.dig('value', 'string_value')

      return image_url if image_url&.start_with?('http')
    end

    nil
  end
end
