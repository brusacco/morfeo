# Facebook Sentiment Analysis - Quick Start Guide

## 🚀 Implementation in 5 Steps

This is the TL;DR version. For full details, see `FACEBOOK_SENTIMENT_ANALYSIS_IMPLEMENTATION_PLAN.md`.

---

## Step 1: Run Migration (5 minutes)

```bash
# Create the migration
rails generate migration AddSentimentAnalysisToFacebookEntries

# Edit the generated migration file and add:
```

```ruby
class AddSentimentAnalysisToFacebookEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :facebook_entries, :sentiment_score, :decimal, precision: 5, scale: 2
    add_column :facebook_entries, :sentiment_label, :integer, default: 0
    add_column :facebook_entries, :sentiment_positive_pct, :decimal, precision: 5, scale: 2
    add_column :facebook_entries, :sentiment_negative_pct, :decimal, precision: 5, scale: 2
    add_column :facebook_entries, :sentiment_neutral_pct, :decimal, precision: 5, scale: 2
    add_column :facebook_entries, :controversy_index, :decimal, precision: 5, scale: 4
    add_column :facebook_entries, :emotional_intensity, :decimal, precision: 8, scale: 4
    
    add_index :facebook_entries, :sentiment_score
    add_index :facebook_entries, :sentiment_label
  end
end
```

```bash
# Run it
rails db:migrate
```

---

## Step 2: Update FacebookEntry Model (30 minutes)

Add to `app/models/facebook_entry.rb`:

```ruby
# At the top, add enum
enum sentiment_label: {
  very_negative: 0,
  negative: 1,
  neutral: 2,
  positive: 3,
  very_positive: 4
}

# Add constant
SENTIMENT_WEIGHTS = {
  reactions_like_count: 0.5,
  reactions_love_count: 2.0,
  reactions_haha_count: 1.5,
  reactions_wow_count: 1.0,
  reactions_sad_count: -1.5,
  reactions_angry_count: -2.0,
  reactions_thankful_count: 2.0
}.freeze

# Add callback
before_save :calculate_sentiment_analysis, if: :reactions_changed?

# Add scopes
scope :positive_sentiment, -> { where(sentiment_label: [:positive, :very_positive]) }
scope :negative_sentiment, -> { where(sentiment_label: [:negative, :very_negative]) }
scope :neutral_sentiment, -> { where(sentiment_label: :neutral) }
scope :controversial, -> { where('controversy_index > ?', 0.6) }

# Add methods (copy from full implementation plan)
def calculate_sentiment_analysis
  return if reactions_total_count.zero?
  
  self.sentiment_score = calculate_weighted_sentiment_score
  self.sentiment_label = determine_sentiment_label(sentiment_score)
  
  positive = reactions_like_count + reactions_love_count + reactions_haha_count + 
             reactions_wow_count + reactions_thankful_count
  negative = reactions_sad_count + reactions_angry_count
  
  self.sentiment_positive_pct = (positive.to_f / reactions_total_count * 100).round(2)
  self.sentiment_negative_pct = (negative.to_f / reactions_total_count * 100).round(2)
  self.sentiment_neutral_pct = (100 - sentiment_positive_pct - sentiment_negative_pct).round(2)
  
  self.controversy_index = calculate_controversy_index(positive, negative)
  self.emotional_intensity = calculate_emotional_intensity
end

def calculate_weighted_sentiment_score
  weighted_sum = SENTIMENT_WEIGHTS.sum do |reaction_field, weight|
    (send(reaction_field) || 0) * weight
  end
  (weighted_sum / reactions_total_count.to_f).round(2)
end

def determine_sentiment_label(score)
  case score
  when 1.5..Float::INFINITY then :very_positive
  when 0.5..1.5 then :positive
  when -0.5..0.5 then :neutral
  when -1.5..-0.5 then :negative
  else :very_negative
  end
end

def calculate_controversy_index(positive, negative)
  return 0.0 if reactions_total_count.zero?
  balance = ((positive - negative).abs.to_f / reactions_total_count)
  (1.0 - balance).round(4)
end

def calculate_emotional_intensity
  intense = reactions_love_count + reactions_angry_count + 
           reactions_sad_count + reactions_wow_count + reactions_thankful_count
  (intense.to_f / [reactions_like_count, 1].max).round(4)
end

def sentiment_text
  case sentiment_label
  when 'very_positive' then '😊 Muy Positivo'
  when 'positive' then '🙂 Positivo'
  when 'neutral' then '😐 Neutral'
  when 'negative' then '☹️ Negativo'
  when 'very_negative' then '😠 Muy Negativo'
  else '❓ Sin clasificar'
  end
end

def sentiment_color
  case sentiment_label
  when 'very_positive' then 'text-green-700 bg-green-50 border-green-200'
  when 'positive' then 'text-green-600 bg-green-50 border-green-100'
  when 'neutral' then 'text-gray-600 bg-gray-50 border-gray-200'
  when 'negative' then 'text-red-600 bg-red-50 border-red-100'
  when 'very_negative' then 'text-red-700 bg-red-50 border-red-200'
  else 'text-gray-500 bg-gray-50 border-gray-200'
  end
end

private

def reactions_changed?
  changed.any? { |attr| attr.start_with?('reactions_') }
end
```

