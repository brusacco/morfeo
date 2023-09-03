# frozen_string_literal: true

class Page < ApplicationRecord
  belongs_to :site
  validates :uid, presence: true
  validates :uid, uniqueness: true

  after_create :update_attributes

  private

  # Updates the page's attributes based on the Facebook data.
  def update_attributes
    response = FacebookServices::UpdatePage.call(uid)
    update!(response.data) if response.success?
  end
end
