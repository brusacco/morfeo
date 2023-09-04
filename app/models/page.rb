# frozen_string_literal: true

class Page < ApplicationRecord
  belongs_to :site
  validates :uid, presence: true
  validates :uid, uniqueness: true

  after_create :update_attributes
  after_update :update_site_image

  private

  # Updates the page's attributes based on the Facebook data.
  def update_attributes
    response = FacebookServices::UpdatePage.call(uid)
    update!(response.data) if response.success?
    update_site_image
  end

  # Updates the site's image based on the Facebook data.
  def update_site_image
    site.save_image(picture) if picture.present?
  end
end
