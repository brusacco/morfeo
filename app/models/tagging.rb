# frozen_string_literal: true

class Tagging < ApplicationRecord
  belongs_to :tag, touch: true
  belongs_to :taggable, polymorphic: true
end