---

## Step 3: Calculate Sentiment for Existing Data (10 minutes)

Create rake task `lib/tasks/facebook_sentiment.rake`:

```ruby
namespace :facebook do
  desc "Calculate sentiment analysis for all Facebook entries"
  task calculate_sentiment: :environment do
    puts "Starting sentiment analysis..."
    
    total = FacebookEntry.where('reactions_total_count > 0').count
    processed = 0
    
    FacebookEntry.where('reactions_total_count > 0').find_each do |entry|
      entry.calculate_sentiment_analysis
      entry.save
      
      processed += 1
      print "\rProcessed: #{processed}/#{total} (#{(processed.to_f / total * 100).round(1)}%)"
    end
    
    puts "\n✓ Done!"
  end
end
```

Run it:

```bash
rails facebook:calculate_sentiment
```

---

## Step 4: Add Topic-Level Methods (20 minutes)

Add to `app/models/topic.rb`:

```ruby
def facebook_sentiment_summary(start_time: DAYS_RANGE.days.ago, end_time: Time.zone.now)
  Rails.cache.fetch("topic_#{id}_fb_sentiment_#{start_time.to_date}", expires_in: 2.hours) do
    entries = FacebookEntry.for_topic(self, start_time:, end_time:)
                          .where('reactions_total_count > 0')
    
    return nil if entries.empty?
    
    {
      average_sentiment: entries.average(:sentiment_score).to_f.round(2),
      sentiment_distribution: calculate_sentiment_distribution(entries),
      top_positive_posts: entries.positive_sentiment.order(sentiment_score: :desc).limit(5),
      top_negative_posts: entries.negative_sentiment.order(sentiment_score: :asc).limit(5),
      controversial_posts: entries.controversial.order(controversy_index: :desc).limit(5),
      sentiment_over_time: entries.group_by_day(:posted_at, format: '%d/%m')
                                 .average(:sentiment_score)
                                 .transform_values { |v| v.to_f.round(2) },
      reaction_breakdown: {
        love: entries.sum(:reactions_love_count),
        haha: entries.sum(:reactions_haha_count),
        wow: entries.sum(:reactions_wow_count),
        like: entries.sum(:reactions_like_count),
        thankful: entries.sum(:reactions_thankful_count),
        sad: entries.sum(:reactions_sad_count),
        angry: entries.sum(:reactions_angry_count)
      }
    }
  end
end

def facebook_sentiment_trend
  Rails.cache.fetch("topic_#{id}_fb_sentiment_trend", expires_in: 1.hour) do
    recent = FacebookEntry.for_topic(self, start_time: 24.hours.ago)
                         .where('reactions_total_count > 0')
                         .average(:sentiment_score).to_f
                         
    previous = FacebookEntry.for_topic(self, start_time: 48.hours.ago, end_time: 24.hours.ago)
                           .where('reactions_total_count > 0')
                           .average(:sentiment_score).to_f
    
    return { trend: 'stable', change: 0 } if recent.zero? || previous.zero?
    
    change = ((recent - previous) / previous.abs * 100).round(1)
    
    {
      recent_score: recent.round(2),
      previous_score: previous.round(2),
      change_percent: change,
      trend: change > 5 ? 'improving' : (change < -5 ? 'declining' : 'stable'),
      direction: change > 0 ? 'up' : (change < 0 ? 'down' : 'stable')
    }
  end
end

private

def calculate_sentiment_distribution(entries)
  total = entries.count
  {
    very_positive: { count: entries.very_positive.count, 
                    percentage: (entries.very_positive.count.to_f / total * 100).round(1) },
    positive: { count: entries.positive.count, 
               percentage: (entries.positive.count.to_f / total * 100).round(1) },
    neutral: { count: entries.neutral.count, 
              percentage: (entries.neutral.count.to_f / total * 100).round(1) },
    negative: { count: entries.negative.count, 
               percentage: (entries.negative.count.to_f / total * 100).round(1) },
    very_negative: { count: entries.very_negative.count, 
                    percentage: (entries.very_negative.count.to_f / total * 100).round(1) }
  }
end
```

