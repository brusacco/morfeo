# CRITICAL FIXES REQUIRED - General Dashboard
**Priority: HIGH - Before CEO Presentation**

## 🔴 Issue #1: Invalid Reach Estimation

**Current Code** (Line 240, aggregator_service.rb):
```ruby
digital_reach = entries.sum(:total_count) * 10  # ❌ INVALID
```

**Problem**: Arbitrary 10x multiplier with no scientific basis

**Required Fix**:
```ruby
# Option A: Remove multiplier, use actual interaction data
digital_reach = entries.sum(:total_count)  # Conservative: reach ≈ interactions
note = "Reach estimado basado en interacciones (conservador)"

# Option B: Site-weighted multiplier
def digital_reach_validated
  entries_by_site = topic.report_entries(start_date, end_date).group_by(&:site)
  
  entries_by_site.sum do |site, site_entries|
    # Use site's actual traffic data if available
    multiplier = site.reach_multiplier || 5  # Conservative default
    site_entries.sum(&:total_count) * multiplier
  end
end
```

**Testing**: Compare with Google Analytics data if available

---

## 🔴 Issue #2: Invalid Impressions Calculation

**Current Code** (Line 349):
```ruby
def total_impressions
  total_reach * 1.3  # ❌ FALSE "industry standard"
end
```

**Problem**: 
- Claim of "industry standard" is inaccurate
- Impressions ≠ Reach × constant
- Will be questioned by data-savvy stakeholders

**Required Fix**:
```ruby
# Option A: Remove entirely (recommended)
# Delete method and remove from views

# Option B: Platform-specific frequency
def total_impressions_estimated
  {
    facebook: facebook_data[:reach] * 2.1,    # Meta benchmark
    twitter: twitter_data[:reach] * 1.8,      # Twitter benchmark  
    digital: nil,  # Cannot estimate without tracking
    total: facebook_data[:reach] * 2.1 + twitter_data[:reach] * 1.8,
    confidence: "low",
    disclaimer: "Estimación aproximada basada en promedios de industria"
  }
end
```

---

## 🔴 Issue #3: Performance - Market Position

**Current Code** (Line 516):
```ruby
def market_position
  all_topics = Topic.active
  ranked = all_topics.map do |t|
    service = self.class.new(topic: t, start_date: start_date, end_date: end_date)
    [t.id, service.send(:total_mentions)]  # ❌ N+1 service calls
  end
  # ...
end
```

**Problem**:
- Creates AggregatorService for EACH topic
- If 50 topics → 50 × 6+ queries = 300+ database queries
- Will timeout with many topics

**Required Fix**:
```ruby
def market_position_optimized
  # Single query per platform (3 total instead of 150+)
  Rails.cache.fetch("market_position_all_topics_#{start_date.to_date}_#{end_date.to_date}", expires_in: 1.hour) do
    all_mentions = {}
    
    # Digital mentions by topic (1 query)
    Entry.enabled
         .where(published_at: start_date..end_date)
         .group(:topic_id)
         .count
         .each { |topic_id, count| all_mentions[topic_id] = (all_mentions[topic_id] || 0) + count }
    
    # Facebook mentions by topic (1 query)
    FacebookEntry
      .where(posted_at: start_date..end_date)
      .joins(taggings: { tag: :topic })
      .group('topics.id')
      .count
      .each { |topic_id, count| all_mentions[topic_id] = (all_mentions[topic_id] || 0) + count }
    
    # Twitter mentions by topic (1 query)
    TwitterPost
      .where(posted_at: start_date..end_date)
      .joins(taggings: { tag: :topic })
      .group('topics.id')
      .count
      .each { |topic_id, count| all_mentions[topic_id] = (all_mentions[topic_id] || 0) + count }
    
    # Rank topics
    ranked = all_mentions.sort_by { |_id, count| -count }
    position = ranked.index { |id, _count| id == topic.id }
    
    {
      rank: position ? position + 1 : nil,
      total_topics: ranked.size,
      percentile: position && ranked.size > 0 ? ((1 - position.to_f / ranked.size) * 100).round(0) : nil
    }
  end
end
```

**Testing**: 
- Benchmark before: `Benchmark.measure { market_position }`
- Benchmark after: Should be < 100ms

---

## 🔴 Issue #4: Arbitrary Sentiment Alerts

