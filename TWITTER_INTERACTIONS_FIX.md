# Social Media Interactions Ordering Fix

## Problem Identified

The "Tweets con más interacciones" (Tweets with most interactions) and "Publicaciones con más interacciones" (Posts with most interactions) sections were not correctly displaying content ordered by total interactions.

### Root Causes

1. **Conflicting Order Clauses**: 
   - For Twitter: The `@posts` collection came from `TwitterPost.for_topic(@topic)`, which includes `.recent` (ordering by `posted_at DESC`)
   - For Facebook: The `@entries` collection came from `FacebookEntry.for_topic(@topic)`, which also includes `.recent`
   - When trying to apply a new ordering with `.order()`, the existing order was not being cleared first, causing potential conflicts

2. **Inconsistent Interaction Calculations (Twitter only)**: 
   - The instance method `total_interactions` included `quote_count` in the calculation
   - The class method `total_interactions` and SQL ordering did NOT include `quote_count`
   - This inconsistency meant the ordering didn't match the actual total shown on the UI

## Changes Made

### 1. `app/controllers/twitter_topic_controller.rb`

#### Top Posts Ordering (Line 73-75)
**Before:**
```ruby
@top_posts = @posts.order(
  Arel.sql('(twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count) DESC')
).limit(top_posts_limit)
```

**After:**
```ruby
@top_posts = @posts.reorder(
  Arel.sql('(twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count) DESC')
).limit(top_posts_limit)
```

**Changes:**
- Used `.reorder()` instead of `.order()` to clear existing ordering
- Added `quote_count` to match the instance method calculation

#### Tag Interactions (Line 95)
**Before:**
```ruby
.sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count'))
```

**After:**
```ruby
.sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count'))
```

#### Site Interactions (Line 130)
**Before:**
```ruby
.sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count'))
```

**After:**
```ruby
.sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count'))
```

### 2. `app/models/twitter_post.rb`

#### Class Method: `grouped_interactions` (Line 39)
**Before:**
```ruby
.sum(Arel.sql('favorite_count + retweet_count + reply_count'))
```

**After:**
```ruby
.sum(Arel.sql('favorite_count + retweet_count + reply_count + quote_count'))
```

#### Class Method: `total_interactions` (Line 44)
**Before:**
```ruby
relation.sum(:favorite_count) + relation.sum(:retweet_count) + relation.sum(:reply_count)
```

**After:**
```ruby
relation.sum(:favorite_count) + relation.sum(:retweet_count) + relation.sum(:reply_count) + relation.sum(:quote_count)
```

### 3. `app/controllers/facebook_topic_controller.rb`

#### Top Posts Ordering (Line 72-74)
**Before:**
```ruby
@top_posts = @entries.order(
  Arel.sql('(facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count) DESC')
).limit(top_posts_limit)
```

**After:**
```ruby
@top_posts = @entries.reorder(
  Arel.sql('(facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count) DESC')
).limit(top_posts_limit)
```

**Changes:**
- Used `.reorder()` instead of `.order()` to clear existing ordering from `.recent` scope
- Facebook calculations were already consistent (no quote_count equivalent)

## Impact

These changes ensure that:

1. ✅ The "Tweets con más interacciones" section correctly displays tweets ordered by total interactions (favorites + retweets + replies + quotes)
2. ✅ The "Publicaciones con más interacciones" section correctly displays Facebook posts ordered by total interactions
3. ✅ All interaction calculations are consistent across the Twitter implementation
4. ✅ The existing ordering from `.recent` is properly cleared before applying the interactions ordering
5. ✅ Quote counts are now included in all Twitter interaction calculations, matching the instance method

## Views Affected

### Twitter
- `app/views/twitter_topic/show.html.erb` - Shows top 20 tweets with most interactions
- `app/views/twitter_topic/pdf.html.erb` - Shows top 10 tweets with most interactions in PDF export

### Facebook
- `app/views/facebook_topic/show.html.erb` - Shows top 20 posts with most interactions
- `app/views/facebook_topic/pdf.html.erb` - Shows top 10 posts with most interactions in PDF export

All views use the `@top_posts` variable, so the fix applies to both display and PDF export.

## Testing Recommendations

1. Navigate to a Twitter topic page
2. Verify that tweets in "Tweets con más interacciones" section are ordered from highest to lowest total interactions
3. Check that the displayed interaction numbers match the ordering
4. Generate a PDF report and verify the same correct ordering
5. Compare tag interaction totals to ensure they include quote counts

