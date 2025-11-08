# Facebook & Twitter Dashboard Refactoring Plan

**Date**: November 8, 2025
**Status**: 🔍 Analysis Complete - Implementation Plan

---

## 📊 Current State Analysis

### Digital & Tag Dashboards ✅ (Already Refactored)
- **Sentiment Type**: Categorical (positive, neutral, negative)
- **Data Source**: `Entry.polarity` field
- **Charts**: Line charts showing 3 sentiment categories over time
- **Status**: ✅ Using `shared/sentiment_trend_charts` partial + presenter

### Facebook Dashboard
- **Sentiment Type**: **Continuous score** (-2.0 to +2.0)
- **Data Source**: `FacebookEntry.sentiment_score` (weighted reactions)
- **Charts**: 
  - Line chart of average sentiment score over time
  - Pie chart of sentiment distribution (very positive, positive, neutral, negative, very negative)
- **Status**: ❌ Uses custom implementation, **DIFFERENT structure**

### Twitter Dashboard
- **Sentiment Type**: ⚠️ **Not implemented**
- **Data Source**: None (TwitterPost has no sentiment field)
- **Charts**: None
- **Status**: ❌ No sentiment analysis

---

## 🎯 Refactoring Strategy

### Option 1: Adapt Facebook to Use Shared Partial (NOT RECOMMENDED)

**Problem**: Facebook sentiment is fundamentally different:
- Continuous score (-2.0 to +2.0) vs categorical (positive/neutral/negative)
- Weighted reactions vs simple polarity
- 5 categories (very positive to very negative) vs 3 categories
- Different statistical methods

**Verdict**: ❌ Would require forcing square peg into round hole

### Option 2: Create Separate Partials for Different Sentiment Types (RECOMMENDED)

**Benefits**:
- Each dashboard uses appropriate visualization
- No forced abstractions
- Cleaner separation
- Future-proof

**Structure**:
```
app/views/shared/
├── _sentiment_trend_charts.html.erb        # For categorical (Digital, Tag)
├── _sentiment_score_charts.html.erb        # For continuous (Facebook)
└── _sentiment_analysis_placeholder.html.erb # For future (Twitter)
```

---

## 📋 What CAN Be Refactored

### 1. Facebook Charts - Create Dedicated Partial ✅

The Facebook sentiment visualization is complex and self-contained. We can refactor it into a dedicated partial with a presenter.

**Current**: 300+ lines of sentiment HTML in `facebook_topic/show.html.erb`  
**After**: Reusable partial + presenter

### 2. Twitter - No Refactoring Needed (Yet) ⚠️

Twitter doesn't have sentiment analysis. When implemented, it should use appropriate pattern based on data structure.

---

## 🚀 Implementation Plan

### Phase 1: Create Facebook Sentiment Partial (2-3 hours)

#### 1.1 Create `FacebookSentimentPresenter`

```ruby
# app/presenters/facebook_sentiment_presenter.rb
class FacebookSentimentPresenter
  attr_reader :sentiment_summary, :sentiment_distribution, :sentiment_over_time
  
  def initialize(options)
    @sentiment_summary = options[:sentiment_summary]
    @sentiment_distribution = options[:sentiment_distribution]
    @sentiment_over_time = options[:sentiment_over_time]
    @reaction_breakdown = options[:reaction_breakdown]
    @top_positive_posts = options[:top_positive_posts]
    @top_negative_posts = options[:top_negative_posts]
    @controversial_posts = options[:controversial_posts]
    @sentiment_trend = options[:sentiment_trend]
  end
  
  def has_data?
    @sentiment_summary.present?
  end
  
  def average_sentiment
    @sentiment_summary[:average_sentiment] if has_data?
  end
  
  def statistical_validity
    @sentiment_summary[:statistical_validity] if has_data?
  end
  
  # ... more presenter methods
end
```

#### 1.2 Create Partial

