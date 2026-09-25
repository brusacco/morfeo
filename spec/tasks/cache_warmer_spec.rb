# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'cache:clear' do
  before(:all) do
    load Rails.root.join('lib/tasks/cache_warmer.rake') unless Rake::Task.task_defined?('cache:clear')
  end

  it 'invalidates every v3 dashboard namespace' do
    allow(Rails.cache).to receive(:delete_matched)
    task = Rake::Task['cache:clear']
    task.reenable

    task.execute

    %w[
      digital_dashboard:v3:*
      facebook_dashboard:v3:*
      twitter_dashboard:v3:*
      instagram_dashboard:v3:*
      general_dashboard:v3:*
      home_dashboard:v3:*
    ].each do |pattern|
      expect(Rails.cache).to have_received(:delete_matched).with(pattern).once
    end
  end
end
