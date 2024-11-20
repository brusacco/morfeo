# frozen_string_literal: true

class Entry < ApplicationRecord
  acts_as_taggable_on :tags
end
