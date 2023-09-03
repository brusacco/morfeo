# frozen_string_literal: true

class Site < ApplicationRecord
  validates :name, uniqueness: true
  validates :url, uniqueness: true

  has_many :entries, dependent: :destroy
  has_one :page, dependent: :destroy
end
