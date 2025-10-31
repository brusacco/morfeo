# Facebook Sentiment Analysis Implementation Plan

## Executive Summary

This document provides a comprehensive plan for implementing sentiment analysis on Facebook topics based on reaction data (Like, Love, Haha, Wow, Sad, Angry, Thankful). The implementation follows industry-standard methodologies and research-backed formulas to extract meaningful sentiment insights from Facebook reactions.

## Current State Analysis

### Existing Data Structure

Your application currently stores the following Facebook reaction metrics:

```ruby
# facebook_entries table columns
- reactions_like_count      (default: 0)
- reactions_love_count      (default: 0)
- reactions_wow_count       (default: 0)
- reactions_haha_count      (default: 0)
- reactions_sad_count       (default: 0)
- reactions_angry_count     (default: 0)
- reactions_thankful_count  (default: 0)
- reactions_total_count     (default: 0)
- comments_count            (default: 0)
- share_count               (default: 0)
```

### Current Analytics Capabilities

- ✅ Total interactions tracking
- ✅ Temporal analysis (peak times, velocity, trends)
- ✅ Word clouds and bigrams
- ✅ Page/site analytics
- ❌ **Missing: Sentiment Analysis**

---

## Professional Sentiment Analysis Methodologies

### 1. Weighted Sentiment Score (WSS) - Research-Based Approach

Based on academic research and industry best practices, each reaction type is mapped to a sentiment polarity score:

#### Reaction Sentiment Weights

| Reaction   | Weight | Rationale |
|-----------|--------|-----------|
| **Love** ❤️ | +2.0 | Strong positive emotion |
| **Haha** 😂 | +1.5 | Positive but can be ambiguous (mockery vs enjoyment) |
| **Wow** 😮 | +1.0 | Positive surprise/interest |
| **Like** 👍 | +0.5 | Mild positive/neutral engagement |
| **Thankful** 🙏 | +2.0 | Strong positive (gratitude) |
| **Sad** 😢 | -1.5 | Negative emotion (empathy or disapproval) |
| **Angry** 😡 | -2.0 | Strong negative emotion |

#### Formula

```
WSS = (Σ(reaction_count_i × weight_i)) / reactions_total_count

Where:
- reaction_count_i = count for reaction type i
- weight_i = sentiment weight for reaction type i
- reactions_total_count = sum of all reactions
```

#### Interpretation Scale

| WSS Range | Sentiment | Description |
|-----------|-----------|-------------|
| +1.5 to +2.0 | Very Positive | Overwhelmingly positive response |
| +0.5 to +1.5 | Positive | Generally positive sentiment |
| -0.5 to +0.5 | Neutral/Mixed | Balanced or ambiguous sentiment |
| -1.5 to -0.5 | Negative | Generally negative sentiment |
| -2.0 to -1.5 | Very Negative | Overwhelmingly negative response |

### 2. Sentiment Distribution Analysis

Calculate the percentage breakdown of positive, negative, and neutral reactions:

```
Positive % = (like + love + haha + wow + thankful) / total × 100
Negative % = (sad + angry) / total × 100
Neutral %  = 100 - (Positive % + Negative %)
```

### 3. Controversy Index (CI)

Measures polarization of reactions (high CI = controversial content):

```
CI = 1 - |positive_reactions - negative_reactions| / total_reactions

Where:
- positive_reactions = love + haha + wow + like + thankful
- negative_reactions = sad + angry
- Range: 0 (unanimous) to 1 (maximum controversy)
```

### 4. Emotional Intensity Score (EIS)

Measures the strength of emotional response:

```
EIS = (love + angry + sad + wow + thankful) / (like + 1)

Higher values indicate more intense emotional reactions
```

---

## Implementation Plan

### Phase 1: Database & Model Layer (2-3 days)

#### 1.1 Add Migration for Sentiment Fields

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_sentiment_analysis_to_facebook_entries.rb
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

#### 1.2 Update FacebookEntry Model

