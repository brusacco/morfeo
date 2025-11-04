# Configurable Facebook Pagination - Complete ✅

**Date**: November 4, 2025  
**Issue**: Hardcoded 2-page limit in Facebook crawler  
**Priority**: ⚠️ HIGH (Flexibility)  
**Status**: ✅ FIXED

---

## 🎯 Issue

### Problem
The Facebook fanpage crawler was **hardcoded to only fetch 2 pages** (200 posts) per fanpage:

```ruby
# OLD CODE (line 34)
break if iteration >= 2  # ❌ Hardcoded limit
```

**Impact**:
- Only 200 posts fetched per fanpage (2 pages × 100 posts)
- Missed recent posts if fanpage is very active
- No flexibility for different crawl strategies
- Inconsistent with main crawler (which now has configurable depth)

---

## ✅ Solution Implemented

### Configurable Pagination

The crawler now accepts a `max_pages` parameter with intelligent defaults:

```ruby
# NEW CODE
task :fanpage_crawler, [:max_pages] => :environment do |_t, args|
  max_pages = (args[:max_pages] || 3).to_i  # Default: 3 pages = ~300 posts
  
  # Validate range (1-10)
  unless (1..10).include?(max_pages)
    puts "❌ Error: max_pages must be between 1 and 10"
    exit 1
  end
  
  # Use max_pages in loop
  break if page_count >= max_pages
end
```

---

## 📋 What Changed

### 1. ✅ **Configurable Parameter**

**Before**: Fixed 2 pages
```ruby
break if iteration >= 2  # Hardcoded
```

**After**: Configurable (default 3)
```ruby
max_pages = (args[:max_pages] || 3).to_i
break if page_count >= max_pages
```

---

### 2. ✅ **Validation**

Added range validation (1-10 pages):
```ruby
unless (1..10).include?(max_pages)
  Rails.logger.error "Invalid max_pages: #{max_pages}. Must be between 1 and 10."
  puts "❌ Error: max_pages must be between 1 and 10 (got: #{max_pages})"
  exit 1
end
```

**Why 1-10 limit?**
- 1 page = 100 posts (minimum useful crawl)
- 10 pages = 1,000 posts (enough for most pages)
- Prevents accidental infinite loops
- Protects against rate limits

---

### 3. ✅ **Better Logging**

Added comprehensive progress tracking:
```ruby
puts "\n" + "=" * 80
puts "FACEBOOK FANPAGE CRAWLER"
puts "=" * 80
puts "Max pages per fanpage: #{max_pages} (#{max_pages * 100} posts max)"
puts "=" * 80 + "\n"

# Per page:
puts "  [Page #{page_count}/#{max_pages}] Processing #{label}..."
puts "  ✓ Stored #{entries.size} posts"
puts "  ✓ Completed: #{page_count} pages processed"
```

---

### 4. ✅ **Rate Limit Protection**

Added small delay between pages:
```ruby
# Small delay between pages to avoid rate limits
sleep(0.5) if cursor.present?
```

---

### 5. ✅ **Better Output**

Improved terminal output with emojis and formatting:
```ruby
# Success
puts "    ✓ #{facebook_entry.facebook_post_id} (#{facebook_entry.posted_at.strftime('%Y-%m-%d')})"

# Warning
puts "  ⚠️  No entries returned"

# Error
puts "  ❌ Error: #{response.error}"
```

---

## 🚀 Usage

### Default (3 pages = ~300 posts per page)
```bash
rake facebook:fanpage_crawler
```

### Custom (5 pages = ~500 posts per page)
```bash
rake facebook:fanpage_crawler[5]
```

### Quick check (1 page = ~100 posts per page)
```bash
rake facebook:fanpage_crawler[1]
```

### Full crawl (10 pages = ~1,000 posts per page)
```bash
rake facebook:fanpage_crawler[10]
```

---

## 📊 Comparison

### Before:
- ❌ Fixed 2 pages (200 posts)
- ❌ No flexibility
- ❌ Limited logging
- ❌ Inconsistent with main crawler

### After:
- ✅ Configurable (default 3 pages = 300 posts)
- ✅ Range validation (1-10)
- ✅ Comprehensive logging
- ✅ Rate limit protection
- ✅ Better terminal output
- ✅ Consistent with main crawler

---

## 📈 Impact

### Posts Collected Per Fanpage:

