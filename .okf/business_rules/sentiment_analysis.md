---
type: Business Rule
title: Sentiment Analysis
description: Sentiment analysis rules by platform
tags: [sentiment, analysis, polarity, emotions]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Morfeo performs sentiment analysis on content to understand public opinion. Different platforms use different approaches based on available data.

# Rules

## Digital Media (Entries)

- Uses OpenAI GPT-5-mini for sentiment analysis
- Polarity enum: neutral(0), positive(1), negative(2)
- Analysis performed on title + description + content snippet (truncated to 500 chars)
- Uses JSON schema response format for structured output
- Results stored in `polarity` field
- Service: `AiServices::SentimentAnalysisService`

## Facebook

- Uses reaction breakdown for sentiment calculation
- Sentiment weights: like(0.5), love(2.0), haha(1.5), wow(1.0), sad(-1.5), angry(-2.0), thankful(2.0)
- Sentiment label enum: very_negative(0), negative(1), neutral(2), positive(3), very_positive(4)
- Calculates controversy index (>60% polarization = controversial)
- Calculates emotional intensity (>50% emotional reactions = high emotion)
- Requires minimum 30 reactions for statistical validity

## Twitter

- No built-in sentiment analysis
- Relies on engagement metrics for performance analysis

## Instagram

- No built-in sentiment analysis
- Relies on engagement metrics for performance analysis

# Topic Sentiment Words

- Topics can define custom positive and negative words
- Used for word cloud coloring and sentiment analysis
- Applied across all platforms for consistent analysis

# Related

- [Entry Model](../models/entry.md) - Entry polarity
- [FacebookEntry Model](../models/facebook_entry.md) - Facebook sentiment
- [Topic Model](../models/topic.md) - Topic sentiment words
