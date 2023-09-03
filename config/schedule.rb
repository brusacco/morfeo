# frozen_string_literal: true

set :environment, 'production'

every :hour do
  rake 'crawler'
  rake 'update_stats'
  rake 'update_site_stats'
end

every 6.hours do
  rake 'crawler_deep'
  rake 'generate_ai_reports'
end
