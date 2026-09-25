# frozen_string_literal: true

namespace :performance do
  desc 'Compare tag query SQL, results, timing, and query plans for a topic'
  task :tagged_entries, %i[topic_id days] => :environment do |_task, args|
    topic_id = args[:topic_id].presence || abort('Usage: rake performance:tagged_entries[TOPIC_ID,DAYS]')
    days = (args[:days].presence || DAYS_RANGE).to_i
    topic = Topic.find(topic_id)
    start_time = days.days.ago.beginning_of_day
    end_time = Time.current
    tag_names = topic.tags.pluck(:name)
    tag_ids = topic.tags.pluck(:id)

    abort("Topic #{topic.id} has no tags") if tag_ids.empty?

    base_scope = Entry.enabled.where(published_at: start_time..end_time)
    scopes = {
      tagged_with: base_scope.tagged_with(tag_names, any: true, on: :tags),
      tag_ids_exists: base_scope.with_any_tag_ids(tag_ids, context: :tags)
    }
    connection = ActiveRecord::Base.connection

    puts "Topic: #{topic.id} - #{topic.name}"
    puts "Range: #{start_time}..#{end_time} (#{days} days)"
    puts "Database: #{connection.adapter_name} #{connection.database_version}"

    results =
      scopes.transform_values do |scope|
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ids = scope.order(:id).pluck(:id)
        elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000

        { ids: ids, elapsed_ms: elapsed_ms }
      end

    puts "\nParity: #{results[:tagged_with][:ids] == results[:tag_ids_exists][:ids] ? 'PASS' : 'FAIL'}"

    scopes.each do |name, scope|
      daily_totals = scope.group(:published_date).sum(:total_count)
      top_ids = scope.order(total_count: :desc).limit(10).pluck(:id)
      sql = scope.to_sql

      puts "\n#{name}:"
      puts "  Rows: #{results[name][:ids].size}"
      puts "  Load time: #{results[name][:elapsed_ms].round(2)}ms"
      puts "  Daily totals: #{daily_totals}"
      puts "  Top 10 IDs: #{top_ids.join(', ')}"
      puts "  SQL: #{sql}"

      begin
        puts "  EXPLAIN FORMAT=JSON: #{connection.select_value("EXPLAIN FORMAT=JSON #{sql}")}"
      rescue ActiveRecord::StatementInvalid => e
        puts "  EXPLAIN FORMAT=JSON unavailable: #{e.message.lines.first.strip}"
        puts "  EXPLAIN: #{connection.select_all("EXPLAIN #{sql}").to_a}"
      end

      begin
        puts "  EXPLAIN ANALYZE: #{connection.select_all("EXPLAIN ANALYZE #{sql}").to_a}"
      rescue ActiveRecord::StatementInvalid => e
        puts "  EXPLAIN ANALYZE unavailable: #{e.message.lines.first.strip}"
      end
    end
  end
end