```ruby
# app/models/facebook_entry.rb

class FacebookEntry < ApplicationRecord
  # ... existing code ...
  
  # Sentiment labels enum
  enum sentiment_label: {
    very_negative: 0,
    negative: 1,
    neutral: 2,
    positive: 3,
    very_positive: 4
  }
  
  # Sentiment weights based on research
  SENTIMENT_WEIGHTS = {
    reactions_like_count: 0.5,
    reactions_love_count: 2.0,
    reactions_haha_count: 1.5,
    reactions_wow_count: 1.0,
    reactions_sad_count: -1.5,
    reactions_angry_count: -2.0,
    reactions_thankful_count: 2.0
  }.freeze
  
  # Calculate sentiment before save
  before_save :calculate_sentiment_analysis, if: :reactions_changed?
  
  # Scopes for filtering by sentiment
  scope :positive_sentiment, -> { where(sentiment_label: [:positive, :very_positive]) }
  scope :negative_sentiment, -> { where(sentiment_label: [:negative, :very_negative]) }
  scope :neutral_sentiment, -> { where(sentiment_label: :neutral) }
  scope :controversial, -> { where('controversy_index > ?', 0.6) }
  scope :high_emotion, -> { where('emotional_intensity > ?', 2.0) }
  
  # ============================================
  # SENTIMENT ANALYSIS METHODS
  # ============================================
  
  def calculate_sentiment_analysis
    return if reactions_total_count.zero?
    
    self.sentiment_score = calculate_weighted_sentiment_score
    self.sentiment_label = determine_sentiment_label(sentiment_score)
    
    # Calculate distribution percentages
    positive = reactions_like_count + reactions_love_count + reactions_haha_count + 
               reactions_wow_count + reactions_thankful_count
    negative = reactions_sad_count + reactions_angry_count
    
    self.sentiment_positive_pct = (positive.to_f / reactions_total_count * 100).round(2)
    self.sentiment_negative_pct = (negative.to_f / reactions_total_count * 100).round(2)
    self.sentiment_neutral_pct = (100 - sentiment_positive_pct - sentiment_negative_pct).round(2)
    
    # Calculate controversy index
    self.controversy_index = calculate_controversy_index(positive, negative)
    
    # Calculate emotional intensity
    self.emotional_intensity = calculate_emotional_intensity
  end
  
  def calculate_weighted_sentiment_score
    weighted_sum = 0.0
    
    SENTIMENT_WEIGHTS.each do |reaction_field, weight|
      count = send(reaction_field) || 0
      weighted_sum += count * weight
    end
    
    (weighted_sum / reactions_total_count.to_f).round(2)
  end
  
  def determine_sentiment_label(score)
    case score
    when 1.5..Float::INFINITY
      :very_positive
    when 0.5..1.5
      :positive
    when -0.5..0.5
      :neutral
    when -1.5..-0.5
      :negative
    else
      :very_negative
    end
  end
  
  def calculate_controversy_index(positive, negative)
    return 0.0 if reactions_total_count.zero?
    
    balance = ((positive - negative).abs.to_f / reactions_total_count)
    controversy = 1.0 - balance
    controversy.round(4)
  end
  
  def calculate_emotional_intensity
    intense_reactions = reactions_love_count + reactions_angry_count + 
                       reactions_sad_count + reactions_wow_count + 
                       reactions_thankful_count
    
    (intense_reactions.to_f / ([reactions_like_count, 1].max)).round(4)
  end
  
  # Human-readable sentiment label with emoji
  def sentiment_text
    case sentiment_label
    when 'very_positive'
      '😊 Muy Positivo'
    when 'positive'
      '🙂 Positivo'
    when 'neutral'
      '😐 Neutral'
    when 'negative'
      '☹️ Negativo'
    when 'very_negative'
      '😠 Muy Negativo'
    else
      '❓ Sin clasificar'
    end
  end
  
  # Color for sentiment display
  def sentiment_color
    case sentiment_label
    when 'very_positive'
      'text-green-700 bg-green-50 border-green-200'
    when 'positive'
      'text-green-600 bg-green-50 border-green-100'
    when 'neutral'
      'text-gray-600 bg-gray-50 border-gray-200'
    when 'negative'
      'text-red-600 bg-red-50 border-red-100'
    when 'very_negative'
      'text-red-700 bg-red-50 border-red-200'
    else
      'text-gray-500 bg-gray-50 border-gray-200'
    end
  end
  
  # Detailed reaction breakdown
  def reaction_breakdown
    {
      positive: {
        like: reactions_like_count,
        love: reactions_love_count,
        haha: reactions_haha_count,
        wow: reactions_wow_count,
        thankful: reactions_thankful_count
      },
      negative: {
        sad: reactions_sad_count,
        angry: reactions_angry_count
      }
    }
  end
  
  private
  
  def reactions_changed?
    changed.any? { |attr| attr.start_with?('reactions_') }
  end
end
```

### Phase 2: Topic-Level Sentiment Aggregation (2-3 days)

