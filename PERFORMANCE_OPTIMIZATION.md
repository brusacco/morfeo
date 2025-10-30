# Performance Optimization: Topic Stats Daily

## Overview
The `TopicController#show` and `TopicController#pdf` actions have been optimized to use pre-aggregated data from `topic_stat_dailies` and `title_topic_stat_dailies` tables instead of running expensive group-by queries on the entries table.

## Changes Made

### Before (Inefficient)
```ruby
# Multiple expensive queries on entries table
@chart_entries = @entries.group_by_day(:published_at)
@chart_entries_sentiments = @entries.where.not(polarity: nil).group(:polarity).group_by_day(:published_at)
@title_entries = @topic.title_list_entries
@title_chart_entries = @title_entries.reorder(nil).group_by_day(:published_at)

# Aggregate computations
@chart_entries_counts = @chart_entries.size
@chart_entries_sums = @chart_entries.sum(:total_count)
@title_chart_entries_counts = @title_chart_entries.size
@title_chart_entries_sums = @title_chart_entries.sum(:total_count)
@chart_entries_sentiments_counts = @chart_entries_sentiments.size
@chart_entries_sentiments_sums = @chart_entries_sentiments.sum(:total_count)
```

### After (Optimized)
```ruby
# Use pre-aggregated daily stats for performance
topic_stats = @topic.topic_stat_dailies.normal_range.order(:topic_date)

# Build chart data from aggregated stats
@chart_entries_counts = topic_stats.pluck(:topic_date, :entry_count).to_h
@chart_entries_sums = topic_stats.pluck(:topic_date, :total_count).to_h

# Sentiment chart data from aggregated stats
@chart_entries_sentiments_counts = {}
@chart_entries_sentiments_sums = {}

topic_stats.each do |stat|
  date = stat.topic_date
  # Counts by sentiment
  @chart_entries_sentiments_counts[['positive', date]] = stat.positive_quantity || 0
  @chart_entries_sentiments_counts[['neutral', date]] = stat.neutral_quantity || 0
  @chart_entries_sentiments_counts[['negative', date]] = stat.negative_quantity || 0
  
  # Interactions by sentiment
  @chart_entries_sentiments_sums[['positive', date]] = stat.positive_interaction || 0
  @chart_entries_sentiments_sums[['neutral', date]] = stat.neutral_interaction || 0
  @chart_entries_sentiments_sums[['negative', date]] = stat.negative_interaction || 0
end

# Use pre-aggregated title stats for performance
title_stats = @topic.title_topic_stat_dailies.normal_range.order(:topic_date)

@title_chart_entries_counts = title_stats.pluck(:topic_date, :entry_quantity).to_h
@title_chart_entries_sums = title_stats.pluck(:topic_date, :entry_interaction).to_h
```

## Data Structure

### TopicStatDaily Table
- `entry_count` - Number of entries for the day
- `total_count` - Total interactions for the day
- `positive_quantity` - Number of positive entries
- `negative_quantity` - Number of negative entries
- `neutral_quantity` - Number of neutral entries
- `positive_interaction` - Total interactions for positive entries
- `negative_interaction` - Total interactions for negative entries
- `neutral_interaction` - Total interactions for neutral entries
- `topic_date` - Date
- `topic_id` - Associated topic

### TitleTopicStatDaily Table
- `entry_quantity` - Number of entries with topic in title for the day
- `entry_interaction` - Total interactions for entries with topic in title
- `average` - Average interactions per entry
- `topic_date` - Date
- `topic_id` - Associated topic

## Data Population

The aggregated data is populated by rake tasks:
- `rake topic_stat_daily` - Populates `topic_stat_dailies`
- `rake title_topic_stat_daily` - Populates `title_topic_stat_dailies`

These tasks are scheduled to run hourly via the `whenever` gem (see `config/schedule.rb`).

## Performance Benefits

1. **Reduced Query Complexity**: Instead of multiple `GROUP BY` queries on large tables, we use simple indexed lookups on pre-aggregated data.
2. **Faster Page Load**: Chart data is fetched with 2-3 simple queries instead of 6+ complex group-by queries.
3. **Consistent Performance**: Performance is predictable regardless of the number of entries, as the stats tables have fixed rows per day.
4. **Memory Efficiency**: Less data transferred from database to application.

## Important Notes

1. **Data Freshness**: The data in stats tables is updated hourly. For real-time data, consider:
   - Running the rake tasks more frequently
   - Adding a cache-busting mechanism
   - Showing a "Last updated" timestamp to users

2. **Compatibility**: The data structure matches the expected format for Chartkick/Highcharts:
   - Simple hash `{date => count}` for column charts
   - Nested array keys `[['sentiment', date]]` for multi-series area charts

3. **Scope**: The `normal_range` scope (defined in the models) limits data to the configured `DAYS_RANGE` (typically 7-30 days).

## Testing

To test the optimization:

1. Ensure the rake tasks have run: `rake topic_stat_daily && rake title_topic_stat_daily`
2. Visit a topic show page: `/topic/:id`
3. Verify all charts display correctly
4. Check the Rails logs to confirm only simple queries are executed
5. Compare page load time before/after optimization

## Rollback

If issues arise, you can revert to the previous implementation by checking out the git commit before this change. The views remain unchanged, so only the controller needs to be reverted.

