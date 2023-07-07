# frozen_string_literal: true

STOP_WORDS = Rails.root.join('stop-words.txt').readlines.map(&:strip)
DAYS_RANGE = 7