**Current Code** (Line 455-462):
```ruby
if average_sentiment < -30  # ❌ Arbitrary threshold
  alerts << { type: 'crisis', severity: 'high', ... }
end

if trend[:change] < -20  # ❌ Arbitrary threshold
  alerts << { type: 'warning', severity: 'medium', ... }
end
```

**Problem**:
- No statistical or historical basis for -30, -20 thresholds
- Could trigger false alarms
- CEO will ask "Why -30? Why not -25 or -40?"

**Required Fix**:
```ruby
def detect_sentiment_alerts_validated
  alerts = []
  current = average_sentiment
  
  # Use historical data if available (>30 days of data)
  if topic.has_historical_sentiment_data?
    historical_avg = topic.historical_sentiment_average
    historical_std = topic.historical_sentiment_std_dev
    
    # Statistical test: Z-score
    z_score = (current - historical_avg) / historical_std
    
    # 2 standard deviations = statistically significant
    if z_score < -2.0 && current < -20
      alerts << {
        type: 'crisis',
        severity: 'high',
        message: "Sentimiento significativamente inferior al promedio histórico",
        details: "Z-score: #{z_score.round(2)} (p < 0.05)",
        current_value: current,
        historical_avg: historical_avg.round(1),
        recommendation: 'Acción inmediata requerida'
      }
    elsif z_score < -1.5
      alerts << {
        type: 'warning',
        severity: 'medium',
        message: "Sentimiento por debajo del promedio histórico",
        details: "Z-score: #{z_score.round(2)}",
        recommendation: 'Monitorear situación'
      }
    end
  else
    # Fallback: Absolute thresholds with disclaimer
    if current < -40  # More conservative threshold
      alerts << {
        type: 'crisis',
        severity: 'high',
        message: "Sentimiento muy negativo detectado",
        note: "Umbral absoluto - considerar contexto histórico",
        recommendation: 'Revisar causa y considerar respuesta'
      }
    end
  end
  
  # Positive opportunity (less critical, so absolute threshold OK)
  if current > 50
    alerts << {
      type: 'opportunity',
      severity: 'low',
      message: "Sentimiento muy positivo - oportunidad de amplificación",
      recommendation: 'Aumentar frecuencia de publicación'
    }
  end
  
  alerts
end

# Add to Topic model
class Topic < ApplicationRecord
  def has_historical_sentiment_data?
    # Need at least 30 days of data for statistical validity
    report_entries.where('published_at < ?', 30.days.ago).exists?
  end
  
  def historical_sentiment_average
    Rails.cache.fetch("#{cache_key}/historical_sentiment_avg", expires_in: 24.hours) do
      # Calculate from data older than current period
      # Implement based on your data structure
    end
  end
  
  def historical_sentiment_std_dev
    Rails.cache.fetch("#{cache_key}/historical_sentiment_std", expires_in: 24.hours) do
      # Calculate standard deviation
      # Implement based on your data structure
    end
  end
end
```

**Testing**:
- Test with known negative event (verify alert triggers)
- Test with normal variation (verify no false alarms)

---

## 🔴 Issue #5: Division by Zero Risk

**Current Code** (Line 656):
```ruby
def identify_viral_content
  {
    digital: top_digital_entries.select { |e| 
      e.total_count > digital_data[:interactions] / digital_data[:count] * 5  # ❌ Division by zero if count = 0
    }
  }
end
```

**Required Fix**:
```ruby
def identify_viral_content
  {
    digital: identify_viral_digital,
    facebook: identify_viral_facebook,
    twitter: identify_viral_twitter
  }
end

private

def identify_viral_digital
  return [] if digital_data[:count].zero?
  
  avg_engagement = digital_data[:interactions] / digital_data[:count].to_f
  threshold = avg_engagement * 5
  
  top_digital_entries.select { |e| e.total_count > threshold }
end

def identify_viral_facebook
  return [] if facebook_data[:count].zero?
  
  avg_engagement = facebook_data[:interactions] / facebook_data[:count].to_f
  threshold = avg_engagement * 5
  
  top_facebook_posts.select do |p|
    (p.reactions_total_count + p.comments_count + p.share_count) > threshold
  end
end

def identify_viral_twitter
  return [] if twitter_data[:count].zero?
  
  avg_engagement = twitter_data[:interactions] / twitter_data[:count].to_f
  threshold = avg_engagement * 5
  
  top_tweets.select { |t| t.total_interactions > threshold }
end
```

---

## 🟡 Issue #6: Hardcoded Temporal Intelligence