---

## Step 5: Add UI (1 hour)

### 5.1 Update Controller

Add to `app/controllers/facebook_topic_controller.rb`:

```ruby
def show
  load_facebook_data
  load_pages_data
  load_facebook_temporal_intelligence
  load_sentiment_analysis  # NEW LINE
end

private

def load_sentiment_analysis
  @sentiment_summary = @topic.facebook_sentiment_summary
  
  return unless @sentiment_summary
  
  @sentiment_distribution = @sentiment_summary[:sentiment_distribution]
  @sentiment_over_time = @sentiment_summary[:sentiment_over_time]
  @reaction_breakdown = @sentiment_summary[:reaction_breakdown]
  @top_positive_posts = @sentiment_summary[:top_positive_posts]
  @top_negative_posts = @sentiment_summary[:top_negative_posts]
  @controversial_posts = @sentiment_summary[:controversial_posts]
  @sentiment_trend = @topic.facebook_sentiment_trend
end
```

### 5.2 Add Helper Methods

Create `app/helpers/sentiment_helper.rb`:

```ruby
module SentimentHelper
  def sentiment_emoji(score)
    case score
    when 1.5..Float::INFINITY then '😊'
    when 0.5..1.5 then '🙂'
    when -0.5..0.5 then '😐'
    when -1.5..-0.5 then '☹️'
    else '😠'
    end
  end
  
  def sentiment_score_color(score)
    case score
    when 1.5..Float::INFINITY then 'text-green-700'
    when 0.5..1.5 then 'text-green-600'
    when -0.5..0.5 then 'text-gray-600'
    when -1.5..-0.5 then 'text-red-600'
    else 'text-red-700'
    end
  end
end
```

### 5.3 Add Simple Overview Section

Add to `app/views/facebook_topic/show.html.erb` (after statistics, before word clouds):

