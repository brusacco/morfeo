class Newspaper < ApplicationRecord
  belongs_to :site
  has_many :newspaper_texts, dependent: :destroy

  has_one_attached :cover
  has_one_attached :backcover

  accepts_nested_attributes_for :newspaper_texts, allow_destroy: true

  validate :date
end