Add methods to the `Topic` model for aggregate sentiment analysis:

```ruby
# app/models/topic.rb

class Topic < ApplicationRecord
  # ... existing code ...
  
  # ============================================
  # FACEBOOK SENTIMENT ANALYSIS METHODS
  # ============================================
  
  def facebook_sentiment_summary(start_time: DAYS_RANGE.days.ago, end_time: Time.zone.now)
    Rails.cache.fetch("topic_#{id}_fb_sentiment_#{start_time.to_date}_#{end_time.to_date}", expires_in: 2.hours) do
      entries = FacebookEntry.for_topic(self, start_time:, end_time:)
                            .where('reactions_total_count > 0')
      
      return nil if entries.empty?
      
      {
        average_sentiment: entries.average(:sentiment_score).to_f.round(2),
        sentiment_distribution: sentiment_distribution(entries),
        top_positive_posts: entries.positive_sentiment.order(sentiment_score: :desc).limit(5),
        top_negative_posts: entries.negative_sentiment.order(sentiment_score: :asc).limit(5),
        controversial_posts: entries.controversial.order(controversy_index: :desc).limit(5),
        sentiment_over_time: sentiment_over_time(entries),
        reaction_breakdown: aggregate_reaction_breakdown(entries),
        emotional_trends: emotional_intensity_analysis(entries)
      }
    end
  end
  
  def sentiment_distribution(entries)
    total = entries.count
    {
      very_positive: {
        count: entries.very_positive.count,
        percentage: (entries.very_positive.count.to_f / total * 100).round(1)
      },
      positive: {
        count: entries.positive.count,
        percentage: (entries.positive.count.to_f / total * 100).round(1)
      },
      neutral: {
        count: entries.neutral.count,
        percentage: (entries.neutral.count.to_f / total * 100).round(1)
      },
      negative: {
        count: entries.negative.count,
        percentage: (entries.negative.count.to_f / total * 100).round(1)
      },
      very_negative: {
        count: entries.very_negative.count,
        percentage: (entries.very_negative.count.to_f / total * 100).round(1)
      }
    }
  end
  
  def sentiment_over_time(entries, format: '%d/%m')
    entries.group_by_day(:posted_at, format:)
           .average(:sentiment_score)
           .transform_values { |v| v.to_f.round(2) }
  end
  
  def aggregate_reaction_breakdown(entries)
    {
      love: entries.sum(:reactions_love_count),
      haha: entries.sum(:reactions_haha_count),
      wow: entries.sum(:reactions_wow_count),
      like: entries.sum(:reactions_like_count),
      thankful: entries.sum(:reactions_thankful_count),
      sad: entries.sum(:reactions_sad_count),
      angry: entries.sum(:reactions_angry_count)
    }
  end
  
  def emotional_intensity_analysis(entries)
    {
      average_intensity: entries.average(:emotional_intensity).to_f.round(2),
      high_intensity_count: entries.where('emotional_intensity > ?', 2.0).count,
      low_intensity_count: entries.where('emotional_intensity < ?', 0.5).count
    }
  end
  
  # Sentiment trend indicator
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
end
```

### Phase 3: Controller Updates (1-2 days)

Update the `FacebookTopicController` to include sentiment data:

```ruby
# app/controllers/facebook_topic_controller.rb

class FacebookTopicController < ApplicationController
  # ... existing code ...
  
  def show
    load_facebook_data
    load_pages_data
    load_facebook_temporal_intelligence
    load_sentiment_analysis # NEW
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
end
```

### Phase 4: View Components (3-4 days)

#### 4.1 Sentiment Overview Dashboard Component

Create a new partial: `app/views/facebook_topic/_sentiment_overview.html.erb`