```erb
<!-- Sentiment Analysis Section -->
<% if @sentiment_summary %>
  <section id="sentiment-analysis" class="mb-8">
    <h2 class="text-2xl font-bold text-gray-900 mb-6">
      <i class="fa-solid fa-heart-pulse text-purple-600 mr-2"></i>
      Análisis de Sentimiento
    </h2>
    
    <!-- Overview Cards -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
      <!-- Average Sentiment -->
      <div class="bg-gradient-to-br from-purple-50 to-indigo-50 rounded-xl border border-purple-200 p-6">
        <h3 class="text-sm font-medium text-gray-600 mb-2">Sentimiento Promedio</h3>
        <div class="flex items-center justify-between">
          <div class="text-4xl font-bold <%= sentiment_score_color(@sentiment_summary[:average_sentiment]) %>">
            <%= number_with_precision(@sentiment_summary[:average_sentiment], precision: 2) %>
          </div>
          <div class="text-5xl"><%= sentiment_emoji(@sentiment_summary[:average_sentiment]) %></div>
        </div>
        <p class="text-xs text-gray-500 mt-2">-2.0 (muy negativo) a +2.0 (muy positivo)</p>
      </div>
      
      <!-- Trend -->
      <% if @sentiment_trend %>
        <div class="bg-white rounded-xl border border-gray-200 p-6">
          <h3 class="text-sm font-medium text-gray-600 mb-2">Tendencia (24h)</h3>
          <div class="text-3xl font-bold <%= @sentiment_trend[:direction] == 'up' ? 'text-green-600' : 
                                              @sentiment_trend[:direction] == 'down' ? 'text-red-600' : 
                                              'text-gray-600' %>">
            <%= "%+.1f" % @sentiment_trend[:change_percent] %>%
          </div>
          <div class="flex items-center mt-2 text-sm">
            <i class="fa-solid <%= @sentiment_trend[:direction] == 'up' ? 'fa-arrow-trend-up' : 
                                    @sentiment_trend[:direction] == 'down' ? 'fa-arrow-trend-down' : 
                                    'fa-minus' %> mr-2"></i>
            <span class="text-gray-600"><%= @sentiment_trend[:trend].humanize %></span>
          </div>
        </div>
      <% end %>
      
      <!-- Controversial Count -->
      <div class="bg-white rounded-xl border border-gray-200 p-6">
        <h3 class="text-sm font-medium text-gray-600 mb-2">Posts Controversiales</h3>
        <div class="text-3xl font-bold text-amber-600">
          <%= @controversial_posts.size %>
        </div>
        <p class="text-xs text-gray-500 mt-2">Alto balance entre reacciones positivas/negativas</p>
      </div>
    </div>
    
    <!-- Sentiment Over Time Chart -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Evolución del Sentimiento</h3>
      <%= line_chart @sentiment_over_time, 
          colors: ['#8b5cf6'], 
          min: -2, 
          max: 2,
          download: true %>
    </div>
    
    <!-- Distribution Pie Chart -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Distribución de Sentimientos</h3>
      <%= pie_chart({
            'Muy Positivo' => @sentiment_distribution[:very_positive][:count],
            'Positivo' => @sentiment_distribution[:positive][:count],
            'Neutral' => @sentiment_distribution[:neutral][:count],
            'Negativo' => @sentiment_distribution[:negative][:count],
            'Muy Negativo' => @sentiment_distribution[:very_negative][:count]
          },
          donut: true,
          colors: ['#10b981', '#84cc16', '#94a3b8', '#f97316', '#ef4444'],
          download: true %>
    </div>
    
    <!-- Reaction Breakdown -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">
        <i class="fa-solid fa-chart-bar text-indigo-600 mr-2"></i>
        Desglose de Reacciones
      </h3>
      <%= column_chart({
            'Love ❤️' => @reaction_breakdown[:love],
            'Haha 😂' => @reaction_breakdown[:haha],
            'Wow 😮' => @reaction_breakdown[:wow],
            'Like 👍' => @reaction_breakdown[:like],
            'Thankful 🙏' => @reaction_breakdown[:thankful],
            'Sad 😢' => @reaction_breakdown[:sad],
            'Angry 😡' => @reaction_breakdown[:angry]
          },
          colors: ['#ec4899', '#f59e0b', '#8b5cf6', '#3b82f6', '#10b981', '#6366f1', '#ef4444'],
          download: true %>
    </div>
  </section>
<% end %>
```

