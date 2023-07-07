STOP_WORDS = File.readlines(Rails.root.join('stop-words.txt')).map { |a| a.strip }
DAYS_RANGE = 7