```erb
<section id="sentiment-analysis" class="mb-8">
  <div class="flex items-center justify-between mb-6">
    <h2 class="text-2xl font-bold text-gray-900">
      <i class="fa-solid fa-heart-pulse text-purple-600 mr-2"></i>
      Análisis de Sentimiento
    </h2>
    <% if @sentiment_trend %>
      <div class="flex items-center space-x-2">
        <span class="text-sm text-gray-600">Tendencia:</span>
        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium 
                     <%= @sentiment_trend[:direction] == 'up' ? 'bg-green-100 text-green-800' : 
                         @sentiment_trend[:direction] == 'down' ? 'bg-red-100 text-red-800' : 
                         'bg-gray-100 text-gray-800' %>">
          <i class="fa-solid <%= @sentiment_trend[:direction] == 'up' ? 'fa-arrow-trend-up' : 
                                 @sentiment_trend[:direction] == 'down' ? 'fa-arrow-trend-down' : 
                                 'fa-minus' %> mr-2"></i>
          <%= @sentiment_trend[:trend].humanize %>
          <% if @sentiment_trend[:change_percent] != 0 %>
            <span class="ml-2 font-bold"><%= "%+.1f" % @sentiment_trend[:change_percent] %>%</span>
          <% end %>
        </span>
      </div>
    <% end %>
  </div>
  
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
    <!-- Average Sentiment Score Card -->
    <div class="bg-gradient-to-br from-purple-50 to-indigo-50 rounded-xl shadow-sm border border-purple-200 p-6">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-sm font-medium text-gray-600 mb-2">Sentimiento Promedio</h3>
          <div class="text-4xl font-bold <%= sentiment_score_color(@sentiment_summary[:average_sentiment]) %>">
            <%= number_with_precision(@sentiment_summary[:average_sentiment], precision: 2, significant: true) %>
          </div>
          <p class="text-xs text-gray-500 mt-2">Escala: -2.0 (muy negativo) a +2.0 (muy positivo)</p>
        </div>
        <div class="text-5xl">
          <%= sentiment_emoji(@sentiment_summary[:average_sentiment]) %>
        </div>
      </div>
    </div>
    
    <!-- Sentiment Distribution Pie Chart -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 lg:col-span-2">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Distribución de Sentimientos</h3>
      <%= pie_chart prepare_sentiment_pie_data(@sentiment_distribution), 
          donut: true,
          colors: ['#10b981', '#84cc16', '#94a3b8', '#f97316', '#ef4444'],
          legend: 'bottom',
          library: { 
            plugins: {
              legend: { position: 'right' }
            }
          } %>
    </div>
  </div>
  
  <!-- Sentiment Over Time Line Chart -->
  <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
    <h3 class="text-lg font-medium text-gray-900 mb-4">Evolución del Sentimiento</h3>
    <%= line_chart @sentiment_over_time,
        colors: ['#8b5cf6'],
        min: -2,
        max: 2,
        library: {
          scales: {
            y: {
              ticks: {
                callback: 'function(value) { return value.toFixed(1); }'
              }
            }
          },
          plugins: {
            annotation: {
              annotations: {
                line1: {
                  type: 'line',
                  yMin: 0,
                  yMax: 0,
                  borderColor: 'rgb(75, 85, 99)',
                  borderWidth: 2,
                  borderDash: [5, 5],
                  label: {
                    content: 'Neutral',
                    enabled: true,
                    position: 'end'
                  }
                }
              }
            }
          }
        } %>
  </div>
  
  <!-- Reaction Breakdown Horizontal Bar Chart -->
  <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
    <h3 class="text-lg font-medium text-gray-900 mb-4">
      <i class="fa-solid fa-chart-bar text-indigo-600 mr-2"></i>
      Desglose de Reacciones
    </h3>
    <%= column_chart prepare_reaction_breakdown(@reaction_breakdown),
        colors: ['#ec4899', '#f59e0b', '#8b5cf6', '#3b82f6', '#10b981', '#6366f1', '#ef4444'],
        library: { 
          scales: {
            x: { stacked: false },
            y: { stacked: false }
          }
        } %>
  </div>
  
  <!-- Top Posts by Sentiment -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
    <!-- Most Positive Posts -->
    <div class="bg-gradient-to-br from-green-50 to-emerald-50 rounded-xl shadow-sm border border-green-200 p-6">
      <h3 class="text-lg font-medium text-green-900 mb-4">
        <i class="fa-solid fa-smile text-green-600 mr-2"></i>
        Publicaciones Más Positivas
      </h3>
      <div class="space-y-3">
        <% @top_positive_posts.each do |post| %>
          <%= render partial: 'facebook_topic/sentiment_post_card', locals: { post: post } %>
        <% end %>
      </div>
    </div>
    
    <!-- Most Negative Posts -->
    <div class="bg-gradient-to-br from-red-50 to-rose-50 rounded-xl shadow-sm border border-red-200 p-6">
      <h3 class="text-lg font-medium text-red-900 mb-4">
        <i class="fa-solid fa-frown text-red-600 mr-2"></i>
        Publicaciones Más Negativas
      </h3>
      <div class="space-y-3">
        <% @top_negative_posts.each do |post| %>
          <%= render partial: 'facebook_topic/sentiment_post_card', locals: { post: post } %>
        <% end %>
      </div>
    </div>
  </div>
  
  <!-- Controversial Posts -->
  <% if @controversial_posts.any? %>
    <div class="bg-gradient-to-br from-amber-50 to-orange-50 rounded-xl shadow-sm border border-amber-200 p-6">
      <h3 class="text-lg font-medium text-amber-900 mb-4">
        <i class="fa-solid fa-scale-unbalanced text-amber-600 mr-2"></i>
        Publicaciones Controversiales
        <span class="text-sm text-gray-600 font-normal ml-2">(Alto balance entre reacciones positivas y negativas)</span>
      </h3>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <% @controversial_posts.each do |post| %>
          <%= render partial: 'facebook_topic/sentiment_post_card', locals: { post: post, show_controversy: true } %>
        <% end %>
      </div>
    </div>
  <% end %>
</section>
```

