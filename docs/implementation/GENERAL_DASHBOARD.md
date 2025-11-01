# General Dashboard - Executive Analytics

## Overview

The General Dashboard is a professional, CEO-level reporting tool that aggregates data from all available sources (Digital Media, Facebook, Twitter) to provide comprehensive insights for strategic decision-making.

## Features

### 1. **Executive Summary**
- **Total Mentions**: Aggregate count across all channels
- **Total Interactions**: Combined engagement metrics
- **Total Reach**: Estimated unique users reached
- **Share of Voice**: Market presence percentage
- **Engagement Rate**: Interactions / Reach ratio
- **Trend Velocity**: Growth rate vs. previous period
- **Sentiment Score**: Weighted average sentiment

### 2. **Channel Performance Analysis**
Each channel (Digital, Facebook, Twitter) provides:
- Mentions count
- Total interactions
- Estimated reach
- Engagement rate
- Sentiment score
- Trend direction
- Market share percentage

**Visual Components**:
- Channel comparison pie charts
- Engagement rate bars
- Trend indicators

### 3. **Sentiment Analysis**
- **Overall Sentiment Score**: Weighted across all channels
- **Sentiment Distribution**: Positive/Neutral/Negative breakdown
- **Sentiment Confidence Level**: Based on sample size
- **Sentiment Trend**: Change vs. previous period
- **Sentiment Alerts**: Automated crisis detection

**Alert Types**:
- 🔴 **Crisis Alert**: Very negative sentiment detected
- 🟡 **Warning**: Rapid sentiment decline
- 🟢 **Opportunity**: Highly positive trend

### 4. **Reach Analysis**
- Total reach across all channels
- Estimated impressions (reach × 1.3)
- Unique sources count
- Channel-wise reach breakdown

### 5. **Competitive Analysis**
- **Share of Voice**: Percentage of total market mentions
- **Market Position**: Ranking among all topics
- **Growth Rate**: Percentage change vs. previous period
- **Market Percentile**: Performance ranking

### 6. **Strategic Recommendations**
Based on data analysis, the system provides:

#### Publishing Time Optimization
- Best day and hour to publish
- Based on highest engagement averages
- Aggregated across all channels

#### Best Channel Recommendation
- Identifies the highest-performing channel
- Based on engagement rate

#### Content Suggestions
- Actionable insights based on viral content
- Sentiment-driven content recommendations
- Trending topic exploitation

#### Growth Opportunities
- Underperforming channels identification
- Share of voice improvement areas
- Specific action items

### 7. **Top Content**
Quick access to best-performing content:
- Top 3 Digital Entries
- Top 3 Facebook Posts
- Top 3 Tweets

## Technical Implementation

### Architecture

```
┌─────────────────────────────────────┐
│   GeneralDashboardController        │
│   - Handles requests                │
│   - Date range filtering            │
│   - PDF export                      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  AggregatorService                  │
│  - Data collection from all sources │
│  - Metric calculation               │
│  - Recommendation generation        │
│  - 30-minute caching                │
└──────────────┬──────────────────────┘
               │
    ┌──────────┴──────────┬────────────────┐
    ▼                     ▼                ▼
┌─────────┐         ┌──────────┐    ┌──────────┐
│ Entries │         │ Facebook │    │ Twitter  │
│ (Digital│         │ Entries  │    │ Posts    │
│  Media) │         └──────────┘    └──────────┘
└─────────┘
```

### Key Classes

#### `GeneralDashboardServices::AggregatorService`
Main service for data aggregation:
- Collects data from Entry, FacebookEntry, TwitterPost
- Calculates cross-channel metrics
- Generates recommendations
- Implements intelligent caching

#### `GeneralDashboardController`
Handles HTTP requests:
- `show`: Displays the dashboard
- `pdf`: Generates PDF export

#### `GeneralDashboardHelper`
View helpers for:
- Sentiment visualization (emojis, colors)
- Chart data preparation
- Metric formatting

### Caching Strategy

```ruby
Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
  # Expensive aggregation operations
end
```

Cache keys include:
- Topic ID
- Start date
- End date

## Metrics Definitions

### Share of Voice (SOV)
```
SOV = (Topic Mentions / Total Market Mentions) × 100
```

### Engagement Rate
```
Engagement Rate = (Total Interactions / Total Reach) × 100
```

### Trend Velocity
```
Velocity = ((Current Period - Previous Period) / Previous Period) × 100
```

### Sentiment Score
Weighted average across channels:
```
Score = Σ(Channel Score × Channel Weight) / Total Weight
```

Where weight = number of mentions per channel

### Growth Rate
```
Growth = ((Current Mentions - Previous Mentions) / Previous Mentions) × 100
```

## Best Practices (Based on Research)

### 1. **Data Visualization**
- Use color consistently (green = positive, red = negative)
- Show context (comparisons, trends)
- Highlight key metrics
- Progressive disclosure (summary → details)

### 2. **Executive Reporting**
- Lead with key insights
- Provide actionable recommendations
- Show trends and changes
- Include confidence indicators

### 3. **PR Analytics Standards**
Following industry research (2024-2025):
- Share of Voice for market positioning
- Sentiment analysis for reputation management
- Reach and engagement for impact measurement
- Temporal intelligence for optimization

## Usage

### Accessing the Dashboard

1. **Via Navigation**: Click "General" in the top navigation, select a topic
2. **Direct URL**: `/general_dashboards/:topic_id`

### Date Range Filtering (Future Enhancement)
URL parameters:
```
/general_dashboards/1?start_date=2025-10-01&end_date=2025-10-31
```

### PDF Export
Click "Exportar PDF" button or visit:
```
/general_dashboards/:topic_id/pdf
```

## Performance Considerations

### Caching
- 30-minute cache expiration
- Cache invalidation on data updates
- Separate caches per topic/date range

### Query Optimization
- Uses ActiveRecord includes/joins
- Batch loading for related records
- Aggregation at database level

### Recommendations
- For topics with >10,000 mentions, consider:
  - Extending cache duration
  - Background job processing
  - Data warehouse implementation

## Future Enhancements

### Phase 2
- [ ] Historical trend comparison (multi-period)
- [ ] Custom date range selector in UI
- [ ] Exportar a Excel/CSV
- [ ] Scheduled email reports
- [ ] Geographic distribution (if data available)
- [ ] Influencer identification
- [ ] AI-powered insights (GPT integration)

### Phase 3
- [ ] Real-time updates (WebSockets)
- [ ] Custom dashboard configuration
- [ ] Comparison with competitors
- [ ] Predictive analytics
- [ ] Automated alerts system

## Related Documents

- `/docs/implementation/GENERAL_DASHBOARD.md` (this file)
- `/app/services/general_dashboard_services/aggregator_service.rb`
- `/app/controllers/general_dashboard_controller.rb`
- `/app/views/general_dashboard/show.html.erb`

## Support

For questions or issues, contact the development team or refer to the main documentation.