### 5.4 Add Sentiment Badge to Post Cards

In `app/views/facebook_topic/_facebook_entry.html.erb`, add before the closing `</div>` (around line 122):

```erb
<!-- Sentiment Badge -->
<% if facebook_entry.sentiment_score.present? %>
  <div class="mt-3 pt-3 border-t border-gray-200">
    <div class="flex items-center justify-between">
      <span class="text-xs text-gray-500">Sentimiento:</span>
      <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium border <%= facebook_entry.sentiment_color %>">
        <%= facebook_entry.sentiment_text %>
        <span class="ml-1.5 font-bold"><%= number_with_precision(facebook_entry.sentiment_score, precision: 1) %></span>
      </span>
    </div>
  </div>
<% end %>
```

---

## Testing Your Implementation

### 1. Test Individual Post Sentiment

```ruby
# Rails console
post = FacebookEntry.first
post.calculate_sentiment_analysis
post.save
puts "Score: #{post.sentiment_score}"
puts "Label: #{post.sentiment_label}"
puts "Text: #{post.sentiment_text}"
```

### 2. Test Topic Aggregation

```ruby
topic = Topic.first
summary = topic.facebook_sentiment_summary
puts "Average: #{summary[:average_sentiment]}"
puts "Distribution: #{summary[:sentiment_distribution]}"
```

### 3. Verify in Browser

Visit: `http://localhost:3000/facebook_topic/[TOPIC_ID]`

You should see:
- ✅ Sentiment analysis section
- ✅ Average sentiment score with emoji
- ✅ Trend indicator
- ✅ Charts (line, pie, column)
- ✅ Sentiment badges on post cards

---

## Troubleshooting

### Issue: Sentiment score is always 0

**Solution**: Make sure you have reactions data:
```ruby
FacebookEntry.where('reactions_total_count > 0').count
# Should return > 0
```

### Issue: Charts not showing

**Solution**: Make sure you have the `chartkick` gem installed:
```ruby
# Gemfile
gem 'chartkick'
gem 'groupdate'
```

### Issue: Sentiment not updating

**Solution**: Clear cache:
```ruby
Rails.cache.clear
```

Or in console:
```bash
rails tmp:cache:clear
```

### Issue: Performance is slow

**Solution**: Add database indexes (already in migration) and use caching:
```ruby
# Check if indexes exist
ActiveRecord::Base.connection.indexes(:facebook_entries)
```

---

## Next Steps

Once basics are working:

1. **Add more detailed views** - See full implementation plan for complete UI
2. **Add background jobs** - Process sentiment asynchronously
3. **Add API endpoints** - Expose sentiment via API
4. **Add alerts** - Notify when sentiment drops significantly
5. **Add exports** - PDF/Excel reports with sentiment data

---

## Quick Reference: Sentiment Weights

| Reaction | Weight | Meaning |
|----------|--------|---------|
| ❤️ Love | +2.0 | Very positive |
| 😂 Haha | +1.5 | Positive (can be sarcastic) |
| 😮 Wow | +1.0 | Positive interest |
| 👍 Like | +0.5 | Mild positive |
| 🙏 Thankful | +2.0 | Very positive |
| 😢 Sad | -1.5 | Negative |
| 😡 Angry | -2.0 | Very negative |

## Formula

```
Sentiment Score = Σ(reaction_count × weight) / total_reactions

Score Range:
+1.5 to +2.0 = Very Positive 😊
+0.5 to +1.5 = Positive 🙂
-0.5 to +0.5 = Neutral 😐
-1.5 to -0.5 = Negative ☹️
-2.0 to -1.5 = Very Negative 😠
```

---

## Support

For full implementation details, advanced features, and research references, see:
📄 **FACEBOOK_SENTIMENT_ANALYSIS_IMPLEMENTATION_PLAN.md**

---

**Total Time**: ~2-3 hours for basic implementation  
**Difficulty**: Medium  
**Status**: Ready to implement ✅

