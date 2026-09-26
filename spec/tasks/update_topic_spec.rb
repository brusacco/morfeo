# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'TopicUpdateCacheInvalidation' do
  before(:all) do
    load Rails.root.join('lib/tasks/update_topic.rake') unless defined?(TopicUpdateCacheInvalidation)
  end

  it 'invalidates every topic-specific dashboard namespace and Home' do
    expect(TopicUpdateCacheInvalidation.service_cache_patterns(42)).to eq(
      [
        'topic_42_*',
        'digital_dashboard:v3:topic:42:*',
        'facebook_dashboard:v3:topic:42:*',
        'facebook_dashboard:v4:topic:42:*',
        'twitter_dashboard:v3:topic:42:*',
        'twitter_dashboard:v4:topic:42:*',
        'instagram_dashboard:v3:topic:42:*',
        'instagram_dashboard:v4:topic:42:*',
        'general_dashboard:v3:topic:42:*',
        'general_dashboard:v4:topic:42:*',
        'home_dashboard:v3:*',
        'home_dashboard:v4:*'
      ]
    )
  end
end
