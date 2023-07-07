# frozen_string_literal: true

set :environment, 'production'

every :hour do
  rake 'crawler'
  rake 'update_stats'
  rake 'update_site_stats'
end

every 3.hours do
  # rake 'tagger'
  rake 'update_tw_stats'
  rake 'crawler_deep'
end
