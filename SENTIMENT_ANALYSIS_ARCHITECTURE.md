# Sentiment Analysis Architecture Diagram

```
╔════════════════════════════════════════════════════════════════════════════╗
║                  FACEBOOK SENTIMENT ANALYSIS ARCHITECTURE                  ║
╚════════════════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────────────┐
│                        DATA LAYER (PostgreSQL/MySQL)                     │
└──────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ Existing Fields:
                                      │ ├─ reactions_like_count
                                      │ ├─ reactions_love_count
                                      │ ├─ reactions_haha_count
                                      │ ├─ reactions_wow_count
                                      │ ├─ reactions_sad_count
                                      │ ├─ reactions_angry_count
                                      │ ├─ reactions_thankful_count
                                      │ └─ reactions_total_count
                                      │
                                      │ New Fields (Migration):
                                      │ ├─ sentiment_score (decimal)
                                      │ ├─ sentiment_label (enum)
                                      │ ├─ sentiment_positive_pct
                                      │ ├─ sentiment_negative_pct
                                      │ ├─ sentiment_neutral_pct
                                      │ ├─ controversy_index
                                      │ └─ emotional_intensity
                                      ▼

┌──────────────────────────────────────────────────────────────────────────┐
│                      MODEL LAYER (FacebookEntry)                         │
└──────────────────────────────────────────────────────────────────────────┘

          ┌─────────────────────────────────────────────────┐
          │   CALCULATION ENGINE (before_save callback)    │
          │                                                 │
          │   Input: Reaction counts                        │
          │   Process:                                      │
          │   1. calculate_weighted_sentiment_score()       │
          │      WSS = Σ(count × weight) / total           │
          │                                                 │
          │   2. determine_sentiment_label(wss)            │
          │      ├─ Very Positive (1.5 to 2.0)            │
          │      ├─ Positive (0.5 to 1.5)                 │
          │      ├─ Neutral (-0.5 to 0.5)                 │
          │      ├─ Negative (-1.5 to -0.5)               │
          │      └─ Very Negative (-2.0 to -1.5)          │
          │                                                 │
          │   3. calculate_distribution()                   │
          │      ├─ Positive %                             │
          │      ├─ Negative %                             │
          │      └─ Neutral %                              │
          │                                                 │
          │   4. calculate_controversy_index()              │
          │      CI = 1 - |pos - neg| / total             │
          │                                                 │
          │   5. calculate_emotional_intensity()            │
          │      EIS = intense_reactions / likes           │
          │                                                 │
          │   Output: Sentiment metrics stored in DB        │
          └─────────────────────────────────────────────────┘
                                      │
                                      ▼

┌──────────────────────────────────────────────────────────────────────────┐
│                    AGGREGATION LAYER (Topic Model)                       │
└──────────────────────────────────────────────────────────────────────────┘

          ┌─────────────────────────────────────────────────┐
          │   TOPIC-LEVEL SENTIMENT ANALYSIS               │
          │   (Rails.cache, expires_in: 2.hours)           │
          │                                                 │
          │   facebook_sentiment_summary()                  │
          │   ├─ Average Sentiment Score                   │
          │   ├─ Sentiment Distribution                    │
          │   │  ├─ Very Positive: X posts (Y%)           │
          │   │  ├─ Positive: X posts (Y%)                │
          │   │  ├─ Neutral: X posts (Y%)                 │
          │   │  ├─ Negative: X posts (Y%)                │
          │   │  └─ Very Negative: X posts (Y%)           │
          │   ├─ Top Positive Posts (5)                    │
          │   ├─ Top Negative Posts (5)                    │
          │   ├─ Controversial Posts (5)                   │
          │   ├─ Sentiment Over Time (time series)        │
          │   └─ Reaction Breakdown                        │
          │                                                 │
          │   facebook_sentiment_trend()                    │
          │   ├─ Recent Score (24h)                        │
          │   ├─ Previous Score (24-48h)                   │
          │   ├─ Change Percent                            │
          │   └─ Trend Direction (↗️ ↘️ →)                │
          └─────────────────────────────────────────────────┘
                                      │
                                      ▼

┌──────────────────────────────────────────────────────────────────────────┐
│                    CONTROLLER LAYER (FacebookTopicController)            │
└──────────────────────────────────────────────────────────────────────────┘

          ┌─────────────────────────────────────────────────┐
          │   load_sentiment_analysis()                     │
          │                                                 │
          │   @sentiment_summary = topic.sentiment_summary  │
          │   @sentiment_distribution = ...                │
          │   @sentiment_over_time = ...                   │
          │   @top_positive_posts = ...                    │
          │   @top_negative_posts = ...                    │
          │   @controversial_posts = ...                   │
          │   @sentiment_trend = ...                       │
          └─────────────────────────────────────────────────┘
                                      │
                                      ▼

┌──────────────────────────────────────────────────────────────────────────┐
│                          VIEW LAYER (ERB)                                │
└──────────────────────────────────────────────────────────────────────────┘

          ┌─────────────────────────────────────────────────┐
          │   SENTIMENT DASHBOARD SECTION                   │
          │                                                 │
          │   ┌─────────────────────────────────────────┐  │
          │   │  📊 Overview Cards                      │  │
          │   │  ├─ Average Sentiment: 1.23 😊          │  │
          │   │  ├─ Trend: +12.5% ↗️                     │  │
          │   │  └─ Controversial: 3 posts              │  │
          │   └─────────────────────────────────────────┘  │
          │                                                 │
          │   ┌─────────────────────────────────────────┐  │
          │   │  📈 Sentiment Over Time (Line Chart)    │  │
          │   │  [Chartkick line_chart]                 │  │
          │   └─────────────────────────────────────────┘  │
          │                                                 │
          │   ┌─────────────────────────────────────────┐  │
          │   │  🥧 Distribution (Pie Chart)            │  │
          │   │  [Chartkick pie_chart]                  │  │
          │   └─────────────────────────────────────────┘  │
          │                                                 │
          │   ┌─────────────────────────────────────────┐  │
          │   │  📊 Reaction Breakdown (Bar Chart)      │  │
          │   │  [Chartkick column_chart]               │  │
          │   └─────────────────────────────────────────┘  │
          │                                                 │
          │   ┌───────────────┬───────────────────────┐  │
          │   │ 😊 Top       │  ☹️ Top Negative      │  │
          │   │  Positive     │   Posts               │  │
          │   │  Posts        │                       │  │
          │   └───────────────┴───────────────────────┘  │
          │                                                 │
          │   ┌─────────────────────────────────────────┐  │
          │   │  ⚖️ Controversial Posts                 │  │
          │   │  [Grid of post cards]                   │  │
          │   └─────────────────────────────────────────┘  │
          └─────────────────────────────────────────────────┘
                                      │
                                      ▼

┌──────────────────────────────────────────────────────────────────────────┐
│                       USER INTERFACE (Browser)                           │
└──────────────────────────────────────────────────────────────────────────┘


═══════════════════════════════════════════════════════════════════════════

                            DATA FLOW DIAGRAM

═══════════════════════════════════════════════════════════════════════════

    Facebook API                     Your Application
         │                                  │
         │  1. Fetch Post                  │
         │  + Reactions                    │
         ├─────────────────────────────────▶
         │                                  │
         │                            ┌─────┴─────┐
         │                            │ Facebook  │
         │                            │  Entry    │
         │                            │  Created  │
         │                            └─────┬─────┘
         │                                  │
         │                            2. before_save
         │                              callback fires
         │                                  │
         │                            ┌─────▼─────┐
         │                            │ Calculate │
         │                            │ Sentiment │
         │                            │  Metrics  │
         │                            └─────┬─────┘
         │                                  │
         │                            3. Store in DB:
         │                               sentiment_score
         │                               sentiment_label
         │                               controversy_index
         │                               etc.
         │                                  │
         │                            ┌─────▼─────┐
         │                            │   Saved   │
         │                            │   to DB   │
         │                            └─────┬─────┘
         │                                  │
    User Visits                             │
    Topic Page                              │
         │                                  │
         ├─────────────────────────────────▶│
         │                                  │
         │                            4. Controller
         │                               load_sentiment
         │                                  │
         │                            ┌─────▼─────┐
         │                            │  Query DB │
         │                            │  Aggregate│
         │                            │   (Cache) │
         │                            └─────┬─────┘
         │                                  │
         │                            5. Render View
         │                               with Charts
         │                                  │
         ◀─────────────────────────────────┤
         │                                  │
    Display                                 │
    Dashboard                               │


═══════════════════════════════════════════════════════════════════════════

                        CALCULATION FLOW (Detailed)

═══════════════════════════════════════════════════════════════════════════

Step 1: Collect Reaction Data
┌─────────────────────────────────┐
│  reactions_like_count = 50      │
│  reactions_love_count = 100     │
│  reactions_haha_count = 30      │
│  reactions_wow_count = 20       │
│  reactions_sad_count = 15       │
│  reactions_angry_count = 10     │
│  reactions_thankful_count = 5   │
│  ───────────────────────────    │
│  reactions_total_count = 230    │
└─────────────────────────────────┘
               │
               ▼
Step 2: Apply Weights
┌─────────────────────────────────┐
│  50 × 0.5  =  25.0             │
│  100 × 2.0 = 200.0             │
│  30 × 1.5  =  45.0             │
│  20 × 1.0  =  20.0             │
│  15 × -1.5 = -22.5             │
│  10 × -2.0 = -20.0             │
│  5 × 2.0   =  10.0             │
│  ───────────────────            │
│  Sum = 257.5                    │
└─────────────────────────────────┘
               │
               ▼
Step 3: Calculate WSS
┌─────────────────────────────────┐
│  WSS = 257.5 / 230              │
│  WSS = 1.12                     │
└─────────────────────────────────┘
               │
               ▼
Step 4: Classify
┌─────────────────────────────────┐
│  1.12 is in range [0.5, 1.5]   │
│  Label: Positive 🙂             │
└─────────────────────────────────┘
               │
               ▼
Step 5: Calculate Distribution
┌─────────────────────────────────┐
│  Positive: 205 / 230 = 89.1%   │
│  (like+love+haha+wow+thankful)  │
│                                 │
│  Negative: 25 / 230 = 10.9%    │
│  (sad+angry)                    │
│                                 │
│  Neutral: 0%                    │
└─────────────────────────────────┘
               │
               ▼
Step 6: Calculate Controversy
┌─────────────────────────────────┐
│  CI = 1 - |205 - 25| / 230     │
│  CI = 1 - 180 / 230             │
│  CI = 1 - 0.78                  │
│  CI = 0.22 (Low controversy)    │
└─────────────────────────────────┘
               │
               ▼
Step 7: Calculate Intensity
┌─────────────────────────────────┐
│  Intense = 100+15+10+20+5=150  │
│  EIS = 150 / 50 = 3.0          │
│  (High emotional intensity)     │
└─────────────────────────────────┘
               │
               ▼
Step 8: Store Results
┌─────────────────────────────────┐
│  sentiment_score = 1.12         │
│  sentiment_label = positive     │
│  sentiment_positive_pct = 89.1  │
│  sentiment_negative_pct = 10.9  │
│  sentiment_neutral_pct = 0.0    │
│  controversy_index = 0.22       │
│  emotional_intensity = 3.0      │
└─────────────────────────────────┘


═══════════════════════════════════════════════════════════════════════════

                          CACHING STRATEGY

═══════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────┐
│                          CACHE LAYERS                                   │
└─────────────────────────────────────────────────────────────────────────┘

Level 1: Database (Persistent)
├─ Individual post sentiment (calculated once at save)
├─ Fast retrieval via indexes
└─ No runtime calculation overhead

Level 2: Rails Cache (2 hours)
├─ Topic-level aggregations
├─ Sentiment over time series
├─ Top posts lists
└─ Cache key: "topic_#{id}_fb_sentiment_#{date}"

Level 3: Action Caching (1 hour)
├─ Full page render
├─ Per user, per topic
└─ Cache key: { topic_id: X, user_id: Y }

Cache Invalidation:
├─ Automatic after 2 hours
├─ Manual: Rails.cache.clear
└─ Per-topic: Rails.cache.delete("topic_#{id}_fb_sentiment")


═══════════════════════════════════════════════════════════════════════════

                          PERFORMANCE METRICS

═══════════════════════════════════════════════════════════════════════════

Without Caching:
├─ Page Load Time: ~3-5 seconds
├─ Database Queries: 20-30 queries
└─ Memory Usage: High

With Caching (Recommended):
├─ Page Load Time: ~200-500ms (first load: ~1s)
├─ Database Queries: 2-5 queries
└─ Memory Usage: Moderate

Database Indexes Added:
├─ sentiment_score (range queries)
├─ sentiment_label (filtering)
└─ posted_at + sentiment_score (time series)

Expected Throughput:
├─ Individual Calculation: <10ms per post
├─ Topic Aggregation: <500ms for 1000 posts
└─ Cache Hit Rate: ~95% (production)


═══════════════════════════════════════════════════════════════════════════

                    BACKGROUND PROCESSING (Optional)

═══════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────┐
│                  Bulk Sentiment Calculation Job                         │
└─────────────────────────────────────────────────────────────────────────┘

    Scheduled Task (Cron)
           │
           ▼
    ┌──────────────────┐
    │ Every 6 hours    │
    │ or               │
    │ When reactions   │
    │ are updated      │
    └────────┬─────────┘
             │
             ▼
    ┌──────────────────┐
    │ Sidekiq/Delayed  │
    │ Job Queue        │
    └────────┬─────────┘
             │
             ▼
    Find posts with changed reactions
             │
             ▼
    Calculate sentiment for each
             │
             ▼
    Update database in batches
             │
             ▼
    Clear relevant caches
             │
             ▼
    Done ✅


═══════════════════════════════════════════════════════════════════════════

                          MONITORING & ALERTS

═══════════════════════════════════════════════════════════════════════════

Metrics to Monitor:
├─ Average sentiment per topic
├─ Sentiment trend velocity
├─ Number of controversial posts
├─ Calculation time
└─ Cache hit rate

Alert Conditions:
├─ Sentiment drop >15% in 24h ⚠️
├─ Controversial posts spike ⚠️
├─ Calculation time >100ms ⚠️
├─ Cache hit rate <80% ⚠️
└─ Negative sentiment >60% ⚠️

Dashboard Integration:
├─ Grafana/Datadog metrics
├─ Slack notifications
├─ Email alerts
└─ Admin dashboard widgets


═══════════════════════════════════════════════════════════════════════════

This architecture provides:
✅ Scalable sentiment analysis
✅ Real-time calculations
✅ Efficient caching
✅ Comprehensive metrics
✅ Production-ready performance
✅ Easy maintenance and monitoring

Ready for implementation! 🚀

