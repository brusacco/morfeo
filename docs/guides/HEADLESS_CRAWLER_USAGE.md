# Headless Crawler - Usage Guide

## 🚀 Quick Start

### Basic Usage

```bash
# Crawl all JavaScript-enabled sites
rake crawler:headless

# Test with single site first (recommended)
rake crawler:headless:test[1]

# Crawl specific site(s) by ID
rake crawler:headless:site[76]
rake crawler:headless:site[76,45,23]

# Test with first 5 sites
rake crawler:headless:test[5]

# Backward compatible (old task name)
rake headless_crawler
```

---

## 📋 Task Options

### 1. Full Crawl - `crawler:headless`

Processes all enabled sites with `is_js: true`, ordered by `total_count` (descending).

```bash
rake crawler:headless
```

**Use when**: Running scheduled production crawls.

**Output**: Comprehensive logs for all sites with overall summary.

---

### 2. Test Mode - `crawler:headless:test[N]`

Processes only the first N sites (for testing).

```bash
# Test with 1 site
rake crawler:headless:test[1]

# Test with 5 sites
rake crawler:headless:test[5]
```

**Use when**:

- Testing after deployment
- Debugging issues
- Validating configuration changes

---

### 3. Specific Sites - `crawler:headless:site[IDs]`

Processes only specified site IDs (comma-separated).

```bash
# Single site
rake crawler:headless:site[76]

# Multiple sites
rake crawler:headless:site[76,45,23,67]
```

**Use when**:

- Targeting problematic sites
- Re-crawling specific publishers
- Testing site-specific fixes

**How to find site IDs**:

```ruby
# Rails console
Site.enabled.where(is_js: true).pluck(:id, :name)
# => [[76, "SNT"], [45, "ABC Color"], ...]
```

---

## 📊 Understanding the Output

### Console Output

