# 🌐 Headless Crawler with Proxy Support

## Overview

The headless crawler now supports **scrape.do proxy** integration, combining:
- ✅ **Full Selenium capabilities** (complex JavaScript, browser APIs)
- ✅ **IP rotation & Cloudflare bypass** (via scrape.do proxy)
- ✅ **Single token** (same `SCRAPE_DO_API_TOKEN` for both crawlers)

This is the **best option** for sites with strong bot protection (like Ñanduti).

---

## 🔐 Setup

### 1. Configure API Token

```bash
# Add to .env file (or use existing one)
SCRAPE_DO_API_TOKEN=ed138ed418924138923ced2b81e04d53
```

The token is shared between:
- `ProxyCrawler` (HTTP requests via API)
- `HeadlessCrawler with proxy` (Selenium via proxy)

### 2. Verify Configuration

```bash
rails console
> ENV['SCRAPE_DO_API_TOKEN']
=> "ed138ed418924138923ced2b81e04d53"
```

---

## 🚀 Usage

### Without Proxy (Default)

```bash
# Standard headless crawler (direct connection)
rake crawler:headless
rake crawler:test[1]
rake crawler:site[134]
```

### With Proxy (Bypass Cloudflare) ⭐

```bash
# All JS sites with proxy
rake crawler:headless_proxy

# Test with 1 site using proxy
rake crawler:test_proxy[1]

# Specific sites with proxy (e.g., Ñanduti)
rake crawler:site_proxy[134]

# Multiple sites with proxy
rake crawler:site_proxy[134,69,76]
```

---

## 🆚 When to Use Proxy?

### Use Proxy When:
- ✅ Site blocks standard headless browser (e.g., Ñanduti)
- ✅ Getting Cloudflare "Checking your browser" loops
- ✅ Need IP rotation for rate limiting
- ✅ Site has aggressive bot detection

### Use Direct (No Proxy) When:
- ✅ Site works fine without proxy
- ✅ Want to save API costs
- ✅ Testing locally in development
- ✅ Site has no bot protection

---

## 📊 How It Works

### Standard Headless Crawler
```
Your Server → Chrome Headless → Website
```

### Headless Crawler with Proxy
```
Your Server → Chrome Headless → scrape.do Proxy → Website
                                  (IP Rotation + Cloudflare Bypass)
```

### Technical Details

**Proxy Configuration (Selenium):**
```ruby
proxy = Selenium::WebDriver::Proxy.new(
  http: "http://TOKEN:@proxy.scrape.do:8080",
  ssl: "http://TOKEN:@proxy.scrape.do:8080"
)
options.proxy = proxy
```

**Chrome Arguments (Anti-detection):**
- `--headless=new` - Latest headless mode
- `--disable-blink-features=AutomationControlled`
- `--user-agent=...` - Realistic user agent
- `--ignore-certificate-errors` - Handle proxy SSL

---

## 💰 Cost Considerations

### scrape.do Pricing
- **Standard Headless**: Free (uses your server)
- **With Proxy**: Charged per request (homepage + each article)

**Example:**
- Site with 50 articles
- Cost = 51 requests (1 homepage + 50 articles)

**Recommendation:**
- Use proxy ONLY for sites that need it
- Configure per-site in `config/schedule.rb`

---

## 🔧 Configuration per Site

You can mix and match crawlers based on site needs:

```ruby
# config/schedule.rb

# Sites without bot protection - direct
every 1.hour do
  rake "crawler:site[76,113,93]"  # SNT, DelPyNews, Megacadena
end

# Sites with Cloudflare - with proxy
every 1.hour do
  rake "crawler:site_proxy[134,69]"  # Ñanduti, Monumental
end
```

---

## 🧪 Testing

### Test Ñanduti (Previously Failed)

**Without proxy (will likely fail):**
```bash
rake crawler:site[134]
```

**With proxy (should work):**
```bash
rake crawler:site_proxy[134]
```

### Compare Output

**Without proxy:**
```
🔍 Link Extraction Debug for Ñanduti:
   Total <a> tags found: 1
   Matching filter: 0
   Sample links:
     - https://www.cloudflare.com/...
⚠️  WARNING: Cloudflare blocking!
```

**With proxy:**
```
🌐 Using scrape.do proxy (proxy.scrape.do:8080)
✓ Browser ready

🔍 Link Extraction Debug for Ñanduti:
   Total <a> tags found: 156
   Matching filter: 45
   
🔗 Found 45 article link(s)
✓ Successfully bypassed Cloudflare!
```

---

## 🐛 Troubleshooting

### Proxy Not Working

**1. Token not set:**
```
⚠️  Warning: SCRAPE_DO_API_TOKEN not set, running without proxy
```

**Solution:**
```bash
export SCRAPE_DO_API_TOKEN=your_token_here
# or add to .env
```

**2. Proxy connection failed:**
```
❌ Failed to configure proxy: connection refused
```

**Solution:**
- Check scrape.do service status
- Verify token is valid
- Check firewall allows port 8080

**3. Still seeing Cloudflare:**
```
🛡️  Cloudflare protection detected!
⏳ Waiting for Cloudflare (max 30s)...
```

**Solution:**
- Proxy is working, just waiting for clearance
- If it clears: ✓ Success
- If it doesn't: Site may require additional config

---

## 📈 Best Practices

### 1. Test First
Always test with 1 site before running all:
```bash
rake crawler:test_proxy[1]
```

### 2. Monitor Costs
Track scrape.do usage dashboard

### 3. Use Selectively
Only use proxy for sites that need it:
- Ñanduti (134) - **Needs proxy**
- Monumental (69) - **Test if needed**
- SNT (76) - **Works without proxy**

### 4. Cache Results
The crawler already implements:
- Batch URL checking (skips existing)
- Daily aggregation stats
- Efficient database queries

### 5. Schedule Smart
```ruby
# Peak hours - frequent updates with proxy
every 30.minutes, at: ['8:00', '8:30', '9:00', ... '18:00'] do
  rake "crawler:site_proxy[134]"  # Important sites
end

# Off-peak - less frequent, no proxy
every 2.hours do
  rake "crawler:site[76,113]"  # Standard sites
end
```

---

## 🎯 Summary

| Feature | Direct Headless | Headless + Proxy |
|---------|----------------|------------------|
| **Speed** | Fast | Medium |
| **Cost** | Free | Pay per request |
| **Cloudflare Bypass** | Limited | Excellent ✅ |
| **IP Rotation** | No | Yes |
| **JavaScript** | Full support | Full support |
| **Best for** | Standard sites | Protected sites |

**Recommendation:**
- Start with direct headless
- Add proxy only for sites that fail
- Monitor costs and effectiveness

---

## 📚 Related Docs

- [Headless Crawler Guide](HEADLESS_CRAWLER_USAGE.md)
- [Proxy Crawler Setup](../PROXY_CRAWLER_SETUP.md)
- [Configuration Guide](../../config/schedule.rb)

---

**Last Updated:** November 11, 2025  
**Version:** 1.0  
**Requires:** `SCRAPE_DO_API_TOKEN` environment variable

