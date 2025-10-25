# frozen_string_literal: true

class TwitterPost < ApplicationRecord
  belongs_to :twitter_profile
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
    occurrences.sort_by { |_, count| -count }
               .first(limit)
  end

  def self.bigram_occurrences(scope = all, limit = 100)
    occurrences = Hash.new(0)
    scope.find_each do |post|
      post.bigrams.each { |bigram| occurrences[bigram] += 1 if bigram.present? }
    end
    occurrences.sort_by { |_, count| -count }
               .first(limit)
  end

  def total_interactions
    favorite_count + retweet_count + reply_count + quote_count
  end

  def words
    tokens = text.to_s.downcase.scan(/[[:alpha:]]+/)
    stop_words = defined?(STOP_WORDS) ? STOP_WORDS : []
    tokens.reject { |word| word.length <= 1 || stop_words.include?(word) }
  end

  def bigrams
    words.each_cons(2).map { |pair| pair.join(' ') }
  end

  def tweet_url
    return unless twitter_profile&.username && tweet_id

    "https://twitter.com/#{twitter_profile.username}/status/#{tweet_id}"
  end
end
