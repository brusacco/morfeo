# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TwitterDashboardPresenter do
  let(:topic) { create(:topic) }

  it 'exposes the dashboard metrics' do
    presenter = described_class.new(
      topic: topic,
      total_posts: 100,
      total_interactions: 5000,
      total_views: 50_000,
      average_interactions: 50,
      chart_posts: { Date.today => 10 },
      chart_interactions: { Date.today => 500 },
      tag_counts: [Struct.new(:name, :count).new('test', 10)],
      tag_interactions: { 'test' => 50 },
      profiles_count: { 'profile1' => 10 },
      profiles_interactions: { 'profile1' => 100 },
      top_posts: [Object.new],
      posts: [Object.new, Object.new],
      viral_content: [{ post: Object.new, multiplier: 5 }],
      word_occurrences: { 'word' => 10 },
      bigram_occurrences: { 'word pair' => 5 }
    )

    expect(presenter.topic).to eq(topic)
    expect(presenter.total_posts).to eq(100)
    expect(presenter.total_interactions).to eq(5000)
    expect(presenter.total_views).to eq(50_000)
    expect(presenter.average_interactions).to eq(50)
    expect(presenter.has_data?).to be(true)
    expect(presenter.has_viral_content?).to be(true)
    expect(presenter.viral_count).to eq(1)
    expect(presenter.has_word_cloud?).to be(true)
    expect(presenter.has_bigram_data?).to be(true)
    expect(presenter.has_top_posts?).to be(true)
    expect(presenter.has_tag_data?).to be(true)
    expect(presenter.has_profile_data?).to be(true)
    expect(presenter.has_chart_data?).to be(true)
    expect(presenter.formatted_total_posts).to eq('100')
    expect(presenter.formatted_total_interactions).to eq('5.000')
    expect(presenter.formatted_total_views).to eq('50.000')
    expect(presenter.engagement_rate).to eq(10.0)
    expect(presenter.has_views_data?).to be(true)
    expect(presenter.kpi_cards.size).to eq(4)
    expect(presenter.chart_configs[:posts][:chart_id]).to eq('twitterPostsChart')
    expect(presenter.tag_counts_chart_data).to eq('test' => 10)
    expect(presenter.config[:colors][:primary]).to eq('#0ea5e9')
    expect(presenter.color(:primary)).to eq('#0ea5e9')
    expect(presenter.chart_colors(:tag_counts)).to be_an(Array)
  end

  it 'handles empty data' do
    presenter = described_class.new

    expect(presenter.total_posts).to eq(0)
    expect(presenter.total_interactions).to eq(0)
    expect(presenter.total_views).to eq(0)
    expect(presenter.average_interactions).to eq(0)
    expect(presenter.chart_posts).to eq({})
    expect(presenter.chart_interactions).to eq({})
    expect(presenter.top_posts).to eq([])
    expect(presenter.posts).to eq([])
    expect(presenter.viral_content).to eq([])
    expect(presenter.has_data?).to be(false)
    expect(presenter.has_viral_content?).to be(false)
    expect(presenter.has_views_data?).to be(false)
  end
end
