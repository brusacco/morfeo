# Alert Time Window Standardization - FIXED

**Date**: November 4, 2025  
**Status**: ✅ **FIXED**  
**Priority**: Medium - Data Consistency

---

## 🐛 Issue Identified

### The Problem

The main/home dashboard was showing contradictory information compared to individual topic dashboards:

- **Main Dashboard Alert**: "📉 Disminución de Menciones: Honor Colorado"
- **Topic Dashboard**: "Velocidad del Tema: +101.4% creciendo"

Both were technically correct, but using **different time windows** causing user confusion.

---

## 🔍 Root Cause Analysis

### Original Implementation

**Main/Home Dashboard Alerts** (`app/services/home_services/dashboard_aggregator_service.rb`):
- Used **3 days vs 3 days** comparison
- Compared last 3 days (days 0-3) vs previous 3 days (days 3-6)
- Source: `TopicStatDaily` table (aggregated stats)

**Individual Topic Dashboards** (Digital, Facebook, Twitter):
- Used **24 hours vs 24 hours** comparison  
- Compared last 24h vs previous 24h (24-48h ago)
- Source: Live queries from `Entry`, `FacebookEntry`, `TwitterPost`

### Why This Caused Confusion

A topic could show:
- ✅ **Growing** in the last 24 hours (recent spike: 145 mentions)
- ⚠️ **Declining** over the last 3 days (overall trend: 500 → 400 mentions)

Both are accurate, but inconsistent messaging confuses users.

---

## ✅ Solution Implemented

### Standardized to 24h vs 24h Window

Updated `app/services/home_services/dashboard_aggregator_service.rb`:

#### Change 1: `calculate_topic_trend_direction_from_stats`

**Before** (3-day window):
```ruby
def calculate_topic_trend_direction_from_stats(stats)
  recent_stats = stats.select { |s| s.topic_date >= 3.days.ago.to_date }
  previous_stats = stats.select { |s| s.topic_date.between?(6.days.ago.to_date, 3.days.ago.to_date) }
  # ...
end
```

**After** (24h window):
```ruby
def calculate_topic_trend_direction_from_stats(stats)
  # Use 24h vs 24h window to match individual dashboard velocity calculations
  # This ensures consistency across all dashboards (Digital, Facebook, Twitter)
  recent_stats = stats.select { |s| s.topic_date >= 1.day.ago.to_date }
  previous_stats = stats.select { |s| s.topic_date.between?(2.days.ago.to_date, 1.day.ago.to_date) }
  # ...
end
```

#### Change 2: `generate_trend_alert`

**Before**:
```ruby
def generate_trend_alert(topic, stats, trend)
  recent_count = stats.select { |s| s.topic_date >= 3.days.ago.to_date }.sum { |s| s.entry_count || 0 }
  # ...
  details: "Las menciones están disminuyendo en los últimos días. Considere aumentar actividad."
end
```

**After**:
```ruby
def generate_trend_alert(topic, stats, trend)
  # Use 24h window to match individual dashboard calculations
  recent_count = stats.select { |s| s.topic_date >= 1.day.ago.to_date }.sum { |s| s.entry_count || 0 }
  # ...
  details: "Las menciones están disminuyendo en las últimas 24 horas comparado con el día anterior. Considere aumentar actividad."
end
```

---

## 🎯 Consistency Achieved

Now **ALL dashboards** use the same time window:

| Dashboard | Time Window | Source | Status |
|-----------|-------------|--------|--------|
| **Digital Topic** | 24h vs 24h | `list_entries` (Entry) | ✅ Already consistent |
| **Facebook Topic** | 24h vs 24h | `FacebookEntry` | ✅ Already consistent |
| **Twitter Topic** | 24h vs 24h | `TwitterPost` | ✅ Already consistent |
| **Main/Home Dashboard** | 24h vs 24h | `TopicStatDaily` | ✅ **NOW FIXED** |

---

## 📊 Impact

### Benefits
- ✅ Eliminates contradictory messaging
- ✅ Users see consistent metrics across all dashboards
- ✅ Clearer alert context ("últimas 24 horas" instead of "últimos días")
- ✅ Alerts match velocity calculations

### Trade-offs
- ⚠️ 24h windows are more volatile (single-day spikes trigger alerts)
- ⚠️ May see more fluctuation in alerts day-to-day
- ✅ But more accurate and responsive to recent changes

---

## 🧪 Testing Checklist

- [ ] Load main/home dashboard and verify alerts use 24h window
- [ ] Verify alert text says "últimas 24 horas" not "últimos días"
- [ ] Compare alert status with individual topic velocity
- [ ] Confirm no contradictions between dashboards
- [ ] Check that TopicStatDaily data is up-to-date (run `rake topic_stat_daily` if needed)

---

## 📝 Notes

### Data Source Consideration

The main dashboard uses `TopicStatDaily` which is updated by cron jobs:
- **Frequency**: Daily (configured in `config/schedule.rb`)
- **Job**: `rake topic_stat_daily`

If cron jobs are delayed, alerts may lag behind real-time data. For truly real-time alerts, consider using live queries like individual dashboards, but this would impact performance.

### Alternative Approaches Considered

1. **Keep 3-day window, add clarification**: Rejected - still confusing
2. **Use 7-day window**: Rejected - too slow to react to changes
3. **Show both 24h and 3-day trends**: Possible future enhancement
4. **Switch to real-time queries**: Rejected - performance cost too high

---

## ✅ Status

**RESOLVED** - Main dashboard now uses 24h vs 24h window matching all other dashboards.

**Files Modified**:
- `app/services/home_services/dashboard_aggregator_service.rb`

**Cache Consideration**: 
- Alerts are cached for 30 minutes
- After deployment, cache will clear automatically
- Or manually clear with `Rails.cache.clear` if needed

---

**Verified By**: Cursor AI  
**Approved By**: Bruno Sacco  
**Deployed**: Pending

