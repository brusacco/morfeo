# frozen_string_literal: true

class Site < ApplicationRecord
  has_many :newspaper, dependent: :destroy

  validates :name, uniqueness: true
  validates :url, uniqueness: true

  has_many :entries, dependent: :destroy
  has_one :page, dependent: :destroy
  has_one :twitter_profile, dependent: :destroy
  has_one :instagram_profile, dependent: :destroy

  scope :enabled, -> { where(status: true) }
  scope :disabled, -> { where(status: false) }
  scope :js_site, -> { where(is_js: true) }
  scope :entry_none, -> { enabled.where(entries_count: 0) }

  def save_image(url)
    response = HTTParty.get(url)
    update!(image64: Base64.strict_encode64(response.body))
  end

  def image
    if image64
      image_tag(
        "data:image/jpeg;base64,#{image64}",
        size: 50,
        class: 'h-10 w-10 flex-shrink-0 rounded-full bg-gray-300'
      )
    else
      image_tag('default-entry.svg', size: 50, class: 'h-10 w-10 flex-shrink-0 rounded-full bg-gray-300')
    end
  end
end
