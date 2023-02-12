# frozen_string_literal: true

class Entry < ApplicationRecord
  acts_as_taggable_on :tags
  validates :url, uniqueness: true
  belongs_to :site, touch: true

  scope :a_day_ago, -> { where(published_at: 1.day.ago..) }
  scope :a_week_ago, -> { where(published_at: 1.week.ago..) }
  scope :a_month_ago, -> { where(published_at: 1.month.ago..) }
  scope :has_image, -> { where.not(image_url: nil) }
  scope :has_interactions, -> { where(total_count: 10..) }
  scope :has_any_interactions, -> { where(total_count: 1..) }

  before_save :set_published_date

  def all_tags
    response = tags.map(&:name)
    tags.each do |tag|
      response << tag.variations.gsub(', ', ',').split(',') if tag.variations
    end
    response.uniq.flatten
  end

  def generate_bigrams
    regex = /([A-ZÀ-Ö][a-zø-ÿ]{3,})\s([A-ZÀ-Ö][a-zø-ÿ]{3,})/
    bad_words = ['Noticias', 'Internacional', 'Radio', 'Noticiero', 'Desde']
    bigrams = []
    words = title.split
    words.each_cons(2).each do |bigram|
      tag = bigram.join(' ')
      bigrams << tag if tag.match(regex) && !contains_substring?(tag, bad_words)
    end
    bigrams
  end

  private

  def set_published_date
    self.published_date = published_at.to_date if published_at.present?
  end

  def contains_substring?(string, substrings)
    substrings.any? { |substring| string.scan(substring).any? }
  end
end