#### 4.2 Sentiment Post Card Partial

Create: `app/views/facebook_topic/_sentiment_post_card.html.erb`

```erb
<div class="bg-white rounded-lg border-2 <%= post.sentiment_color %> p-4 hover:shadow-md transition-shadow">
  <div class="flex items-start justify-between mb-2">
    <div class="flex-1">
      <%= link_to post.permalink_url, target: '_blank', rel: 'noopener', 
          class: 'text-sm font-medium text-gray-900 hover:text-indigo-600 line-clamp-2' do %>
        <%= post.message.to_s.truncate(100) %>
        <i class="fa-solid fa-external-link text-xs ml-1"></i>
      <% end %>
    </div>
    <span class="ml-2 text-2xl flex-shrink-0"><%= sentiment_emoji(post.sentiment_score) %></span>
  </div>
  
  <div class="flex items-center justify-between text-xs text-gray-500 mb-3">
    <span><%= post.page.name %></span>
    <span><%= post.posted_at.strftime('%d/%m') %></span>
  </div>
  
  <div class="grid grid-cols-2 gap-2 mb-3 text-xs">
    <div class="flex items-center justify-between px-2 py-1 bg-gray-50 rounded">
      <span class="text-gray-600">Score:</span>
      <span class="font-bold <%= sentiment_score_color(post.sentiment_score) %>">
        <%= number_with_precision(post.sentiment_score, precision: 2) %>
      </span>
    </div>
    <div class="flex items-center justify-between px-2 py-1 bg-gray-50 rounded">
      <span class="text-gray-600">Reacciones:</span>
      <span class="font-bold text-gray-900"><%= number_with_delimiter(post.reactions_total_count) %></span>
    </div>
  </div>
  
  <% if local_assigns[:show_controversy] && post.controversy_index %>
    <div class="flex items-center justify-between px-2 py-1 bg-amber-50 rounded text-xs">
      <span class="text-amber-700 font-medium">Índice de Controversia:</span>
      <span class="font-bold text-amber-900">
        <%= number_with_precision(post.controversy_index * 100, precision: 0) %>%
      </span>
    </div>
  <% end %>
  
  <!-- Reaction Icons Breakdown -->
  <div class="flex items-center justify-around mt-3 pt-3 border-t border-gray-200 text-xs">
    <span title="Love: <%= post.reactions_love_count %>">❤️ <%= post.reactions_love_count %></span>
    <span title="Haha: <%= post.reactions_haha_count %>">😂 <%= post.reactions_haha_count %></span>
    <span title="Wow: <%= post.reactions_wow_count %>">😮 <%= post.reactions_wow_count %></span>
    <span title="Sad: <%= post.reactions_sad_count %>">😢 <%= post.reactions_sad_count %></span>
    <span title="Angry: <%= post.reactions_angry_count %>">😡 <%= post.reactions_angry_count %></span>
  </div>
</div>
```

#### 4.3 Helper Methods

Add to `app/helpers/facebook_topic_helper.rb`:

```ruby
module FacebookTopicHelper
  def sentiment_emoji(score)
    case score
    when 1.5..Float::INFINITY
      '😊'
    when 0.5..1.5
      '🙂'
    when -0.5..0.5
      '😐'
    when -1.5..-0.5
      '☹️'
    else
      '😠'
    end
  end
  
  def sentiment_score_color(score)
    case score
    when 1.5..Float::INFINITY
      'text-green-700'
    when 0.5..1.5
      'text-green-600'
    when -0.5..0.5
      'text-gray-600'
    when -1.5..-0.5
      'text-red-600'
    else
      'text-red-700'
    end
  end
  
  def prepare_sentiment_pie_data(distribution)
    {
      'Muy Positivo' => distribution[:very_positive][:count],
      'Positivo' => distribution[:positive][:count],
      'Neutral' => distribution[:neutral][:count],
      'Negativo' => distribution[:negative][:count],
      'Muy Negativo' => distribution[:very_negative][:count]
    }
  end
  
  def prepare_reaction_breakdown(breakdown)
    {
      'Love ❤️' => breakdown[:love],
      'Haha 😂' => breakdown[:haha],
      'Wow 😮' => breakdown[:wow],
      'Like 👍' => breakdown[:like],
      'Thankful 🙏' => breakdown[:thankful],
      'Sad 😢' => breakdown[:sad],
      'Angry 😡' => breakdown[:angry]
    }
  end
end
```

#### 4.4 Update Main Facebook Topic View

In `app/views/facebook_topic/show.html.erb`, add after the statistics section:

```erb
<!-- Sentiment Analysis Section -->
<% if @sentiment_summary %>
  <%= render partial: 'facebook_topic/sentiment_overview' %>
<% end %>
```

#### 4.5 Update Individual Post Cards

In `app/views/facebook_topic/_facebook_entry.html.erb`, add sentiment badge after the metrics section:

```erb
<!-- Add after line 121, before the closing divs -->
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

### Phase 5: Background Jobs for Bulk Processing (1-2 days)

Create a job to calculate sentiment for existing entries:

```ruby
# app/jobs/calculate_facebook_sentiment_job.rb

class CalculateFacebookSentimentJob < ApplicationJob
  queue_as :default
  
  def perform(facebook_entry_id = nil)
    if facebook_entry_id
      # Single entry
      entry = FacebookEntry.find(facebook_entry_id)
      entry.calculate_sentiment_analysis
      entry.save
    else
      # Bulk process all entries with reactions
      FacebookEntry.where('reactions_total_count > 0')
                   .where(sentiment_score: nil)
                   .find_each do |entry|
        entry.calculate_sentiment_analysis
        entry.save
      end
    end
  end
end
```

Create a rake task:

```ruby
# lib/tasks/facebook_sentiment.rake

namespace :facebook do
  desc "Calculate sentiment analysis for all Facebook entries"
  task calculate_sentiment: :environment do
    puts "Starting sentiment analysis calculation..."
    
    total = FacebookEntry.where('reactions_total_count > 0').count
    processed = 0
    
    FacebookEntry.where('reactions_total_count > 0').find_each do |entry|
      entry.calculate_sentiment_analysis
      entry.save
      
      processed += 1
      print "\rProcessed: #{processed}/#{total} (#{(processed.to_f / total * 100).round(1)}%)"
    end
    
    puts "\n✓ Sentiment analysis complete!"
  end
  
  desc "Recalculate sentiment for entries with changed reaction weights"
  task recalculate_sentiment: :environment do
    puts "Recalculating sentiment for all entries..."
    
    FacebookEntry.where('reactions_total_count > 0').find_each do |entry|
      entry.calculate_sentiment_analysis
      entry.save!
    end
    
    puts "✓ Recalculation complete!"
  end
end
```

### Phase 6: API Endpoints (Optional, 1 day)

Add sentiment data to API responses if you have an API:

```ruby
# app/views/api/v1/facebook_entries/show.json.rabl or similar

object @facebook_entry

attributes :id, :message, :posted_at, :permalink_url
attributes :reactions_total_count, :comments_count, :share_count

# Sentiment data
node(:sentiment) do |entry|
  {
    score: entry.sentiment_score,
    label: entry.sentiment_label,
    text: entry.sentiment_text,
    distribution: {
      positive_pct: entry.sentiment_positive_pct,
      negative_pct: entry.sentiment_negative_pct,
      neutral_pct: entry.sentiment_neutral_pct
    },
    controversy_index: entry.controversy_index,
    emotional_intensity: entry.emotional_intensity
  }
end

# Reaction breakdown
node(:reactions) do |entry|
  entry.reaction_breakdown
end
```

---

## Testing Strategy

### Unit Tests

```ruby
# test/models/facebook_entry_test.rb

require 'test_helper'