**Current Code** (Line 122):
```ruby
def calculate_combined_optimal_time_simple
  { day: 'Lunes', hour: 9, recommendation: 'Lunes a las 09:00 hrs', avg_engagement: 0 }
end
```

**Problem**: Always returns Monday 9 AM, ignoring actual data

**Required Fix**:
```ruby
def build_temporal_intelligence_cached
  # Cache for 24 hours to avoid expensive recalculation
  Rails.cache.fetch("temporal_intelligence_#{topic.id}", expires_in: 24.hours) do
    {
      digital: topic.optimal_publishing_time,
      facebook: topic.facebook_optimal_publishing_time,
      twitter: topic.twitter_optimal_publishing_time,
      combined: calculate_combined_optimal_time_actual,
      cached_at: Time.current
    }
  rescue StandardError => e
    Rails.logger.error "Temporal intelligence error: #{e.message}"
    # Fallback to simple version
    build_temporal_intelligence_lightweight
  end
end

def calculate_combined_optimal_time_actual
  # Get optimal times from each channel
  digital_opt = topic.optimal_publishing_time
  facebook_opt = topic.facebook_optimal_publishing_time
  twitter_opt = topic.twitter_optimal_publishing_time rescue nil
  
  # Find the one with highest engagement
  candidates = [digital_opt, facebook_opt, twitter_opt].compact
  return { day: 'Lunes', hour: 9, recommendation: 'Lunes a las 09:00 hrs', avg_engagement: 0 } if candidates.empty?
  
  best = candidates.max_by { |opt| opt[:avg_engagement] || 0 }
  best
end
```

---

## Testing Checklist

Before presenting to CEO, verify:

- [ ] **No division by zero errors** - Test with topics that have 0 mentions
- [ ] **Performance under load** - Test with 50+ topics
- [ ] **Cache effectiveness** - Verify page loads in < 3 seconds
- [ ] **Data accuracy** - Manually verify totals match raw queries
- [ ] **Sentiment alerts** - Test with known positive/negative periods
- [ ] **Mobile display** - Check responsive design
- [ ] **Error handling** - Test with API failures

---

## SQL Queries to Verify Data

```sql
-- Verify mention totals
SELECT 
  'digital' as source,
  COUNT(*) as mentions,
  SUM(total_count) as interactions
FROM entries 
WHERE topic_id = [TOPIC_ID] 
  AND published_at BETWEEN '[START]' AND '[END]'
  AND enabled = 1

UNION ALL

SELECT 
  'facebook' as source,
  COUNT(DISTINCT fe.id) as mentions,
  SUM(fe.reactions_total_count + fe.comments_count + fe.share_count) as interactions
FROM facebook_entries fe
INNER JOIN taggings t ON t.taggable_id = fe.id AND t.taggable_type = 'FacebookEntry'
INNER JOIN tags tg ON tg.id = t.tag_id
WHERE tg.topic_id = [TOPIC_ID]
  AND fe.posted_at BETWEEN '[START]' AND '[END]'

UNION ALL

SELECT 
  'twitter' as source,
  COUNT(DISTINCT tp.id) as mentions,
  SUM(tp.favorite_count + tp.retweet_count + tp.reply_count + tp.quote_count) as interactions
FROM twitter_posts tp
INNER JOIN taggings t ON t.taggable_id = tp.id AND t.taggable_type = 'TwitterPost'
INNER JOIN tags tg ON tg.id = t.tag_id
WHERE tg.topic_id = [TOPIC_ID]
  AND tp.posted_at BETWEEN '[START]' AND '[END]';
```

---

## Documentation Updates

After fixes, update:

1. **README** - Add note about reach estimation methodology
2. **User Guide** - Explain what metrics are estimated vs actual
3. **API Docs** - Document confidence levels for each metric
4. **Change Log** - Record all formula changes

---

## Timeline

**Immediate (Today)**:
- [ ] Fix division by zero (Issue #5) - 30 min
- [ ] Add error handling to market position (Issue #3) - 1 hour

**Tomorrow**:
- [ ] Fix reach calculation (Issue #1) - 2 hours
- [ ] Remove/fix impressions (Issue #2) - 1 hour
- [ ] Fix sentiment alerts (Issue #4) - 2 hours

**Before CEO Meeting**:
- [ ] Full testing with production data - 2 hours
- [ ] Performance testing - 1 hour
- [ ] Documentation updates - 1 hour

**Total Estimated Time**: ~10 hours (1.5 days)

