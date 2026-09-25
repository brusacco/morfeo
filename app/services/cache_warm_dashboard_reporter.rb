# frozen_string_literal: true

class CacheWarmDashboardReporter
  DASHBOARD_NAMES = %i[digital facebook twitter instagram general].freeze
  DEFAULT_WORKERS = 4

  def self.worker_count(value = ENV.fetch('CACHE_WARM_WORKERS', DEFAULT_WORKERS))
    workers = value.to_i
    workers.positive? ? workers : DEFAULT_WORKERS
  end

  def self.slowest_dashboard_calls(results, limit: 10)
    dashboard_calls(results).sort_by { |call| -call[:duration] }.first(limit)
  end

  def self.aggregate_statistics(results)
    DASHBOARD_NAMES.index_with do |dashboard|
      calls = dashboard_calls(results).select { |call| call[:name] == dashboard }
      total = calls.sum { |call| call[:duration] }

      {
        calls: calls.count,
        total: total,
        average: calls.any? ? total / calls.count : 0.0,
        max: calls.map { |call| call[:duration] }.max || 0.0,
        hits: calls.count { |call| call[:cache_status] == :hit },
        misses: calls.count { |call| call[:cache_status] == :miss },
        unknown: calls.count { |call| call[:cache_status].nil? }
      }
    end
  end

  def self.cache_statistics(results)
    calls = dashboard_calls(results)
    hits = calls.count { |call| call[:cache_status] == :hit }
    misses = calls.count { |call| call[:cache_status] == :miss }
    known = hits + misses

    {
      hits: hits,
      misses: misses,
      unknown: calls.count - known,
      hit_rate: known.positive? ? (hits.to_f / known * 100) : 0.0
    }
  end

  def self.dashboard_calls(results)
    results.flat_map do |result|
      result.fetch(:dashboards, {}).map do |name, dashboard|
        dashboard.merge(name: name, topic_id: result[:topic_id], topic_name: result[:topic_name])
      end
    end
  end

  def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, notifications: ActiveSupport::Notifications)
    @clock = clock
    @notifications = notifications
  end

  def warm_topic(topic)
    topic_started_at = @clock.call
    dashboards = {}

    dashboard_definitions(topic).each do |name, invocation|
      dashboards[name] = measure_dashboard(name, &invocation)
    end

    {
      success: dashboards.values.none? { |dashboard| dashboard[:error] },
      topic_id: topic.id,
      topic_name: topic.name,
      duration: @clock.call - topic_started_at,
      dashboards: dashboards
    }
  end

  def print_report(results:, workers:, wall_time:, io: $stdout)
    statistics = self.class.aggregate_statistics(results)
    cache_statistics = self.class.cache_statistics(results)

    io.puts "\nCACHE WARM PERFORMANCE REPORT"
    io.puts
    io.puts "Topics: #{results.count}"
    io.puts "Workers: #{workers}"
    io.puts "Total wall time: #{format_duration(wall_time)}"
    io.puts 'Note: dashboard totals are summed worker time and do not equal wall time.'
    io.puts "\nTOPICS"
    io.puts format('%-28s %8s %8s %8s %9s %8s %8s', 'Topic', 'Digital', 'Facebook', 'Twitter', 'Instagram', 'General', 'Total')
    io.puts '-' * 86

    results.sort_by { |result| -result[:duration] }.each do |result|
      dashboards = result.fetch(:dashboards, {})
      io.puts format(
        '%-28s %8s %8s %8s %9s %8s %8s',
        truncate(result[:topic_name] || "Topic #{result[:topic_id]}", 28),
        *DASHBOARD_NAMES.map { |name| format_duration(dashboards.dig(name, :duration)) },
        format_duration(result[:duration])
      )

      dashboards.each do |name, dashboard|
        io.puts format('  %-10s %8s %s%s', name.to_s.capitalize, format_duration(dashboard[:duration]), cache_status_label(dashboard[:cache_status]), error_label(dashboard))
      end
    end

    io.puts "\nSLOWEST DASHBOARDS"
    self.class.slowest_dashboard_calls(results).each_with_index do |dashboard, index|
      io.puts format('%2d. %-10s / %-28s %8s %s%s', index + 1, dashboard[:name].to_s.capitalize, truncate(dashboard[:topic_name] || "Topic #{dashboard[:topic_id]}", 28), format_duration(dashboard[:duration]), cache_status_label(dashboard[:cache_status]), error_label(dashboard))
    end

    io.puts "\nBY DASHBOARD"
    io.puts format('%-12s %7s %9s %9s %9s %7s %7s %7s', 'Dashboard', 'Calls', 'Total', 'Avg', 'Max', 'Hits', 'Misses', 'Unknown')
    io.puts '-' * 74
    statistics.each do |name, statistic|
      io.puts format('%-12s %7d %9s %9s %9s %7d %7d %7d', name.to_s.capitalize, statistic[:calls], format_duration(statistic[:total]), format_duration(statistic[:average]), format_duration(statistic[:max]), statistic[:hits], statistic[:misses], statistic[:unknown])
    end

    io.puts "\nCache:"
    io.puts "  Hits: #{cache_statistics[:hits]}"
    io.puts "  Misses: #{cache_statistics[:misses]}"
    io.puts "  Unknown: #{cache_statistics[:unknown]}"
    io.puts format('  Hit rate: %.1f%%', cache_statistics[:hit_rate])
  end

  private

  def dashboard_definitions(topic)
    {
      digital: -> { DigitalDashboardServices::AggregatorService.call(topic: topic) },
      facebook: -> { FacebookDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20) },
      twitter: -> { TwitterDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20) },
      instagram: -> { InstagramDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20) },
      general: lambda {
        GeneralDashboardServices::AggregatorService.call(
          topic: topic,
          start_date: DAYS_RANGE.days.ago.beginning_of_day,
          end_date: Time.zone.now.end_of_day
        )
      }
    }
  end

  def measure_dashboard(name)
    generated = false
    cache_read_hit = false
    started_at = @clock.call

    @notifications.subscribed(->(*_) { generated = true }, 'cache_generate.active_support') do
      @notifications.subscribed(->(_name, _started, _finished, _id, payload) { cache_read_hit ||= payload[:hit] }, 'cache_read.active_support') do
        yield
      end
    end

    { name: name, duration: @clock.call - started_at, cache_status: generated ? :miss : (cache_read_hit ? :hit : nil) }
  rescue StandardError => e
    {
      name: name,
      duration: @clock.call - started_at,
      cache_status: generated ? :miss : (cache_read_hit ? :hit : nil),
      error_class: e.class.name,
      error: e.message,
      backtrace: ENV['CACHE_WARM_DEBUG'] == '1' ? e.backtrace&.first(5) : nil
    }
  end

  def format_duration(duration)
    duration ? format('%.2fs', duration) : '-'
  end

  def cache_status_label(status)
    status ? status.to_s.upcase : 'UNKNOWN'
  end

  def error_label(dashboard)
    return '' unless dashboard[:error]

    " ERROR (#{dashboard[:error_class]}: #{dashboard[:error]})"
  end

  def truncate(value, length)
    value.to_s.length > length ? "#{value.to_s[0, length - 3]}..." : value.to_s
  end
end