# frozen_string_literal: true

class FacebookEntry < ApplicationRecord
  belongs_to :page

  validates :facebook_post_id, presence: true, uniqueness: true
  validates :page, presence: true
  validates :posted_at, presence: true

  scope :recent, -> { order(posted_at: :desc) }
  scope :for_page,
        lambda { |page_uid|
          joins(:page).where(pages: { uid: page_uid })
        }

  def total_reactions
    reactions_total_count
  end

  def attachment_image_dimensions
    return unless attachment_media_width.present? && attachment_media_height.present?

    [attachment_media_width, attachment_media_height]
  end
end