```erb
<!-- app/views/shared/_facebook_sentiment_analysis.html.erb -->
<% presenter = FacebookSentimentPresenter.new(local_assigns) %>
<% return unless presenter.has_data? %>

<section id="sentiment" class="mb-8">
  <h2 class="text-2xl font-bold text-gray-900 mb-6">
    <i class="fa-solid fa-heart-pulse text-purple-600 mr-2"></i>
    Análisis de Sentimiento
  </h2>
  
  <!-- Overview Cards -->
  <%= render 'shared/facebook_sentiment_overview', presenter: presenter %>
  
  <!-- Charts -->
  <%= render 'shared/facebook_sentiment_charts', presenter: presenter %>
  
  <!-- Top Posts -->
  <%= render 'shared/facebook_sentiment_top_posts', presenter: presenter %>
</section>
```

### Phase 2: Refactor Other Facebook Complex Sections (Optional)

- Temporal Intelligence section
- Viral content detection
- Engagement metrics

---

## 💡 Key Decision: Scope of Refactoring

### What We SHOULD Refactor:

1. ✅ **Facebook Sentiment Section** → Dedicated partial + presenter
   - 300+ lines → Reusable component
   - Complex logic → Encapsulated in presenter
   - Self-contained → Can be reused in other Facebook views

2. ✅ **Common UI Components** → Shared partials
   - KPI cards
   - Temporal intelligence display
   - Viral content cards

### What We SHOULD NOT Refactor:

1. ❌ **Force Facebook to use Digital sentiment partial**
   - Different data structures
   - Different visualizations
   - Would create brittle abstractions

2. ❌ **Create "universal" sentiment partial**
   - Over-abstraction
   - Hard to maintain
   - Violates YAGNI (You Aren't Gonna Need It)

---

## 🎯 Recommendation

### Immediate Action: Refactor Facebook Sentiment into Dedicated Components

**Benefits**:
- DRY within Facebook dashboard
- Cleaner controller
- Easier to test
- Can reuse in Facebook PDF views

**Implementation Time**: 2-3 hours

**Files to Create**:
1. `app/presenters/facebook_sentiment_presenter.rb`
2. `app/views/shared/_facebook_sentiment_analysis.html.erb`
3. `app/views/shared/_facebook_sentiment_overview.html.erb`
4. `app/views/shared/_facebook_sentiment_charts.html.erb`
5. `app/views/shared/_facebook_sentiment_top_posts.html.erb`
6. `test/presenters/facebook_sentiment_presenter_test.rb`

**Impact**:
- Facebook dashboard: 300+ lines → ~50 lines
- Reusable in PDF view
- Better maintainability

---

## 🔮 Future: Twitter Sentiment

When Twitter sentiment is implemented, choose pattern based on data:

**If categorical** (like Digital):
```erb
<%= render 'shared/sentiment_trend_charts',
      title: 'Twitter Sentiment',
      chart_data_counts: @twitter_sentiment_counts,
      chart_data_sums: @twitter_sentiment_sums %>
```

**If continuous** (like Facebook):
```erb
<%= render 'shared/twitter_sentiment_analysis',
      sentiment_data: @twitter_sentiment_data %>
```

---

## ✅ Conclusion

**Best Approach**: Create dedicated Facebook sentiment partial (not force it into Digital pattern)

**Reasoning**:
1. Facebook sentiment is fundamentally different (continuous vs categorical)
2. Forcing abstraction would create maintenance burden
3. Dedicated partial still achieves DRY within Facebook context
4. Follows Rails "Convention over Configuration"

**Next Steps**:
1. Create `FacebookSentimentPresenter`
2. Extract Facebook sentiment to partial
3. Update Facebook controller to use presenter
4. Add tests

**Let me know if you want me to proceed with this approach!**

---

**Note**: If you specifically want to try forcing Facebook into the digital sentiment partial pattern, I can do that, but I strongly recommend against it based on the data structure differences outlined above.

