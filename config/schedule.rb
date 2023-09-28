# frozen_string_literal: true

set :environment, 'production'

every :hour do
  rake 'crawler'
  rake 'update_stats'
  rake 'update_site_stats'
  rake 'clean_site_content'
end

every 2.hours do
  rake 'facebook:fanpage_crawler'
  rake 'facebook:comment_crawler'
end

every 6.hours do
  rake 'crawler_deep'
  rake 'ai:generate_ai_reports'
  rake 'ai:set_topic_polarity'
  rake 'facebook:update_fanpages'
end
