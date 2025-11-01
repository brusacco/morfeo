# frozen_string_literal: true

namespace :entry_topics do
  desc "Validate Entry-Topic associations match tagging"
  task validate: :environment do
    puts "\n" + "=" * 80
    puts "Entry-Topic Association Validation"
    puts "=" * 80

    # Test all active topics
    Topic.active.each do |topic|
      validate_topic(topic)
    end

    puts "\n" + "=" * 80
    puts "Validation complete!"
    puts "=" * 80
  end

  desc "Validate specific topic by ID"
  task :validate_topic, [:topic_id] => :environment do |t, args|
    topic = Topic.find(args[:topic_id])
    validate_topic(topic, verbose: true)
  end

  desc "Performance benchmark old vs new"
  task :benchmark, [:topic_id] => :environment do |t, args|
    require 'benchmark'

    topic = Topic.find(args[:topic_id])

    puts "\n" + "=" * 80
    puts "Performance Benchmark: #{topic.name}"
    puts "=" * 80

    # Warm up
    Entry.enabled.tagged_with(topic.tag_names, any: true).count
    topic.entries.enabled.count

    # Old method (tagged_with)
    old_time = Benchmark.measure do
      Entry.enabled
           .where(published_at: 30.days.ago..)
           .tagged_with(topic.tag_names, any: true)
           .to_a
    end

    # New method (direct association)
    new_time = Benchmark.measure do
      topic.entries
           .enabled
           .where(published_at: 30.days.ago..)
           .to_a
    end

    puts "\nResults:"
    puts "  Old method (tagged_with): #{(old_time.real * 1000).round(2)}ms"
    puts "  New method (association): #{(new_time.real * 1000).round(2)}ms"

    if new_time.real < old_time.real
      improvement = ((old_time.real - new_time.real) / old_time.real * 100).round(1)
      puts "  ✅ #{improvement}% FASTER"
    else
      degradation = ((new_time.real - old_time.real) / old_time.real * 100).round(1)
      puts "  ⚠️  #{degradation}% SLOWER"
    end

    puts "=" * 80
  end

  def validate_topic(topic, verbose: false)
    print "Testing #{topic.name}... "

    # Count entries via old method (tagged_with)
    old_count = Entry.enabled.tagged_with(topic.tag_names, any: true).count

    # Count entries via new method (association)
    new_count = topic.entries.enabled.count

    # Count title entries
    old_title_count = Entry.enabled.tagged_with(topic.tag_names, any: true, on: :title_tags).count
    new_title_count = topic.title_entries.enabled.count

    # Check match
    tags_match = old_count == new_count
    title_tags_match = old_title_count == new_title_count

    if tags_match && title_tags_match
      puts "✅ PASS"
    else
      puts "❌ FAIL"
      puts "  Tags: #{old_count} (old) vs #{new_count} (new)"
      puts "  Title: #{old_title_count} (old) vs #{new_title_count} (new)"
    end

    if verbose
      puts "\nDetailed Results:"
      puts "  Regular tags:"
      puts "    tagged_with: #{old_count}"
      puts "    association: #{new_count}"
      puts "    Match: #{tags_match ? '✅' : '❌'}"
      puts "\n  Title tags:"
      puts "    tagged_with: #{old_title_count}"
      puts "    association: #{new_title_count}"
      puts "    Match: #{title_tags_match ? '✅' : '❌'}"
    end
  rescue => e
    puts "❌ ERROR: #{e.message}"
  end
end

