# frozen_string_literal: true

class FacebookEntry < ApplicationRecord
  belongs_to :page
  acts_as_taggable_on :tags

  validates :facebook_post_id, presence: true, uniqueness: true
  validates :page, presence: true
  validates :posted_at, presence: true

  scope :recent, -> { order(posted_at: :desc) }
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

  def self.word_occurrences(scope = all, limit = 100)
    occurrences = Hash.new(0)
    scope.find_each do |entry|
      entry.words.each { |word| occurrences[word] += 1 }
    end
    occurrences.sort_by { |_, count| -count }
               .first(limit)
  end

  def self.bigram_occurrences(scope = all, limit = 100)
    occurrences = Hash.new(0)
    scope.find_each do |entry|
      entry.bigrams.each { |bigram| occurrences[bigram] += 1 if bigram.present? }
    end
    occurrences.sort_by { |_, count| -count }
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
    stop_words = defined?(STOP_WORDS) ? STOP_WORDS : []
    tokens.reject { |word| word.length <= 1 || stop_words.include?(word) }
  end

  def bigrams
    words.each_cons(2).map { |pair| pair.join(' ') }
  end
end
