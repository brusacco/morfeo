# frozen_string_literal: true

class Site < ApplicationRecord
  validates :name, uniqueness: true
  validates :url, uniqueness: true

  has_many :entries, dependent: :destroy
  has_one :page, dependent: :destroy

  def save_image(url)
    response = HTTParty.get(url)
    update!(image64: Base64.strict_encode64(response))
  end

  def image
    if image64
      image_tag(
        "data:image/jpeg;base64,#{site.image64}",
        size: 50,
        class: 'h-10 w-10 flex-shrink-0 rounded-full bg-gray-300'
      )
    else
      image_tag(
        'https://via.placeholder.com/300x300',
        size: 50,
        class: 'h-10 w-10 flex-shrink-0 rounded-full bg-gray-300'
      )
    end
  end
end
