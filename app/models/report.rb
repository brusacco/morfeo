# frozen_string_literal: true

class Report < ApplicationRecord
  belongs_to :topic, touch: true
end
