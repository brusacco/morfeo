# frozen_string_literal: true

class RecentEntry < ApplicationRecord
  acts_as_taggable_on :tags
  belongs_to :site, touch: true
end
