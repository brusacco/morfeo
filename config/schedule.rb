# frozen_string_literal: true

set :environment, 'production'

every :hour do
  rake 'crawler'
  # rake 'headless_crawler'
  rake 'proxy_crawler'
  rake 'update_stats'
  # rake 'update_api'
  rake 'update_site_stats'
  rake 'update_dates'
  rake 'clean_site_content'
  rake 'category'
  rake 'topic_stat_daily'
  rake 'title_topic_stat_daily'
end

every 3.hours do
  rake 'facebook:fanpage_crawler'
  rake 'twitter:profile_crawler_full'
  rake 'twitter:link_to_entries'
  rake 'twitter:post_tagger'
  # rake 'facebook:comment_crawler'
end

every 4.hours do
  rake 'repeated_notes'
  rake 'title_tagger'
  rake 'facebook:entry_tagger'
end

every 6.hours do
  rake 'crawler_deep'
  rake 'ai:generate_ai_reports'
  rake 'ai:set_topic_polarity'
  rake 'facebook:update_fanpages'
end
