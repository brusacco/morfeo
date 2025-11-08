# frozen_string_literal: true

require 'test_helper'

class TwitterDashboardPresenterTest < ActiveSupport::TestCase
  # Test initialization
  test 'initializes with all twitter dashboard data' do
    topic = topics(:one)
    presenter = TwitterDashboardPresenter.new(
      topic: topic,
      total_posts: 100,
      total_interactions: 5000,
      total_views: 50000,
      average_interactions: 50,
      chart_posts: { Date.today => 10 },
      chart_interactions: { Date.today => 500 },
      tag_counts: [double('Tag', name: 'test', count: 10)],
      tag_interactions: { 'test' => 50 },
      profiles_count: { 'profile1' => 10 },
      profiles_interactions: { 'profile1' => 100 },
      top_posts: [double('Post')],
      posts: [double('Post'), double('Post')],
      viral_content: [{ post: double('Post'), multiplier: 5 }],
      word_occurrences: { 'word' => 10 },
      bigram_occurrences: { 'word pair' => 5 }
    )

    assert_equal topic, presenter.topic
    assert_equal 100, presenter.total_posts
    assert_equal 5000, presenter.total_interactions
    assert_equal 50000, presenter.total_views
    assert_equal 50, presenter.average_interactions
  end

  test 'initializes with empty data' do
    presenter = TwitterDashboardPresenter.new

    assert_equal 0, presenter.total_posts
    assert_equal 0, presenter.total_interactions
    assert_equal 0, presenter.total_views
    assert_equal 0, presenter.average_interactions
    assert_equal({}, presenter.chart_posts)
    assert_equal({}, presenter.chart_interactions)
    assert_equal [], presenter.top_posts
    assert_equal [], presenter.posts
    assert_equal [], presenter.viral_content
  end

  # Test data presence checks
  test 'has_data? returns true when posts present' do
    presenter = TwitterDashboardPresenter.new(total_posts: 10)
    assert presenter.has_data?
  end

  test 'has_data? returns true when posts array present' do
    presenter = TwitterDashboardPresenter.new(posts: [double('Post')])
    assert presenter.has_data?
  end

  test 'has_data? returns false when no data' do
    presenter = TwitterDashboardPresenter.new
    refute presenter.has_data?
  end

  test 'has_viral_content? returns true when viral content present' do
    presenter = TwitterDashboardPresenter.new(viral_content: [{ post: double('Post') }])
    assert presenter.has_viral_content?
  end

  test 'has_viral_content? returns false when no viral content' do
    presenter = TwitterDashboardPresenter.new
    refute presenter.has_viral_content?
  end

  test 'viral_count returns correct count' do
    presenter = TwitterDashboardPresenter.new(
      viral_content: [{ post: double('Post') }, { post: double('Post') }]
    )
    assert_equal 2, presenter.viral_count
  end

  test 'has_word_cloud? returns true when word occurrences present' do
    presenter = TwitterDashboardPresenter.new(word_occurrences: { 'word' => 10 })
    assert presenter.has_word_cloud?
  end

  test 'has_bigram_data? returns true when bigram occurrences present' do
    presenter = TwitterDashboardPresenter.new(bigram_occurrences: { 'word pair' => 5 })
    assert presenter.has_bigram_data?
  end

  test 'has_top_posts? returns true when top posts present' do
    presenter = TwitterDashboardPresenter.new(top_posts: [double('Post')])
    assert presenter.has_top_posts?
  end

  test 'has_tag_data? returns true when tag data present' do
    presenter = TwitterDashboardPresenter.new(tag_counts: [double('Tag')])
    assert presenter.has_tag_data?
  end

  test 'has_profile_data? returns true when profile data present' do
    presenter = TwitterDashboardPresenter.new(profiles_count: { 'profile' => 10 })
    assert presenter.has_profile_data?
  end

  test 'has_chart_data? returns true when chart data present' do
    presenter = TwitterDashboardPresenter.new(chart_posts: { Date.today => 10 })
    assert presenter.has_chart_data?
  end

  # Test formatting methods
  test 'formatted_total_posts returns formatted number' do
    presenter = TwitterDashboardPresenter.new(total_posts: 1000)
    assert_equal '1.000', presenter.formatted_total_posts
  end

  test 'formatted_total_interactions returns formatted number' do
    presenter = TwitterDashboardPresenter.new(total_interactions: 50000)
    assert_equal '50.000', presenter.formatted_total_interactions
  end

  test 'formatted_total_views returns formatted number' do
    presenter = TwitterDashboardPresenter.new(total_views: 1000000)
    assert_equal '1.000.000', presenter.formatted_total_views
  end

  test 'formatted methods return zero for nil values' do
    presenter = TwitterDashboardPresenter.new
    assert_equal '0', presenter.formatted_total_posts
    assert_equal '0', presenter.formatted_total_interactions
    assert_equal '0', presenter.formatted_total_views
  end

  # Test engagement rate calculation
  test 'engagement_rate calculates correctly' do
    presenter = TwitterDashboardPresenter.new(
      total_interactions: 1000,
      total_views: 10000
    )
    assert_equal 10.0, presenter.engagement_rate
  end

  test 'engagement_rate returns zero when no views' do
    presenter = TwitterDashboardPresenter.new(total_interactions: 1000)
    assert_equal 0.0, presenter.engagement_rate
  end

  test 'has_views_data? returns true when views present' do
    presenter = TwitterDashboardPresenter.new(total_views: 1000)
    assert presenter.has_views_data?
  end

  test 'has_views_data? returns false when no views' do
    presenter = TwitterDashboardPresenter.new
    refute presenter.has_views_data?
  end

  # Test KPI cards
  test 'kpi_cards returns array of card configurations' do
    presenter = TwitterDashboardPresenter.new(
      total_posts: 100,
      total_interactions: 5000,
      total_views: 50000,
      average_interactions: 50
    )
    
    cards = presenter.kpi_cards
    assert_equal 4, cards.size
    assert_instance_of Hash, cards.first
    assert cards.first.key?(:title)
    assert cards.first.key?(:value)
    assert cards.first.key?(:icon)
  end

  # Test chart configs
  test 'chart_configs returns posts and interactions configs' do
    data_posts = { Date.today => 10 }
    data_interactions = { Date.today => 500 }
    
    presenter = TwitterDashboardPresenter.new(
      chart_posts: data_posts,
      chart_interactions: data_interactions
    )
    
    configs = presenter.chart_configs
    assert_equal 2, configs.size
    assert configs.key?(:posts)
    assert configs.key?(:interactions)
    assert_equal data_posts, configs[:posts][:data]
    assert_equal 'twitterPostsChart', configs[:posts][:chart_id]
  end

  # Test tag chart data
  test 'tag_counts_chart_data transforms tag counts for chart' do
    tag1 = double('Tag', name: 'tag1', count: 10)
    tag2 = double('Tag', name: 'tag2', count: 20)
    
    presenter = TwitterDashboardPresenter.new(tag_counts: [tag1, tag2])
    
    chart_data = presenter.tag_counts_chart_data
    assert_equal({ 'tag1' => 10, 'tag2' => 20 }, chart_data)
  end

  test 'tag_counts_chart_data returns empty hash when no tags' do
    presenter = TwitterDashboardPresenter.new
    assert_equal({}, presenter.tag_counts_chart_data)
  end

  # Test configuration
  test 'config returns correct structure' do
    presenter = TwitterDashboardPresenter.new
    config = presenter.config

    assert config.key?(:colors)
    assert config.key?(:chart_colors)
    assert_equal '#0ea5e9', config[:colors][:primary]
    assert_instance_of Array, config[:chart_colors][:tag_counts]
  end

  test 'color returns hex code for key' do
    presenter = TwitterDashboardPresenter.new
    
    assert_equal '#0ea5e9', presenter.color(:primary)
    assert_equal '#10b981', presenter.color(:success)
    assert_equal '#0ea5e9', presenter.color(:nonexistent) # defaults to primary
  end

  test 'chart_colors returns color array for chart type' do
    presenter = TwitterDashboardPresenter.new
    
    colors = presenter.chart_colors(:tag_counts)
    assert_instance_of Array, colors
    assert colors.any?
    assert_match(/^#[0-9a-fA-F]{6}$/, colors.first) # validates hex format
  end

  test 'chart_colors returns empty array for unknown type' do
    presenter = TwitterDashboardPresenter.new
    assert_equal [], presenter.chart_colors(:unknown_type)
  end

  private

  # Simple double helper for tests
  def double(name)
    Struct.new(:name, :count).new(name, nil)
  end
end