```bash
🚀 Starting Headless Crawler...
================================================================================

╔══════════════════════════════════════════════════════════════════════════════╗
║ SITE 1/3:                          SNT                                       ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Per-Site Processing

```
================================================================================
Processing site: SNT (https://www.snt.com.py/) [ID: 76]
================================================================================
Found 15 article links
────────────────────────────────────────────────────────────────────────────────
Processing article 1/15: https://www.snt.com.py/articulo/123
✓ New entry created
────────────────────────────────────────────────────────────────────────────────
Processing article 2/15: https://www.snt.com.py/articulo/124
○ Entry already exists
────────────────────────────────────────────────────────────────────────────────
Processing article 3/15: https://www.snt.com.py/articulo/125
✗ Failed to process entry: Date extraction failed
────────────────────────────────────────────────────────────────────────────────
```

**Symbols**:

- `✓` - New entry created successfully
- `○` - Entry already exists (skipped)
- `✗` - Processing failed (see logs)

### Per-Site Summary

```
================================================================================
SUMMARY for SNT
================================================================================
Total links found:    15
New entries created:  10
Existing entries:     3
Failed entries:       2

ERRORS:
  - https://www.snt.com.py/articulo/125: Date extraction failed
  - https://www.snt.com.py/articulo/130: Navigation timeout
================================================================================
```

### Overall Summary

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                            OVERALL SUMMARY                                   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ Duration:             5m 32s                                                 ║
║ Sites processed:      3                                                      ║
║ Sites failed:         0                                                      ║
║ Total new entries:    24                                                     ║
║ Total existing:       12                                                     ║
║ Total failed:         3                                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

✅ Crawler completed successfully!
```

---

## 🔍 Checking Results

### Database Verification

```ruby
# Rails console

# Check recent entries
Entry.where('created_at > ?', 1.hour.ago).count

# Check entries by site
site = Site.find(76)
site.entries.where('created_at > ?', 1.hour.ago).count

# Check entries with tags
Entry.tagged_with(['santiago peña'], any: true).where('created_at > ?', 1.hour.ago)
```

### Log Review

```bash
# Production logs
tail -f log/production.log | grep "HeadlessCrawler"

# Check for errors
grep "ERROR" log/production.log | grep "HeadlessCrawler"

# Check statistics
grep "SUMMARY" log/production.log
```

---

## ⚙️ Configuration

### Timeout Settings

Located in `app/services/headless_crawler_services/browser_manager.rb`:

```ruby
PAGE_LOAD_TIMEOUT = 30      # Page load timeout (seconds)
SCRIPT_TIMEOUT = 30         # JavaScript execution timeout (seconds)
IMPLICIT_WAIT = 5           # Element finding wait (seconds)
STABILIZATION_WAIT = 3      # Page stabilization wait (seconds)
```

**To modify**: Edit the constants and redeploy.

### Retry Configuration

Located in `app/services/headless_crawler_services/browser_manager.rb`:

```ruby
def self.navigate_to(driver, url, retries: 3)
  # Retries: 3 attempts with exponential backoff (2s, 4s, 8s)
end
```

### Site Processing Order

Sites are processed in descending order by `total_count`:

```ruby
# In Orchestrator
sites = Site.enabled.where(is_js: true).order(total_count: :desc)
```

**Rationale**: Process most popular sites first for maximum impact.

---

## 🔧 Troubleshooting

### Issue: "Net::ReadTimeout" Error

**Symptoms**: Task fails with timeout error.

**Solutions**:

1. Check if site is accessible: `curl -I https://site.com`
2. Increase timeout in `BrowserManager`:
   ```ruby
   PAGE_LOAD_TIMEOUT = 60  # Increase to 60 seconds
   ```
3. Skip problematic site temporarily
4. Contact site administrator if persistent

---

### Issue: No Links Extracted

**Symptoms**: "Found 0 article links" in logs.

**Causes**:

1. Invalid site filter regex
2. Site structure changed
3. JavaScript rendering issue

**Debug**:

```ruby
# Rails console
site = Site.find(76)
site.filter  # Check regex pattern
```

**Solutions**:

1. Update site filter in ActiveAdmin
2. Test regex: `"https://site.com/articulo/123".match?(/#{site.filter}/)`
3. Check if site requires authentication

---

### Issue: High Failure Rate

**Symptoms**: Many "✗ Failed to process entry" messages.

**Causes**:

1. Site structure changed
2. Content extraction selectors outdated
3. Date format changed

**Debug**:

```ruby
# Check recent failed entries
Entry.where(published_at: nil).where('created_at > ?', 1.day.ago)
```

**Solutions**:

1. Update content filters in ActiveAdmin
2. Check site's HTML structure
3. Update date extraction patterns

---

### Issue: Chrome Process Not Closing

**Symptoms**: Multiple Chrome processes in memory.

**Check**:

```bash
ps aux | grep chrome
```

**Solutions**:

1. Service automatically cleans up with `ensure` blocks
2. Manual cleanup: `pkill -f chrome`
3. Check logs for uncaught exceptions

---

## 📅 Scheduling

### Cron Setup (via Whenever gem)

Add to `config/schedule.rb`:

```ruby
# Run every hour
every 1.hour do
  rake "crawler:headless"
end

# Run every 2 hours
every 2.hours do
  rake "crawler:headless"
end

# Run at specific times
every :day, at: '2:00am' do
  rake "crawler:headless"
end

# Run on weekdays only
every :weekday, at: '6:00am' do
  rake "crawler:headless"
end
```

**Update crontab**:

```bash
# Generate new crontab
bundle exec whenever --update-crontab

# View current crontab
bundle exec whenever
```

---

## 🚦 Production Best Practices

### 1. Start with Test Mode

Always test with a single site first:

```bash
# Staging
RAILS_ENV=staging rake crawler:headless:test[1]

# Production (after staging success)
rake crawler:headless:test[1]
```

### 2. Monitor First Full Run

```bash
# In one terminal: tail logs
tail -f log/production.log | grep "Crawler"

# In another terminal: run crawler
rake crawler:headless
```

### 3. Handle Failures Gracefully

Service automatically:

- ✅ Retries failed navigations (3 attempts)
- ✅ Continues to next article on failure
- ✅ Continues to next site on critical failure
- ✅ Logs all errors for review

### 4. Review Logs Regularly

```bash
# Daily review
grep "OVERALL SUMMARY" log/production.log | tail -5

# Check error trends
grep "Failed entries:" log/production.log | tail -10
```

### 5. Update Site Configurations

If a site consistently fails:

1. Check site in browser
2. Update filter/selectors in ActiveAdmin
3. Test with `rake crawler:headless:site[SITE_ID]`
4. Re-enable in full crawl

---

## 🎯 Performance Optimization

### Current Performance

- **Per site**: ~2 minutes (with 20 articles)
- **Per article**: ~3-4 seconds
- **Database**: 2 updates per entry (optimized from 5)

### For Large Scale

If processing > 50 sites, consider:

1. **Sidekiq Background Jobs**

   ```ruby
   # Process sites in parallel
   Site.enabled.where(is_js: true).find_each do |site|
     HeadlessCrawlerJob.perform_later(site.id)
   end
   ```

2. **Distributed Crawling**

   - Multiple worker servers
   - Each processes subset of sites

3. **Browser Instance Pooling**
   - Reuse browser across sites
   - Reduce initialization overhead

---

## 📞 Support

### Getting Help

1. **Check logs**: `log/production.log`
2. **Review this guide**: Common issues covered above
3. **Check code documentation**: Inline comments in service files
4. **Rails console**: Debug specific sites/entries

### Reporting Issues

Include in report:

- Task command used
- Full error message
- Site ID and name
- Recent log entries
- Steps to reproduce

---

## 📚 Related Documentation

- **Technical Details**: `/docs/refactoring/HEADLESS_CRAWLER_REFACTOR.md`
- **Code Review**: `/docs/reviews/HEADLESS_CRAWLER_CODE_REVIEW.md`
- **Site Management**: `/docs/guides/SITE_CONFIGURATION.md` (if exists)

---

**Last Updated**: November 11, 2025  
**Version**: 2.0 (Refactored)  
**Status**: Production Ready
