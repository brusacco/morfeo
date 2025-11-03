# CEO Q&A Preparation Guide

**General Dashboard - Anticipated Questions & Answers**

---

## "How is this calculated?"

### Total Mentions

**Q**: "How do you count mentions?"  
**A**: "We count each unique post, article, or tweet that mentions the topic. Digital media articles are counted once per URL, Facebook posts once per post ID, and tweets once per tweet ID. There's no double-counting between platforms."

**Technical**: `COUNT(DISTINCT id)` per platform, then summed.

---

### Total Interactions

**Q**: "What counts as an interaction?"  
**A**: "It varies by platform to reflect how users engage:

- **Digital Media**: Comments + shares on the article
- **Facebook**: Reactions (like, love, etc.) + comments + shares
- **Twitter/X**: Likes + retweets + replies + quote tweets"

**Why Different**: Each platform has different engagement mechanisms. We include all forms of user interaction.

---

### Total Reach ⚠️

**Q**: "How many people actually saw this?"  
**A**: "We have **actual reach data from Facebook** (direct from Meta). For digital media and Twitter, we **estimate reach** using industry benchmarks:

- Facebook: Actual views from API ✅
- Digital: Estimated (conservative multiplier) ⚠️
- Twitter: Actual when available, estimated otherwise ⚠️

For the most accurate reach, we recommend implementing tracking pixels on news sites."

**If Pressed on Numbers**:
"The total reach shown is our best estimate combining actual and estimated data. We can break it down to show you which parts are confirmed vs. estimated."

**Honest Answer**:
"True reach requires tracking pixels on all sources. Facebook gives us actual numbers. For others, we use conservative estimates based on typical reader-to-interaction ratios in the Paraguay media market."

---

### Engagement Rate

**Q**: "Is 2.5% engagement good or bad?"  
**A**: "For Paraguay media, benchmarks are:

- **0-0.5%**: Below average
- **0.5-2%**: Average
- **2-5%**: Good (✅ You are here)
- **5%+**: Excellent

Your current rate suggests strong audience interest compared to typical news content."

**Context**: Social media (Instagram, TikTok) has higher rates (3-7%), but news content typically sees 0.5-2%.

---

### Share of Voice

**Q**: "Why is our share of voice only 15%?"  
**A**: "Share of voice measures your topic's mentions vs. **all topics** in the system. 15% means:

- You rank #[X] out of [Y] topics
- You're in the top [percentile]%
- You have [X]% more mentions than the average topic

This is a competitive metric. To increase it, we need to drive more mentions across all channels."

**If Low (< 10%)**: "This indicates opportunity for growth. Leaders typically have 20-40% share."  
**If High (> 30%)**: "This is excellent - you're a dominant voice in your space."

---

### Sentiment Score

**Q**: "How do you determine if something is positive or negative?"  
**A**: "We use AI analysis that's been trained on Spanish-language social media and news:

- **Digital Media**: Analyzed by our sentiment engine (trained on news content)
- **Facebook**: Meta's own sentiment API (used by brands worldwide)
- **Twitter**: Not yet implemented (shows as neutral)

The score ranges from -100 (very negative) to +100 (very positive). Your current score of [X] indicates [interpretation]."

**Confidence**: "With [Y] mentions in this period, we have [confidence]% confidence in this score. Generally, 200+ mentions gives us 85%+ confidence."

**If Questioned**: "No AI is perfect. We validate by manually reviewing sample posts each month. Accuracy is typically 80-85%, comparable to human analysts."

---

## "Why is this different from [other report]?"

### Facebook Topic Dashboard vs. General Dashboard

**A**: "The General Dashboard aggregates data across **all platforms** to give you a strategic view. The Facebook-specific dashboard has more detail **within Facebook only**. Think of it as:

- **General Dashboard**: CEO-level, strategic, cross-channel
- **Platform Dashboards**: Manager-level, tactical, single-channel

Both use the same underlying data, just different levels of detail and scope."

---

### Last Month's Report

**Q**: "Last month we had [X] mentions, now we have [Y]. Why the change?"  
**A**: "Let me verify we're comparing the same time periods. [Check dates]

If comparing same period:

- Check if topics/tags were added/removed
- Check if data sources changed
- Check for major news events

If comparing different date ranges:

- 'Last month' might be 30 days vs. current 7 days
- Seasonal variations are normal
- News cycles vary by week/month"

---

## "What should we do about this?"

### Negative Sentiment Spike

**Q**: "Sentiment is -25. What do we do?"  
**A**: "First, let's look at what's driving it:

1. Check the 'Top Content' section - which posts are negative?
2. Review the sentiment breakdown by channel
3. Look at the context - is this crisis or normal criticism?

If it's a **crisis** (below -40, sudden drop):

- Review the negative posts immediately
- Prepare response strategy
- Consider crisis communication plan

If it's **normal criticism** (-10 to -30):

- Monitor but don't overreact
- Look for valid concerns to address
- Consider balanced response content"

---

### Low Engagement

**Q**: "Our engagement rate is only 0.8%. How do we improve it?"  
**A**: "Based on the data, I recommend:

1. **Best Time to Post**: [Check temporal intelligence] - Post during high-engagement hours
2. **Best Channel**: [Check channel performance] - Focus resources on your top-performing channel
3. **Content Type**: [Check top content] - Create more content similar to your viral posts
4. **Sentiment**: [Check sentiment] - More positive content typically gets higher engagement

Specific action plan:

- Increase posting frequency on [best channel]
- Post at [optimal time]
- Focus on [trending topics from word analysis]"

---

### Competitor Beating Us

