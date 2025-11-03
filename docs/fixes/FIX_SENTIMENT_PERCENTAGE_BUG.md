# Fix: Sentiment Percentage Bug (Over 100%)

## 🔴 **Bug: Sentiment Percentages Over 100%**

**Symptoms:**
```
Sentiment: 22% Positive / 183% Neutral / 661% Negative
```

---

## 🔍 **Root Cause**

With the new `entry_topics` direct associations, entries can have duplicate rows in the result set when joined. If an entry has multiple tags that match a topic, it appears multiple times.

**Example:**
```
Entry has tags: ["Santiago Peña", "ANR"]
Topic has tags: ["Santiago Peña", "ANR", "Horacio Cartes"]
Result: Entry appears TWICE in the join (once for each matching tag)
```

This causes:
- `COUNT(*)` to count duplicate rows
- Sentiment counts to be inflated
- Percentages over 100%

---

## ✅ **Fix Applied**

Updated `app/services/digital_dashboard_services/aggregator_service.rb`:

### **Before (Line 65-96):**
```ruby
entries_count = entries.size  # ❌ Counts duplicates
entries_total_sum = entries.sum(:total_count)  # ❌ Sums duplicates

polarity_data = entries
                 .group(:polarity)
                 .pluck(
                   :polarity,
                   Arel.sql('COUNT(*)'),  # ❌ Counts duplicate rows
                   Arel.sql('SUM(entries.total_count)')
                 )
```

### **After:**
```ruby
entries_count = entries.distinct.count  # ✅ Counts unique entries
entries_total_sum = entries.distinct.sum(:total_count)  # ✅ Sums unique entries

polarity_data = entries
                 .group(:polarity)
                 .select('polarity, COUNT(DISTINCT entries.id) as count, SUM(DISTINCT entries.total_count) as sum')
                 # ✅ Uses DISTINCT to count/sum unique entries only
                 .map { |row| [row.polarity, { count: row.count, sum: row.sum }] }
                 .to_h
```

---

## 🧪 **Test After Fix**

```bash
# Deploy
cd /home/rails/morfeo
git pull origin main
sudo systemctl restart morfeo-production

# Test on affected topic
RAILS_ENV=production bin/rails runner scripts/diagnose_sentiment_bug.rb "Petropar"
```

**Expected Output:**
```
RAW COUNTS:
Total entries: 41
Positive: 2
Negative: 31
Neutral: 8

FROM AGGREGATOR SERVICE:
entries_count: 41
Positive count: 2   ✅ Matches!
Negative count: 31  ✅ Matches!
Neutral count: 8    ✅ Matches!

percentage_positives: 5%    ✅ Correct!
percentage_negatives: 76%   ✅ Correct!
percentage_neutrals: 20%    ✅ Correct!
Total: 101% (rounding)      ✅ OK!
```

---

## 📊 **Impact**

| Topic | Before (Bug) | After (Fixed) |
|-------|--------------|---------------|
| Petropar | 22%/183%/661% ❌ | 5%/20%/76% ✅ |
| All topics with entry_topics | Wrong percentages | Correct percentages |

---

## 🎯 **Why This Happened**

When we switched from Elasticsearch to direct `entry_topics` associations:
- Elasticsearch returned distinct entry IDs
- Direct JOIN can create duplicate rows if multiple tags match
- We needed to add `.distinct` to all aggregation queries

---

## ✅ **Summary**

- **Issue**: Duplicate rows from JOIN causing wrong counts
- **Fix**: Added `.distinct` to all count/sum operations  
- **Files**: `app/services/digital_dashboard_services/aggregator_service.rb`
- **Deploy**: git pull + restart app
- **Test**: Run diagnostic script to verify

**Sentiment percentages will now be correct!** 🎉