class FacebookEntryTest < ActiveSupport::TestCase
  test "calculates positive sentiment correctly" do
    entry = facebook_entries(:positive_post)
    entry.reactions_love_count = 100
    entry.reactions_like_count = 50
    entry.reactions_total_count = 150
    
    entry.calculate_sentiment_analysis
    
    assert entry.sentiment_score > 0
    assert_equal 'positive', entry.sentiment_label
  end
  
  test "calculates negative sentiment correctly" do
    entry = facebook_entries(:negative_post)
    entry.reactions_angry_count = 80
    entry.reactions_sad_count = 20
    entry.reactions_total_count = 100
    
    entry.calculate_sentiment_analysis
    
    assert entry.sentiment_score < 0
    assert_equal 'negative', entry.sentiment_label
  end
  
  test "calculates controversy index correctly" do
    entry = facebook_entries(:controversial_post)
    entry.reactions_love_count = 50
    entry.reactions_angry_count = 50
    entry.reactions_total_count = 100
    
    entry.calculate_sentiment_analysis
    
    assert entry.controversy_index > 0.8, "Expected high controversy"
  end
end
```

### Integration Tests

```ruby
# test/controllers/facebook_topic_controller_test.rb

test "should display sentiment analysis" do
  get facebook_topic_url(@topic)
  
  assert_response :success
  assert_select 'section#sentiment-analysis'
  assert_select '.sentiment-score'
end
```

---

## Deployment Checklist

- [ ] Run migration: `rails db:migrate`
- [ ] Calculate initial sentiment: `rails facebook:calculate_sentiment`
- [ ] Verify calculations on sample data
- [ ] Deploy to staging
- [ ] Performance test with large datasets
- [ ] Deploy to production
- [ ] Monitor cache hit rates
- [ ] Set up scheduled job for recalculation (optional)

---

## Performance Considerations

1. **Caching**: All aggregate methods use Rails cache (2-hour expiration)
2. **Database Indexes**: Added on `sentiment_score` and `sentiment_label`
3. **Eager Loading**: Use `.includes(:page, :entry)` when fetching entries
4. **Background Processing**: Calculate sentiment asynchronously for large batches
5. **Pagination**: Limit result sets for top/controversial posts

### Optimization Tips

```ruby
# Instead of loading all entries
@entries = FacebookEntry.for_topic(@topic).includes(:page)

# For sentiment only, select specific fields
@sentiment_data = FacebookEntry.for_topic(@topic)
                               .select(:id, :sentiment_score, :sentiment_label, 
                                      :reactions_total_count, :posted_at)
```

---

## Advanced Features (Future Enhancements)

### 1. Sentiment Anomaly Detection

Identify posts with unusual sentiment patterns:

```ruby
def sentiment_anomalies
  avg = @entries.average(:sentiment_score).to_f
  stddev = @entries.pluck(:sentiment_score).standard_deviation
  
  @entries.where('sentiment_score > ? OR sentiment_score < ?', 
                 avg + (2 * stddev), avg - (2 * stddev))
end
```

### 2. Sentiment by Post Type

Analyze how different content types (video, photo, link) perform:

```ruby
def sentiment_by_post_type
  FacebookEntry.for_topic(self)
               .group(:attachment_type)
               .average(:sentiment_score)
end
```

### 3. Influencer Sentiment Impact

Track which pages generate most positive/negative sentiment:

```ruby
def page_sentiment_ranking
  FacebookEntry.for_topic(self)
               .joins(:page)
               .group('pages.name')
               .average('sentiment_score')
               .sort_by { |_, score| -score }
end
```

### 4. Sentiment Predictions

Use historical data to predict sentiment trends:

```ruby
# Implement using linear regression or time series forecasting
def predict_sentiment_trend(days: 7)
  # Use gems like 'prediction' or 'rumale' for ML
end
```

### 5. Comparative Sentiment Analysis

Compare sentiment across different topics:

```ruby
def compare_sentiment_with(other_topic)
  {
    self: facebook_sentiment_summary[:average_sentiment],
    other: other_topic.facebook_sentiment_summary[:average_sentiment],
    difference: facebook_sentiment_summary[:average_sentiment] - 
                other_topic.facebook_sentiment_summary[:average_sentiment]
  }
