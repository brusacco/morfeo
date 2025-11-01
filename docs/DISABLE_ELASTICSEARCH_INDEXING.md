# Fix: Disable Elasticsearch Indexing

## 🔴 **Issue**

After stopping Elasticsearch, the tagger fails with:
```
Failed to open TCP connection to localhost:9200 (Connection refused - connect(2) for "localhost" port 9200)
```

**Root Cause**: Entry model still has `searchkick` callbacks trying to update Elasticsearch on every save.

---

## ✅ **Solution Applied**

Changed `app/models/entry.rb` line 4:

**Before:**
```ruby
searchkick
```

**After:**
```ruby
searchkick callbacks: false
```

This disables automatic Elasticsearch indexing while keeping the searchkick configuration for potential future use.

---

## 🚀 **Deploy the Fix**

```bash
# On production server
cd /home/rails/morfeo
git pull origin main
sudo systemctl restart morfeo-production

# Verify restart
RAILS_ENV=production bin/rails runner "puts '✅ App restarted'"
```

---

## 🧪 **Test the Tagger**

After deploying and restarting:

```bash
# Run tagger on last 7 days
RAILS_ENV=production bin/rails tagger
```

**Expected**: 
- ✅ No Elasticsearch connection errors
- ✅ Entries get re-tagged successfully
- ✅ Associations are created automatically

---

## 📊 **Verify Auto-Sync Works**

After running tagger:

```bash
RAILS_ENV=production bin/rails runner scripts/verify_autosync.rb
```

Should show:
```
✅ sync_topics_from_tags exists
✅ sync_title_topics_from_tags exists
✅ Recent entries have associations
```

---

## 🎯 **What This Fix Does**

| Before | After |
|--------|-------|
| ❌ Entry.save → tries to update ES → fails | ✅ Entry.save → no ES update → succeeds |
| ❌ Tagger fails with connection error | ✅ Tagger works normally |
| ❌ Crawler fails when saving entries | ✅ Crawler works normally |
| ✅ Auto-sync not working (missing callbacks) | ✅ Auto-sync works (after restart) |

---

## 🔮 **Future: Complete Elasticsearch Removal**

Later, we can optionally:

1. **Remove searchkick completely** (Optional - Phase 5)
```ruby
# Remove this line entirely
# searchkick callbacks: false
```

2. **Remove searchkick gem** (Optional)
```ruby
# Gemfile
# gem 'searchkick'  # Remove
```

3. **Remove Elasticsearch queries** (Optional)
- Clean up any remaining ES queries in Topic model
- Remove ES configuration files

**Note**: Since we're using `USE_DIRECT_ENTRY_TOPICS=true` and ES is stopped, these are optional cleanup tasks.

---

## ✅ **Summary**

- **Issue**: searchkick callbacks trying to update stopped Elasticsearch
- **Fix**: Disable callbacks with `searchkick callbacks: false`
- **Impact**: Tagger and crawler will now work without ES errors
- **Deploy**: git pull + restart app
- **Test**: Run tagger to verify

---

**After this fix, the tagger should work without Elasticsearch errors!** 🎯

