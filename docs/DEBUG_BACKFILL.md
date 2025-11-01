# Production Backfill Debug Commands

Run these to diagnose why the backfill didn't create associations:

## 1. Check if entries have tags

```bash
bin/rails runner "
puts 'Checking entries with tags...'
with_tags = Entry.where.not(tag_list: []).count rescue Entry.joins(:taggings).distinct.count
puts 'Entries with tags: ' + with_tags.to_s
puts 'Total entries: ' + Entry.count.to_s

# Sample some entries
puts ''
puts 'Sample entries:'
Entry.limit(10).each do |e|
  tags = e.tag_list rescue []
  puts '  Entry ' + e.id.to_s + ': ' + tags.join(', ')
end
"
```

## 2. Check if topics have tags

```bash
bin/rails runner "
puts 'Checking topics with tags...'
Topic.limit(10).each do |t|
  tag_count = t.tags.count
  puts t.name + ': ' + tag_count.to_s + ' tags'
  if tag_count > 0
    puts '  Tags: ' + t.tags.pluck(:name).join(', ')
  end
end
"
```

## 3. Test manual sync on one entry

```bash
bin/rails runner "
puts 'Testing manual sync...'

# Find an entry with tags
entry = Entry.joins(:taggings).first
if entry
  puts 'Entry ID: ' + entry.id.to_s
  puts 'Tags: ' + entry.tag_list.join(', ')
  
  # Try to sync manually
  begin
    entry.sync_topics_from_tags
    puts 'Sync executed'
    puts 'Topics after sync: ' + entry.topics.count.to_s
    
    # Check what topics match
    matching = Topic.joins(:tags).where(tags: { name: entry.tag_list }).distinct
    puts 'Matching topics: ' + matching.count.to_s
    matching.each { |t| puts '  - ' + t.name }
  rescue => e
    puts 'ERROR: ' + e.message
    puts e.backtrace.first(5).join('\n')
  end
else
  puts 'No entries with tags found'
end
"
```

## 4. Check backfill log for errors

```bash
# Check production log for errors during backfill
tail -100 log/production.log | grep -E "Entry|Error|sync"

# Or if you have the backfill log
tail -100 log/backfill*.log
```

## 5. Verify methods exist

```bash
bin/rails runner "
puts 'Checking if sync methods exist...'
entry = Entry.first
puts 'sync_topics_from_tags exists: ' + entry.respond_to?(:sync_topics_from_tags, true).to_s
puts 'sync_title_topics_from_tags exists: ' + entry.respond_to?(:sync_title_topics_from_tags, true).to_s
"
```

## 6. Check if callbacks are registered

```bash
bin/rails runner "
puts 'Checking callbacks...'
callbacks = Entry._save_callbacks.select { |cb| cb.filter.to_s.include?('sync') }
puts 'Sync callbacks registered: ' + callbacks.size.to_s
callbacks.each { |cb| puts '  ' + cb.filter.to_s }
"
```

## Common Issues:

### Issue 1: Methods are private
If sync methods are private, the backfill job can't call them.

**Fix:** The methods should be public. Check if they're in a `private` section.

### Issue 2: No tags in production
If entries don't have tags, nothing will sync.

**Fix:** This is OK, but verify some entries DO have tags.

### Issue 3: acts_as_taggable_on not working
Tags might not be properly set up.

**Fix:** Check taggings table exists and has data.

### Issue 4: Silent errors
Errors might be caught and logged but not shown.

**Fix:** Check `log/production.log` for error messages.

---

## Quick Test - Try Manual Backfill on 1 Entry

```bash
bin/rails runner "
puts '=' * 80
puts 'Manual Backfill Test - Single Entry'
puts '=' * 80

# Find entry with tags
entry = Entry.joins(:taggings).where(taggable_type: 'Entry').first

if entry
  puts 'Entry ID: ' + entry.id.to_s
  puts 'URL: ' + entry.url
  
  # Get tags
  tags = entry.tag_list
  puts 'Tags: ' + tags.join(', ')
  
  if tags.any?
    # Find matching topics
    matching_topics = Topic.joins(:tags).where(tags: { name: tags }).distinct
    puts 'Matching topics: ' + matching_topics.count.to_s
    
    if matching_topics.any?
      matching_topics.each { |t| puts '  - ' + t.name }
      
      # Try to associate
      begin
        entry.topics = matching_topics
        puts 'Associated successfully!'
        puts 'Verification: ' + entry.topics.count.to_s + ' topics'
        
        # Check database
        et_count = EntryTopic.where(entry_id: entry.id).count
        puts 'EntryTopic records: ' + et_count.to_s
      rescue => e
        puts 'ERROR: ' + e.message
      end
    else
      puts 'No matching topics found'
      puts 'This means entry tags dont match any topic tags'
    end
  else
    puts 'Entry has no tags'
  end
else
  puts 'No entries with taggings found'
  puts 'Check: Entry.joins(:taggings).count'
end

puts '=' * 80
"
```

Run these commands and share the output so I can help debug!

