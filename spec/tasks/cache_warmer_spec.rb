# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'cache:clear' do
  before(:all) do
    load Rails.root.join('lib/tasks/cache_warmer.rake') unless Rake::Task.task_defined?('cache:clear')
  end

  it 'invalidates every dashboard namespace, including all Home cache generations' do
    allow(Rails.cache).to receive(:delete_matched)
    task = Rake::Task['cache:clear']
    task.reenable

    task.execute

    %w[
      digital_dashboard:v3:*
      digital_dashboard:v4:*
      facebook_dashboard:v3:*
      facebook_dashboard:v4:*
      twitter_dashboard:v3:*
      twitter_dashboard:v4:*
      instagram_dashboard:v3:*
      instagram_dashboard:v4:*
      general_dashboard:v3:*
      general_dashboard:v4:*
      home_dashboard:v3:*
      home_dashboard:v4:*
      home_dashboard:v5:*
    ].each do |pattern|
      expect(Rails.cache).to have_received(:delete_matched).with(pattern).once
    end
  end

  it 'warms user-specific Home dashboard topic sets' do
    allow(HomeServices::CacheWarmerService).to receive(:call).and_return([])
    task = Rake::Task['cache:warm_dashboards']
    task.reenable

    task.execute

    expect(HomeServices::CacheWarmerService).to have_received(:call).once
  end
end
