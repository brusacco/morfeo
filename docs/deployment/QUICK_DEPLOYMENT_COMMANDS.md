# Quick Deployment Commands - Phase 3

## 🚀 Fast Production Deployment

### **1. Deploy Code**
```bash
cd /home/rails/morfeo
git pull origin main
bundle install
RAILS_ENV=production bin/rails db:migrate
sudo systemctl restart morfeo-production
```

### **2. Start with Flag OFF (Safe Mode)**
```bash
# Set flag to false (uses Elasticsearch - current behavior)
echo "USE_DIRECT_ENTRY_TOPICS=false" >> .env
sudo systemctl restart morfeo-production

# Test
curl -I https://your-domain.com/topics/1
tail -f log/production.log
```

### **3. Enable New Associations**
```bash
# Switch to direct associations
sed -i 's/USE_DIRECT_ENTRY_TOPICS=false/USE_DIRECT_ENTRY_TOPICS=true/' .env
sudo systemctl restart morfeo-production

# Clear cache
RAILS_ENV=production bin/rails runner "Rails.cache.clear; puts 'Cache cleared!'"

# Test
curl -I https://your-domain.com/topics/1
```

### **4. Quick Performance Test**
```bash
RAILS_ENV=production bin/rails runner "
require 'benchmark'
topic = Topic.first
time = Benchmark.measure { topic.list_entries.to_a }
puts 'Time: ' + (time.real * 1000).round(2).to_s + 'ms'
puts (time.real * 1000 < 250 ? '✅ SUCCESS' : '⚠️ NEEDS TUNING')
"
```

### **5. Monitor Resources**
```bash
# Check memory
free -h

# Check processes
ps aux | grep -E "mysql|java|elastic" | grep -v grep

# Watch logs
tail -f log/production.log | grep -E "Completed|SQL"
```

### **6. Rollback (If Needed)**
```bash
sed -i 's/USE_DIRECT_ENTRY_TOPICS=true/USE_DIRECT_ENTRY_TOPICS=false/' .env
sudo systemctl restart morfeo-production
RAILS_ENV=production bin/rails runner "Rails.cache.clear"
```

---

## 📊 Success Metrics

- ✅ Response time: < 250ms (was 440ms)
- ✅ No SQL errors
- ✅ MySQL memory stable (< 80GB)
- ✅ Elasticsearch no longer queried

---

## 🎯 What Changed

| File | Change |
|------|--------|
| `app/models/topic.rb` | Feature flag to switch between ES and direct associations |
| `app/models/entry.rb` | Auto-sync callbacks for `entry_topics` tables |
| `app/services/digital_dashboard_services/aggregator_service.rb` | Fixed MySQL GROUP BY errors |
| `db/migrate/20251101215140_create_entry_topic_associations.rb` | New join tables |

---

**Last Updated**: November 1, 2025

