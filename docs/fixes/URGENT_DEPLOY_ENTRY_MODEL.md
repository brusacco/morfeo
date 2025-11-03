# 🚨 CRITICAL: Deploy Entry Model to Enable Auto-Sync

## ⚠️ **Issue Found**

The Entry model with auto-sync callbacks is NOT deployed to production!

**Evidence:**
```
❌ sync_topics_from_tags MISSING!
❌ sync_title_topics_from_tags MISSING!
```

**Impact:**
- New entries are getting tagged by crawler
- But NOT getting associated with topics automatically
- Backfill worked (existing entries have associations)
- But new entries need manual re-tagging to get associations

---

## ✅ **Solution: Deploy the Updated Entry Model**

### **Step 1: Verify Local Code Has Callbacks**

Check locally:
```bash
grep -n "after_save :sync_topics_from_tags" app/models/entry.rb
grep -n "after_save :sync_title_topics_from_tags" app/models/entry.rb
grep -n "def sync_topics_from_tags" app/models/entry.rb
grep -n "def sync_title_topics_from_tags" app/models/entry.rb
```

Should show:
- Line 19: `after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?`
- Line 20: `after_save :sync_title_topics_from_tags, if: :saved_change_to_title_tag_list?`
- Method definitions around lines 365-385

---

### **Step 2: Deploy to Production**

```bash
# On production server
cd /home/rails/morfeo

# Pull latest code
git pull origin main

# Restart application
sudo systemctl restart morfeo-production
# OR
touch tmp/restart.txt

# Verify deployment
RAILS_ENV=production bin/rails runner "
if Entry.method_defined?(:sync_topics_from_tags)
  puts '✅ Callbacks deployed successfully!'
else
  puts '❌ Callbacks still missing - restart failed'
end
"
```

---

### **Step 3: Re-Tag Recent Entries (Fix Existing Gap)**

After deploying, re-tag entries created since the last deployment to create missing associations:

```bash
# Re-tag entries from last 24 hours
RAILS_ENV=production bin/rails runner "
puts 'Re-tagging recent entries to create associations...'
count = 0

Entry.where('created_at > ?', 24.hours.ago)
     .where('tag_list IS NOT NULL AND tag_list != \"\"')
     .find_each do |entry|
  
  # This will trigger the callback
  entry.tag_list = entry.tag_list  # Set to itself
  entry.save!  # Triggers sync_topics_from_tags
  
  count += 1
  puts \"Processed: #{count}\" if count % 100 == 0
end

puts \"✅ Re-tagged #{count} entries\"
"
```

Or use the built-in tagger task:
```bash
# This will re-tag last 7 days
RAILS_ENV=production bin/rails tagger
```

---

## 🧪 **Verify Fix Worked**

After deploying and restarting, run verification again:

```bash
RAILS_ENV=production bin/rails runner scripts/verify_autosync.rb
```

Expected output:
```
✅ sync_topics_from_tags exists
✅ sync_title_topics_from_tags exists
```

---

## 📊 **Current Status**

| Item | Status | Notes |
|------|--------|-------|
| **Backfill** | ✅ Complete | 6,226 associations created |
| **Recent entries** | ✅ Working | Entries from backfill period have associations |
| **New entries** | ⚠️ Broken | Created after backfill, no associations |
| **Callbacks** | ❌ Not deployed | Entry model needs to be deployed |
| **Database** | ✅ Ready | Tables and indexes exist |

---

## 🎯 **Action Items**

1. **URGENT**: Deploy Entry model to production (git pull + restart)
2. **Verify**: Check callbacks exist with verification script
3. **Fix gap**: Re-tag entries created in last 24 hours
4. **Monitor**: Watch crawler logs for new entries getting synced

---

## 💡 **Why This Happened**

During Phase 2, we:
1. ✅ Created the migration (deployed)
2. ✅ Created the models (deployed)
3. ✅ Added callbacks to Entry model (NOT deployed yet!)
4. ✅ Ran backfill (worked)
5. ✅ Enabled feature flag (working)
6. ❌ Forgot to restart app after deploying Entry model changes

The app is still running with the OLD Entry model (before callbacks were added)!

---

## 🚀 **Quick Fix Commands**

```bash
# On production server
cd /home/rails/morfeo
git pull origin main
sudo systemctl restart morfeo-production

# Verify
RAILS_ENV=production bin/rails runner "puts Entry.method_defined?(:sync_topics_from_tags) ? '✅ Fixed!' : '❌ Still broken'"

# Re-tag last 24h
RAILS_ENV=production bin/rails tagger
```

---

**This is the missing piece! Once deployed, new entries will automatically get associated with topics.** 🎯

