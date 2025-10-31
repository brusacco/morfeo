# frozen_string_literal: true

class FacebookEntry < ApplicationRecord
  belongs_to :page
  belongs_to :entry, optional: true
  acts_as_taggable_on :tags

  validates :facebook_post_id, presence: true, uniqueness: true
  validates :page, presence: true
  validates :posted_at, presence: true

  before_save :calculate_views_count
  before_save :calculate_sentiment_analysis, if: :reactions_changed?

  # Sentiment labels enum
  enum sentiment_label: {
    very_negative: 0,
    negative: 1,
    neutral: 2,
    positive: 3,
    very_positive: 4
  }

  # Sentiment weights based on research
  SENTIMENT_WEIGHTS = {
    reactions_like_count: 0.5,
    reactions_love_count: 2.0,
    reactions_haha_count: 1.5,
    reactions_wow_count: 1.0,
    reactions_sad_count: -1.5,
    reactions_angry_count: -2.0,
    reactions_thankful_count: 2.0
  }.freeze

  scope :recent, -> { order(posted_at: :desc) }
  scope :linked, -> { where.not(entry_id: nil) }
  scope :unlinked, -> { where(entry_id: nil) }
  scope :with_url, -> { where.not(attachment_target_url: nil).or(where.not(attachment_url: nil)) }
  scope :for_page,
        lambda { |page_uid|
          joins(:page).where(pages: { uid: page_uid })
        }
  scope :within_range,
        lambda { |start_time, end_time|
          where(posted_at: start_time..end_time)
        }
  scope :for_tags,
        lambda { |tag_names|
          tag_names.present? ? tagged_with(tag_names, any: true) : all
        }
  
  # Sentiment thresholds
  CONTROVERSY_THRESHOLD = 0.6  # Posts with >60% polarization
  HIGH_EMOTION_THRESHOLD = 2.0  # Emotional reactions > 2x normal likes

  # Sentiment scopes
  scope :positive_sentiment, -> { where(sentiment_label: [:positive, :very_positive]) }
  scope :negative_sentiment, -> { where(sentiment_label: [:negative, :very_negative]) }
  scope :neutral_sentiment, -> { where(sentiment_label: :neutral) }
  scope :controversial, -> { where('controversy_index > ?', CONTROVERSY_THRESHOLD) }
  scope :high_emotion, -> { where('emotional_intensity > ?', HIGH_EMOTION_THRESHOLD) }

  def self.for_topic(topic, start_time: DAYS_RANGE.days.ago.beginning_of_day, end_time: Time.zone.now.end_of_day)
    tag_names = topic.tags.pluck(:name)
    for_tags(tag_names).within_range(start_time, end_time).includes(page: :site).recent
  end

  def self.grouped_counts(scope = all, format: '%d/%m')
    scope.except(:includes).reorder(nil).group_by_day(:posted_at, format:).count(:id)
  end

  def self.grouped_interactions(scope = all, format: '%d/%m')
    scope.except(:includes).reorder(nil).group_by_day(
      :posted_at,
      format:
    ).sum(Arel.sql('reactions_total_count + comments_count + share_count'))
  end

  def self.total_interactions(scope = all)
    relation = scope.except(:includes).reorder(nil)
    relation.sum(:reactions_total_count) + relation.sum(:comments_count) + relation.sum(:share_count)
  end

  def self.total_views(scope = all)
    scope.except(:includes).reorder(nil).sum(:views_count)
  end

  def self.word_occurrences(scope = all, limit = 100)
    occurrences = Hash.new(0)
    scope.find_each do |entry|
      entry.words.each { |word| occurrences[word] += 1 }
    end
    occurrences.select { |_word, count| count > 1 }
               .sort_by { |_, count| -count }
               .first(limit)
  end

  def self.bigram_occurrences(scope = all, limit = 100)
    occurrences = Hash.new(0)
    scope.find_each do |entry|
      entry.bigrams.each { |bigram| occurrences[bigram] += 1 if bigram.present? }
    end
    occurrences.select { |_bigram, count| count > 1 }
               .sort_by { |_, count| -count }
               .first(limit)
  end

  def total_reactions
    reactions_total_count
  end

  def total_interactions
    reactions_total_count + comments_count + share_count
  end

  def attachment_image_dimensions
    return unless attachment_media_width.present? && attachment_media_height.present?

    [attachment_media_width, attachment_media_height]
  end

  def words
    tokens = message.to_s.downcase.scan(/[[:alpha:]]+/)
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

  # Get the post type for display
  def post_type
    return 'Video' if attachment_type == 'video_autoplay' || attachment_type == 'video_inline'
    return 'Foto' if attachment_type == 'photo'
    return 'Album' if attachment_type == 'album'
    return 'Link' if attachment_type == 'share' || has_external_url?
    return 'Evento' if attachment_type == 'event'
    return 'Encuesta' if attachment_type == 'poll'
    'Publicación'
  end

  # Estimated views calculation based on engagement metrics
  # Formula: (likes * 15) + (comments * 40) + (shares * 80) + (followers * 0.04)
  def estimated_views
    likes = reactions_like_count || 0
    comments = comments_count || 0
    shares = share_count || 0
    followers = page&.followers || 0

    (likes * 15) + (comments * 40) + (shares * 80) + (followers * 0.04)
  end

  # Extract external URLs from the Facebook post (news articles, etc.)
  # Uses attachment_target_url or attachment_url as primary URL sources
  def external_urls
    urls = []
    urls << attachment_target_url if attachment_target_url.present?
    urls << attachment_url if attachment_url.present? && attachment_url != attachment_target_url
    urls.compact.uniq
  end

  # Get the first external URL (most common case for news posts)
  def primary_url
    attachment_target_url.presence || attachment_url.presence
  end

  # Check if post has external URLs
  def has_external_url?
    primary_url.present?
  end

  # Try to find a matching Entry based on the primary URL
  def find_matching_entry
    return unless has_external_url?

    url = primary_url
    normalized_urls = normalize_url(url)

    # Try each normalized variation
    normalized_urls.each do |normalized_url|
      entry = Entry.find_by(url: normalized_url)
      return entry if entry
    end

    nil
  end

  # Link this Facebook post to an Entry if a match is found
  def link_to_entry!
    return false unless has_external_url?

    matching_entry = find_matching_entry
    return false unless matching_entry

    update(entry: matching_entry)
  end

  # ============================================
  # SENTIMENT ANALYSIS METHODS
  # ============================================

  def calculate_sentiment_analysis
    return if reactions_total_count.zero?
    
    self.sentiment_score = calculate_weighted_sentiment_score
    self.sentiment_label = determine_sentiment_label(sentiment_score)
    
    # Calculate distribution percentages
    positive = reactions_like_count + reactions_love_count + reactions_haha_count + 
               reactions_wow_count + reactions_thankful_count
    negative = reactions_sad_count + reactions_angry_count
    
    self.sentiment_positive_pct = (positive.to_f / reactions_total_count * 100).round(2)
    self.sentiment_negative_pct = (negative.to_f / reactions_total_count * 100).round(2)
    self.sentiment_neutral_pct = (100 - sentiment_positive_pct - sentiment_negative_pct).round(2)
    
    # Calculate controversy index
    self.controversy_index = calculate_controversy_index(positive, negative)
    
    # Calculate emotional intensity
    self.emotional_intensity = calculate_emotional_intensity
  end
  
  def calculate_weighted_sentiment_score
    return 0.0 if reactions_total_count.zero?
    
    weighted_sum = 0.0
    
    SENTIMENT_WEIGHTS.each do |reaction_field, weight|
      count = send(reaction_field) || 0
      weighted_sum += count * weight
    end
    
    (weighted_sum / reactions_total_count.to_f).round(2)
  end
  
  def determine_sentiment_label(score)
    case score
    when 1.5..Float::INFINITY
      :very_positive
    when 0.5..1.5
      :positive
    when -0.5..0.5
      :neutral
    when -1.5..-0.5
      :negative
    else
      :very_negative
    end
  end
  
  def calculate_controversy_index(positive, negative)
    return 0.0 if reactions_total_count.zero?
    
    balance = ((positive - negative).abs.to_f / reactions_total_count)
    controversy = 1.0 - balance
    controversy.round(4)
  end
  
  def calculate_emotional_intensity
    intense_reactions = reactions_love_count + reactions_angry_count + 
                       reactions_sad_count + reactions_wow_count + 
                       reactions_thankful_count
    
    (intense_reactions.to_f / ([reactions_like_count, 1].max)).round(4)
  end
  
  # Human-readable sentiment label with emoji
  def sentiment_text
    case sentiment_label
    when 'very_positive'
      '😊 Muy Positivo'
    when 'positive'
      '🙂 Positivo'
    when 'neutral'
      '😐 Neutral'
    when 'negative'
      '☹️ Negativo'
    when 'very_negative'
      '😠 Muy Negativo'
    else
      '❓ Sin clasificar'
    end
  end
  
  # Color for sentiment display
  def sentiment_color
    case sentiment_label
    when 'very_positive'
      'text-green-700 bg-green-50 border-green-200'
    when 'positive'
      'text-green-600 bg-green-50 border-green-100'
    when 'neutral'
      'text-gray-600 bg-gray-50 border-gray-200'
    when 'negative'
      'text-red-600 bg-red-50 border-red-100'
    when 'very_negative'
      'text-red-700 bg-red-50 border-red-200'
    else
      'text-gray-500 bg-gray-50 border-gray-200'
    end
  end

  private

  # Normalize URL to try different variations for matching
  def normalize_url(url)
    return [] if url.blank?

    variations = []

    # 1. Exact URL
    variations << url

    # 2. Without query parameters or fragments
    clean_url = url.split('?').first.split('#').first
    variations << clean_url unless variations.include?(clean_url)

    # 3. Without trailing slash
    without_slash = clean_url.chomp('/')
    variations << without_slash unless variations.include?(without_slash)

    # 4. Protocol variations (http vs https)
    # Many sites use both, Entry table might have different protocol than Facebook
    [url, clean_url, without_slash].each do |variant|
      if variant.start_with?('http://')
        https_variant = variant.sub('http://', 'https://')
        variations << https_variant unless variations.include?(https_variant)
      elsif variant.start_with?('https://')
        http_variant = variant.sub('https://', 'http://')
        variations << http_variant unless variations.include?(http_variant)
      end
    end

    # 5. WWW variations
    if url.include?('www.')
      variations << url.sub('www.', '')
      variations << clean_url.sub('www.', '')
    elsif url.match?(%r{\Ahttps?://(?!www\.)})
      # Try adding www
      with_www = url.sub(%r{(https?://)}i, '\1www.')
      variations << with_www unless variations.include?(with_www)
    end

    variations.compact.uniq
  end

  def calculate_views_count
    self.views_count = estimated_views.round
  end
  
  def reactions_changed?
    changed.any? { |attr| attr.start_with?('reactions_') }
  end
end
