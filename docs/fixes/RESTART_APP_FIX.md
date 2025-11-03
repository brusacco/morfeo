# Quick Fix: Restart Production App

## 🔄 The Issue

Code is deployed but the app is still running the OLD version in memory.

**Evidence:**
- Code is deployed ✅
- But callbacks still show as missing ❌
- This means: App needs to be restarted!

---

## ✅ **Solution: Restart the App**

```bash
# On production server
sudo systemctl restart morfeo-production

# OR if using Passenger
touch /home/rails/morfeo/tmp/restart.txt

# OR if using Puma
sudo systemctl restart puma
```

---

## 🧪 **Verify Restart Worked**

```bash
RAILS_ENV=production bin/rails runner "
puts '=' * 80
puts 'CALLBACK CHECK AFTER RESTART'
puts '=' * 80

if Entry.method_defined?(:sync_topics_from_tags)
  puts '✅ sync_topics_from_tags NOW EXISTS!'
else
  puts '❌ sync_topics_from_tags STILL MISSING'
  puts '   → Code might not be deployed or restart failed'
end

if Entry.method_defined?(:sync_title_topics_from_tags)
  puts '✅ sync_title_topics_from_tags NOW EXISTS!'
else
  puts '❌ sync_title_topics_from_tags STILL MISSING'
end

puts '=' * 80
"
```

---

## 🔄 **Then Re-Run Full Verification**

```bash
RAILS_ENV=production bin/rails runner scripts/verify_autosync.rb
```

Should now show:
```
✅ sync_topics_from_tags exists
✅ sync_title_topics_from_tags exists
```

---

## 📝 **After Restart: Fix the Gap**

New entries created between deployment and restart need to be re-tagged:

```bash
# Re-tag entries from last 24 hours to create associations
RAILS_ENV=production bin/rails runner "
puts 'Fixing entries created since deployment...'

Entry.where('created_at > ?', 24.hours.ago)
     .joins(:taggings)
     .where('taggings.context = ?', 'tags')
     .distinct
     .find_each do |entry|
  
  # Force callback by re-saving
  entry.touch  # Updates updated_at, triggers callbacks
end

puts '✅ Done!'
"
```

Or use the tagger:
```bash
RAILS_ENV=production bin/rails tagger
```

---

## 🎯 **Quick Commands**

```bash
# 1. Restart app
sudo systemctl restart morfeo-production

# 2. Verify
RAILS_ENV=production bin/rails runner "puts Entry.method_defined?(:sync_topics_from_tags) ? '✅ Working!' : '❌ Still broken'"

# 3. Re-run verification
RAILS_ENV=production bin/rails runner scripts/verify_autosync.rb
```

