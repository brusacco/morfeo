# frozen_string_literal: true

stop = Rails.root.join('stop-words.txt').readlines.map(&:strip)
STOP_WORDS = stop << ['fbclid']
DAYS_RANGE = 7
