# frozen_string_literal: true

every :hour do
  rake 'crawler'
  rake 'update_site_stats'
end

every 3.hours do
  rake 'tagger'
end
