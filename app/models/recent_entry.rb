# frozen_string_literal: true

class RecentEntry < ApplicationRecord
  acts_as_taggable_on :tags
end
