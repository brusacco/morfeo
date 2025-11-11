# 🚀 Proxy Crawler - Quick Setup Guide

## 🎯 What Is This?

The proxy crawler scrapes JavaScript-heavy websites using **scrape.do** proxy service instead of Selenium. It's faster for simple sites that don't require complex browser interactions.

---

## 🔐 Step 1: Configure API Token (REQUIRED)

### Option A: Environment Variable (Recommended) ⭐

```bash
# For development: Add to .env file
SCRAPE_DO_API_TOKEN=ed138ed418924138923ced2b81e04d53

# For production: Export in shell or add to server environment
export SCRAPE_DO_API_TOKEN=ed138ed418924138923ced2b81e04d53
```

### Option B: Rails Credentials (Alternative)

```bash
# Edit encrypted credentials
EDITOR="nano" rails credentials:edit
```

Add this to the file:
```yaml
scrape_do:
  api_token: ed138ed418924138923ced2b81e04d53
```

### Option C: Development Mode (Automatic Fallback)

If you're in development mode and haven't set up A or B, it will use the hardcoded token automatically.

**Note:** The token is read in this priority order:
1. `ENV['SCRAPE_DO_API_TOKEN']` (recommended)
2. `Rails.application.credentials` (if ENV not set)
3. Hardcoded (development only)

---

## 🚀 Step 2: Run the Crawler

### Test with 1 site first:

```bash
rake crawler:proxy_test[1]
```

### Run on all JS sites:

```bash
rake crawler:proxy
```

### Run on specific sites:

```bash
# Single site
rake crawler:proxy_site[76]

# Multiple sites
rake crawler:proxy_site[76,113,93]
```

### Legacy command (still works):

```bash
rake proxy_crawler
```

---

## 📊 What You'll See

```
🚀 Starting Proxy Crawler...
================================================================================

📋 Found 6 site(s) to process:
   1. SNT (ID: 76)
   2. DelPyNews (ID: 113)
   ...

🌐 Initializing proxy client (scrape.do)...
✓ Proxy client ready

╔══════════════════════════════════════════════════════════════════════════════╗
║ SITE 1/6:                          SNT                                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

Processing site: SNT (https://www.snt.com.py/) [ID: 76]
================================================================================

🌐 Fetching homepage via proxy...
✓ Homepage fetched (HTTP 200)

🔍 Link Extraction Debug for SNT:
   Total <a> tags found: 122
   With href attribute: 122
   Matching filter: 39
🔗 Found 39 article link(s)

📊 Quick Analysis:
   Total links: 39
   Already in DB: 37 (will skip)
   New to process: 2

   [1/39] https://www.snt.com.py/noticia/... ✓
   [15/39] https://www.snt.com.py/noticia/... ✓

================================================================================
SUMMARY for SNT
================================================================================
Total links found:    39
New entries created:  2
Existing entries:     37
Failed entries:       0
================================================================================

╔══════════════════════════════════════════════════════════════════════════════╗
║                            OVERALL SUMMARY                                   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ Duration:             2m 45s                                                 ║
║ Sites processed:      6                                                      ║
║ Sites failed:         0                                                      ║
║ Total new entries:    8                                                      ║
║ Total existing:       186                                                    ║
║ Total failed:         2                                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

✅ Crawler completed successfully!
```

---

## 🔍 Verify It Worked

### Check Database

```ruby
# Rails console
Entry.where('created_at > ?', 1.hour.ago).count
# Should show new entries
```

### Check Logs

```bash
tail -f log/production.log | grep "ProxyCrawler"
```

---

## 🆚 Proxy vs Headless Crawler

| Feature | Proxy Crawler | Headless Crawler |
|---------|---------------|------------------|
| **Technology** | scrape.do API | Selenium + Chrome |
| **Speed** | Faster | Slower |
| **Cost** | API charges | Server resources |
| **JavaScript** | Basic support | Full support |
| **Cloudflare** | Handled by proxy | May get blocked |
| **Best for** | Simple sites | Complex sites |

### When to Use Which?

**Use Proxy Crawler when:**
- ✅ Site has basic JavaScript
- ✅ Want faster crawling
- ✅ Don't mind API costs
- ✅ Cloudflare protection is strong

**Use Headless Crawler when:**
- ✅ Site has complex JavaScript
- ✅ Need full browser features
- ✅ Want to avoid API costs
- ✅ Have good server resources

---

## ⚙️ Schedule (Cron)

Add to `config/schedule.rb`:

```ruby
# Run proxy crawler every 2 hours
every 2.hours do
  rake "crawler:proxy"
end

# Or alternate with headless crawler
every 1.hour do
  rake "crawler:headless"  # Hour 0, 1, 2...
end

every 2.hours, at: 30 do
  rake "crawler:proxy"     # Hour 0:30, 2:30, 4:30...
end
```

Update crontab:
```bash
bundle exec whenever --update-crontab
```

---

## 🐛 Troubleshooting

### Error: "Scrape.do API token not found"

**Solution**: Set up API token (see Step 1 above)

### Error: "Proxy request failed after 3 attempts"

**Possible causes:**
- Website is down
- Proxy service is having issues
- API token is invalid
- Network connectivity problems

**Solutions:**
1. Check if website loads in browser
2. Verify API token is correct
3. Check scrape.do service status
4. Try again later

### No Links Found

**Check:**
1. Is the site filter correct? (ActiveAdmin → Sites → Edit)
2. Does the site actually have matching URLs?
3. Run with debug output to see sample links

---

## 💡 Pro Tips

### 1. Test Before Production

Always test with 1 site first:
```bash
rake crawler:proxy_test[1]
```

### 2. Monitor Costs

Scrape.do charges per request. Monitor usage:
- Each homepage fetch = 1 request
- Each article fetch = 1 request
- Site with 20 articles = 21 requests

### 3. Combine with Headless

Use both crawlers for different sites:
- Proxy crawler for simple sites (faster, costs money)
- Headless crawler for complex sites (slower, free)

### 4. Check API Limits

Monitor your scrape.do API limits and usage to avoid hitting caps.

---

## 📚 Related Documentation

- **Technical Details**: `docs/refactoring/PROXY_CRAWLER_REFACTOR.md`
- **Headless Crawler**: `docs/guides/HEADLESS_CRAWLER_USAGE.md`
- **Site Configuration**: ActiveAdmin → Sites

---

**Status**: ✅ Production Ready  
**Last Updated**: November 11, 2025  
**Requires**: scrape.do API token

