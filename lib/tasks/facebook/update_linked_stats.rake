namespace :facebook do
  desc 'Update Entry stats from linked Facebook posts for the last week'
  task update_linked_stats: :environment do
    puts 'Starting Facebook linked stats update...'

    end_time = Time.current
    start_time = end_time - 1.week

    puts "Processing Facebook posts from #{start_time.strftime('%Y-%m-%d')} to #{end_time.strftime('%Y-%m-%d')}"

    facebook_posts = FacebookEntry.within_range(start_time, end_time).linked.with_url.includes(:entry)

    puts "Found #{facebook_posts.count} linked Facebook posts with URLs from the last week"

    if facebook_posts.empty?
      puts 'No Facebook posts to process. Task completed.'
      next
    end

    updated_entries = 0
    skipped = 0

    facebook_posts.each do |fb_post|
      entry = fb_post.entry
      reactions = fb_post.reactions_total_count || 0
      comments  = fb_post.comments_count || 0
      shares    = fb_post.share_count || 0
      total     = reactions + comments + shares

      entry.update!(reaction_count: reactions, comment_count: comments, share_count: shares, total_count: total)

      updated_entries += 1
      puts "✓ Entry ##{entry.id} (#{entry.title&.truncate(50)}): #{reactions} reactions, #{comments} comments, #{shares} shares"
    rescue StandardError => e
      skipped += 1
      puts "✗ ERROR on FacebookEntry ##{fb_post.id}: #{e.message}"
    end

    puts "\n" + ('=' * 60)
    puts "✓ Done! Entries updated: #{updated_entries} | Skipped: #{skipped}"
    puts '=' * 60
  end
end