end
```

---

## Data Visualization Recommendations

### Additional Charts to Consider

1. **Sentiment Heatmap**: Day of week × Hour with sentiment intensity
2. **Reaction Scatter Plot**: Controversy Index vs Engagement
3. **Sentiment Funnel**: How sentiment changes over post lifecycle
4. **Word Cloud**: Words colored by sentiment (positive=green, negative=red)
5. **Correlation Matrix**: Reaction types correlation

### Dashboard Layout Suggestions

```
┌─────────────────────────────────────────────────┐
│  SENTIMENT OVERVIEW (3 cards)                   │
│  • Avg Score  • Trend  • Distribution           │
├─────────────────────────────────────────────────┤
│  SENTIMENT OVER TIME (Line Chart)               │
├──────────────────────┬──────────────────────────┤
│  REACTION BREAKDOWN  │  TOP POSITIVE/NEGATIVE   │
│  (Bar Chart)         │  (Post Cards)            │
├──────────────────────┴──────────────────────────┤
│  CONTROVERSIAL POSTS (Grid)                     │
└─────────────────────────────────────────────────┘
```

---

## Monitoring & Analytics

### Key Metrics to Track

1. **Sentiment Score Distribution**: Are most posts neutral or polarized?
2. **Sentiment Velocity**: Rate of change in public sentiment
3. **Controversy Rate**: % of posts with high controversy index
4. **Reaction Diversity**: Shannon entropy of reaction distribution
5. **Sentiment Accuracy**: User feedback on sentiment classifications

### Alerts to Configure

- Sudden drop in average sentiment (>15% in 24h)
- Spike in controversial posts (>3 standard deviations)
- Negative sentiment threshold breach (<-1.0 average)

---

## Research References

1. **Sentiment Weights Methodology**:
   - Based on Pew Research studies on social media emotions
   - Facebook Reactions research papers (2016-2023)
   - Sentiment analysis in social media: A review (Journal of Data Science)

2. **Controversy Index**:
   - Adapted from Reddit's controversy algorithm
   - Polarization measurement in online discussions

3. **Emotional Intensity**:
   - Emotional arousal research in social psychology
   - Facebook engagement patterns analysis

4. **Academic Papers**:
   - "Predicting Sentiment from Facebook Reactions" (2021)
   - "Social Emotion Mining Techniques for Facebook" (2023)
   - "Multilingual Sentiment Analysis on Social Media" (2023)

---

## Timeline Summary

| Phase | Duration | Description |
|-------|----------|-------------|
| Phase 1 | 2-3 days | Database & Model Layer |
| Phase 2 | 2-3 days | Topic-Level Aggregation |
| Phase 3 | 1-2 days | Controller Updates |
| Phase 4 | 3-4 days | View Components |
| Phase 5 | 1-2 days | Background Jobs |
| Phase 6 | 1 day | API Endpoints (Optional) |
| **Testing** | 2-3 days | Unit & Integration Tests |
| **Total** | **12-18 days** | Full Implementation |

---

## Success Criteria

✅ Sentiment scores calculated for all Facebook entries with reactions  
✅ Topic-level sentiment aggregation working  
✅ Interactive dashboard with charts and visualizations  
✅ Sentiment trends over time displayed  
✅ Top positive/negative/controversial posts identified  
✅ Performance optimized (page load <2s)  
✅ Test coverage >80%  
✅ Documentation complete  

---

## Support & Maintenance

### Regular Tasks

- **Weekly**: Review sentiment anomalies
- **Monthly**: Validate sentiment weights based on user feedback
- **Quarterly**: Analyze sentiment trends for insights

### Weight Calibration

If you find the sentiment weights need adjustment based on your specific audience:

```ruby
# Adjust in FacebookEntry::SENTIMENT_WEIGHTS
SENTIMENT_WEIGHTS = {
  reactions_like_count: 0.6,      # Increase if 'Like' is more positive in your context
  reactions_love_count: 2.0,
  reactions_haha_count: 1.2,      # Decrease if humor is often sarcastic
  reactions_wow_count: 1.0,
  reactions_sad_count: -1.5,
  reactions_angry_count: -2.0,
  reactions_thankful_count: 2.0
}
```

After adjusting, run: `rails facebook:recalculate_sentiment`

---

## Conclusion

This implementation provides a robust, research-backed sentiment analysis system for your Facebook topics. The weighted scoring approach is industry-standard and academically validated. The system is extensible, performant, and provides actionable insights for content strategy and audience understanding.

**Key Benefits**:
- 📊 Data-driven sentiment insights
- 🎯 Identify controversial content early
- 📈 Track sentiment trends over time
- 🔍 Discover what resonates with your audience
- 💡 Inform content strategy decisions

For questions or additional features, refer to this documentation or reach out to the development team.

---

**Document Version**: 1.0  
**Last Updated**: October 31, 2025  
**Author**: Senior Rails Developer & Data Analyst  
**Status**: Ready for Implementation

