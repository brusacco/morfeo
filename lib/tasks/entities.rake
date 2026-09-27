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

  desc 'Extract entities from the last N entries (default 50) and PERSIST them ' \
       '(confidence > 0.9). Usage: rake entities:extract[limit]'
  task :extract, [:limit] => :environment do |_t, args|
    limit = args[:limit].presence ? Integer(args[:limit], 10) : 50
    max_chars = 4_000
    min_confidence = EntityExtractor::PersistEntities::MIN_CONFIDENCE

    puts '=' * 80
    puts '💾 ENTITY EXTRACTION + PERSIST (GLiNER gliner2.5-multi-v1)'
    puts '=' * 80
    puts "Limit:  #{limit} entries (most recent, enabled, title+content)"
    puts "Min confidence: #{min_confidence} (lower detections are ignored)"
    puts "Time:   #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    puts '=' * 80
    puts

    base_scope = Entry.enabled
                      .where('(title IS NOT NULL AND title != :blank) OR (content IS NOT NULL AND content != :blank)', blank: '')

    # Resolve the "last N entries" set up front (ids only), then stream it in
    # batches by id so we never hold more than one batch in memory.
    ids = base_scope.order(published_at: :desc).limit(limit).pluck(:id)
    total = ids.size
    puts "Entries to process: #{total}"
    puts

    if total.zero?
      puts 'No entries found with title or content. Nothing to do.'
      return
    end

    min_id = ids.min

    processed = 0
    failed = 0
    skipped = 0
    total_entities_created = 0
    total_mentions_created = 0
    total_ignored = 0

    base_scope
      .where(id: min_id..Float::INFINITY)
      .select(:id, :title, :content, :published_at)
      .in_batches(of: 100, order: :asc) do |batch|
        batch.each do |entry|
          text = "#{entry.title.to_s.strip}\n#{entry.content.to_s.strip}".strip
          text = text[0, max_chars] if text.length > max_chars

          if text.blank?
            skipped += 1
            puts "⏭  [#{entry.id}] SKIPPED (blank title+content)"
            next
          end

          result = EntityExtractor::PersistEntities.call(text: text, content: entry)

          if result.success?
            processed += 1
            total_entities_created += result.entities_created
            total_mentions_created += result.mentions_created
            total_ignored += result.ignored

            puts "✅ [#{entry.id}] #{entry.title.to_s.truncate(70)}"
            puts "   entities: +#{result.entities_created}  mentions: +#{result.mentions_created}  ignored(<=#{min_confidence}): #{result.ignored}"
          else
            failed += 1
            puts "❌ [#{entry.id}] ERROR: #{entry.title.to_s.truncate(70)}"
            puts "   #{result.error}"
          end

          puts '-' * 80
        end
      end

    puts
    puts '=' * 80
    puts 'SUMMARY'
    puts '=' * 80
    puts "Processed:        #{processed}"
    puts "Failed:           #{failed}"
    puts "Skipped:          #{skipped}"
    puts "Entities created: #{total_entities_created}"
    puts "Mentions created: #{total_mentions_created}"
    puts "Ignored (<=#{min_confidence}): #{total_ignored}"
    puts '=' * 80
  end
end