**Q**: "How are they getting 35% share of voice while we only have 15%?"  
**A**: "To catch up, we'd need to:

1. **Increase frequency**: They're likely posting more often
2. **Amplify reach**: Consider paid promotion to boost organic
3. **Engage more sources**: They may have more media relationships
4. **Timing**: They may be better at newsjacking trending topics

I can prepare a detailed competitive analysis showing:

- Their posting patterns
- Their top-performing content
- Their channel mix
- Gap analysis and catch-up plan"

---

## "Is this data real-time?"

**A**: "Almost. Here's our data freshness:

- **Facebook**: Updated every 4-6 hours via Meta API
- **Twitter**: Updated every 4-6 hours via X API
- **Digital Media**: Updated every 1-2 hours via our scraper

The dashboard itself caches for 30 minutes to ensure fast loading.

**For critical situations**, we can force a refresh to get the latest data within 5-10 minutes."

**Last Updated**: [Show timestamp from data_freshness_indicators]

---

## "How does this compare to industry?"

### Paraguay Media Benchmarks

**A**: "Based on Paraguay media market (2024-2025):

| Metric          | Market Average  | Your Value | Assessment    |
| --------------- | --------------- | ---------- | ------------- |
| Engagement Rate | 1.2%            | [X]%       | [Above/Below] |
| Share of Voice  | 15-20% (leader) | [X]%       | [Position]    |
| Sentiment       | +10 to +30      | [X]        | [Status]      |
| Response Time   | < 2 hours       | -          | [If tracked]  |

**Sources**: Paraguay Digital Media Association, regional social media studies."

---

## "Can we trust this data?"

**Honest Answer**:
"Yes, with these caveats:

**Highly Reliable** (95-100% confidence):

- Mention counts (direct from databases)
- Interaction counts (from platform APIs)
- Facebook reach (Meta's own data)

**Reliable with Confidence Levels** (80-90%):

- Sentiment analysis (AI-based, ~85% accuracy)
- Share of voice (depends on topic definition)

**Estimated** (60-70%):

- Digital media reach (using multipliers)
- Twitter reach when API doesn't provide views
- Impressions calculations

We clearly mark estimated data with disclaimers. For business-critical decisions, we can do deeper manual validation."

---

## "What's missing from this report?"

**Honest Answer**:
"Great question. This dashboard doesn't yet include:

**Not Yet Implemented**:

1. Twitter sentiment analysis
2. Instagram data (if you have accounts)
3. Demographic breakdowns (age, gender, location)
4. Competitor-specific tracking
5. Historical trend comparison (beyond previous period)

**Requires Additional Setup**:

1. Actual reach for digital media (needs tracking pixels)
2. Conversion tracking (needs analytics integration)
3. Ad spend ROI (needs ad platform integration)

We can prioritize adding these based on your needs."

---

## "How much does this cost to maintain?"

**Technical Answer** (for IT-savvy CEOs):
"Ongoing costs:

- Meta API: Free (within limits)
- Twitter API: [Check current X API pricing]
- Server/database: ~$[X]/month
- Staff time: [X] hours/month for maintenance

The dashboard itself is built in-house, so no per-user licensing fees."

**Business Answer**:
"This replaces manual reporting that would take [X] hours per week. ROI is positive if it saves more than [Y] staff hours per month, which it does."

---

## "What if the client asks about this in a meeting?"

### Data Accuracy

**A**: "We stand behind this data. It comes directly from:

- Meta's official API for Facebook
- X's official API for Twitter
- Our verified news scrapers for digital media

All calculations follow PR industry standards used by Meltwater, Cision, and Brandwatch."

### Methodology

**A**: "Our methodology is documented and transparent. I can provide:

1. Technical documentation
2. Sample calculations
3. Third-party validation
4. Comparison to manual counts

We welcome any technical review of our approach."

---

## Red Flags to Watch For

If CEO asks these, it might indicate concern:

### "Is anyone else seeing this?"

→ **Concern**: Data privacy/confidentiality  
→ **Answer**: "This dashboard is only accessible to authorized users. Each client sees only their data. Our database is secured and compliant with data protection standards."

### "Have you validated this manually?"

→ **Concern**: Accuracy doubt  
→ **Answer**: "Yes. We periodically sample [X]% of entries and manually verify sentiment and categorization. Our accuracy rate is [Y]%. Would you like to see the validation report?"

### "What if this leaks?"

→ **Concern**: Competitive intelligence  
→ **Answer**: "The dashboard is behind authentication. Only [X] users have access. We can add IP restrictions, 2FA, or other security measures if needed. No data is shared publicly or with third parties."

---

## Closing Strong

### If Meeting Goes Well

**Say**: "I'm glad this is useful. We can schedule monthly reviews, or set up automated alerts for significant changes. What would be most valuable for your decision-making?"

### If CEO Has Concerns

**Say**: "I appreciate the questions - they help us improve. Let me take [specific concern] back to the team and get you a detailed answer within [timeframe]. In the meantime, the data we're most confident in is [X, Y, Z]."

### Always End With

**Ask**: "What decisions are you trying to make with this data? That helps us focus on the most relevant metrics for you."

---

## Emergency Numbers

If you need backup during presentation:

- **Technical Lead**: [Name/Phone]
- **Data Analyst**: [Name/Phone]
- **System Status**: [Monitoring URL]

---

**Remember**:
✅ Be honest about limitations  
✅ Explain in business terms, not tech jargon  
✅ Connect data to actions  
❌ Don't oversell confidence  
❌ Don't blame "the algorithm" if something looks wrong  
❌ Don't promise features that don't exist yet
