# frozen_string_literal: true

class TwitterProfile < ApplicationRecord
  belongs_to :site, optional: true
  has_many :twitter_posts, dependent: :destroy

  validates :uid, presence: true
  validates :uid, uniqueness: true

  after_create :update_attributes
  after_update :update_site_image

  private

  # Updates the Twitter profile's attributes based on the Twitter API data.
  def update_attributes
    response = TwitterServices::UpdateProfile.call(uid)
    update!(response.data) if response.success?
    update_site_image
  end

  # Updates the site's image based on the Twitter profile picture.
  def update_site_image
    site.save_image(picture) if site.present? && picture.present?
  end
end
