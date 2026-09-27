# frozen_string_literal: true

namespace :entities do
  desc 'TEST: Extract entities from the last N entries via the GLiNER API (default 50, no DB writes). ' \
       'Usage: rake entities:test[limit]  (override URL with ENTITY_API_URL)'
  task :test, [:limit] => :environment do |_t, args|
    limit = args[:limit].presence ? Integer(args[:limit], 10) : 50
    api_url = ENV['ENTITY_API_URL'] || 'http://www.morfeo.com.py:8001/v1/entities'
    max_chars = 4_000

    puts '=' * 80
    puts '🔎 ENTITY EXTRACTION TEST (GLiNER gliner2.5-multi-v1)'
    puts '=' * 80
    puts "API:    #{api_url}"
    puts "Limit:  #{limit} entries (most recent, enabled, title+content)"
    puts "Time:   #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    puts '=' * 80
    puts

    entries = Entry.enabled
                   .where('(title IS NOT NULL AND title != :blank) OR (content IS NOT NULL AND content != :blank)', blank: '')
                   .order(published_at: :desc)
                   .limit(limit)
                   .select(:id, :title, :content, :published_at)

    total = entries.count
    puts "Entries to process: #{total}"
    puts

    if total.zero?
      puts 'No entries found with title or content. Nothing to do.'
      return
    end

    processed = 0
    failed = 0
    skipped = 0
    total_entities = 0

    entries.each do |entry|
      text = "#{entry.title.to_s.strip}\n#{entry.content.to_s.strip}".strip
      truncated = text.length > max_chars
      text = text[0, max_chars] if truncated

      if text.blank?
        skipped += 1
        puts "⏭  [#{entry.id}] SKIPPED (blank title+content)"
        next
      end

      result = EntityExtractor::ExtractEntities.call(text: text, api_url: api_url)

      if result.success?
        entities = result.entities
        total_entities += entities.size
        processed += 1

        puts "✅ [#{entry.id}] #{entry.title.to_s.truncate(70)}"
        puts "   published_at: #{entry.published_at}  (#{text.length} chars#{' [truncated]' if truncated})"
        if entities.empty?
          puts '   (no entities found)'
        else
          entities.each do |e|
            puts "   • #{e['type'].ljust(22)} #{e['text']}  (conf: #{format('%.3f', Float(e['confidence'] || 0))})"
          end
        end
      else
        failed += 1
        puts "❌ [#{entry.id}] ERROR calling API for: #{entry.title.to_s.truncate(70)}"
        puts "   #{result.error}"
      end

      puts '-' * 80
    end

    puts
    puts '=' * 80
    puts 'SUMMARY'
    puts '=' * 80
    puts "Processed:  #{processed}"
    puts "Failed:     #{failed}"
    puts "Skipped:    #{skipped}"
    puts "Entities:   #{total_entities} total"
    puts '=' * 80
  end
end