| Configuration | Pages | Posts | Use Case |
|--------------|-------|-------|----------|
| `[1]` | 1 | ~100 | Quick check |
| **`[3]` (default)** | **3** | **~300** | **Regular crawl** |
| `[5]` | 5 | ~500 | Active pages |
| `[10]` | 10 | ~1,000 | Full backfill |

---

## 🕐 Scheduled Crawl

Updated `config/schedule.rb` to use default 3 pages:

```ruby
# Before:
rake 'facebook:fanpage_crawler'  # Default 2 pages

# After:
rake 'facebook:fanpage_crawler[3]'  # Default 3 pages = ~300 posts
```

**Runs**: Every 3 hours

---

## 🧪 Testing

### Test default (3 pages):
```bash
rake facebook:fanpage_crawler
```

**Expected output**:
```
================================================================================
FACEBOOK FANPAGE CRAWLER
================================================================================
Max pages per fanpage: 3 (300 posts max)
================================================================================

[ABC Color] Starting crawl...
  [Page 1/3] Processing page: 1...
    ✓ 123456_789 (2025-11-04) [→ Entry 456] [política, gobierno]
    ✓ 123456_790 (2025-11-04) [No tags]
    ...
  ✓ Stored 100 posts
  [Page 2/3] Processing cursor: xyz...
  ...
  ✓ Completed: 3 pages processed

================================================================================
CRAWL COMPLETE
================================================================================
```

---

### Test custom (5 pages):
```bash
rake facebook:fanpage_crawler[5]
```

**Expected output**:
```
Max pages per fanpage: 5 (500 posts max)
```

---

### Test validation:
```bash
rake facebook:fanpage_crawler[15]
```

**Expected output**:
```
❌ Error: max_pages must be between 1 and 10 (got: 15)
```

---

## 📝 Files Updated

1. ✅ **`lib/tasks/facebook/fanpage_crawler.rake`**
   - Added `[:max_pages]` parameter
   - Default: 3 pages
   - Validation: 1-10 range
   - Better logging
   - Rate limit protection

2. ✅ **`config/schedule.rb`**
   - Updated to use `[3]` explicitly
   - Documented in comment

---

## 💡 Recommendations

### Regular Crawl (Every 3 hours):
```ruby
rake 'facebook:fanpage_crawler[3]'  # 300 posts - Good balance
```

### Backfill/Recovery (Manual):
```bash
rake facebook:fanpage_crawler[10]  # 1,000 posts - Full history
```

### Testing (Development):
```bash
rake facebook:fanpage_crawler[1]  # 100 posts - Quick test
```

---

## ⚠️ Rate Limit Considerations

### Facebook Rate Limits:
- **App-level**: ~4,800 calls/hour
- **User-level**: ~200 calls/hour

### Our Implementation:
- Default 3 pages = 3 API calls per fanpage
- 10 fanpages × 3 pages = 30 calls per crawl
- Runs every 3 hours = ~10 crawls per day = 300 calls/day
- **Well within limits** ✅

### With 10 pages:
- 10 fanpages × 10 pages = 100 calls per crawl
- 8 crawls per day = 800 calls/day
- **Still safe** ✅

---

## 🎉 Benefits

1. ✅ **Flexibility**: Configure pages based on need
2. ✅ **More data**: 3 pages (300 posts) vs 2 pages (200 posts) = **50% more**
3. ✅ **Better logging**: Clear progress tracking
4. ✅ **Rate limit protection**: 0.5s delay between pages
5. ✅ **Validation**: Prevents invalid values
6. ✅ **Consistency**: Same pattern as main crawler

---

## 📚 Related Documentation

- **Main Crawler**: `docs/features/configurable_crawler_depth.md`
- **Facebook Crawler Review**: `docs/reviews/facebook_crawler_review.md`

---

## ✅ Summary

**What changed**:
- ❌ Hardcoded 2 pages (200 posts)
- ✅ Configurable parameter with default 3 pages (300 posts)
- ✅ Validation (1-10 range)
- ✅ Better logging and output
- ✅ Rate limit protection
- ✅ Updated schedule

**Impact**:
- **+50% more posts** collected by default (200 → 300)
- **Flexible** for different use cases
- **Safer** with rate limit protection
- **Better UX** with clear progress

---

**Status**: ✅ **COMPLETE - Production ready**

Facebook crawler now has configurable pagination! 🎉

**Usage**:
```bash
# Default (3 pages)
rake facebook:fanpage_crawler

# Custom
rake facebook:fanpage_crawler[5]
```

