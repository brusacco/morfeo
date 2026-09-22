---
type: Architecture
title: Twitter Account Management
description: Multi-account Twitter API authentication with automatic rate limit rotation
tags: [twitter, accounts, rotation, rate-limit, authentication]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Morfeo uses a multi-account Twitter API authentication system with automatic rate limit rotation to ensure continuous Twitter data collection without downtime. The system manages up to 5 Twitter accounts and automatically switches between them when rate limits are encountered.

# Architecture

## Account Manager Service

**Location**: `app/services/twitter_services/account_manager.rb`

The `TwitterServices::AccountManager` is the centralized manager for Twitter API authentication with automatic account rotation.

### Key Features

- **Multi-account support**: Manages up to 5 Twitter accounts
- **Automatic rotation**: Switches accounts when rate limits are hit
- **Cooldown tracking**: Uses Redis to track rate limit cooldowns (15 minutes)
- **Smart selection**: Always selects the account with the least cooldown remaining
- **Retry logic**: Automatically retries requests with different accounts

### Account Configuration

Accounts are configured via environment variables:

```bash
# Primary account (required)
TWITTER_AUTH_TOKEN="auth_token_value"
TWITTER_CT0_TOKEN="ct0_token_value"

# Secondary account (recommended)
TWITTER_AUTH_TOKEN2="auth_token_value"
TWITTER_CT0_TOKEN2="ct0_token_value"

# Tertiary account (optional)
TWITTER_AUTH_TOKEN3="auth_token_value"
TWITTER_CT0_TOKEN3="ct0_token_value"

# Additional accounts (up to 5)
TWITTER_AUTH_TOKEN4="..."
TWITTER_CT0_TOKEN4="..."
TWITTER_AUTH_TOKEN5="..."
TWITTER_CT0_TOKEN5="..."
```

### Rate Limit Handling

When a rate limit error is detected (HTTP 429 or "Rate limit exceeded" message):

1. The current account is marked as rate limited with a 15-minute cooldown
2. The system automatically switches to the next available account
3. The request is retried with the new account
4. If all accounts are rate limited, the account with the least cooldown remaining is used

### Redis Cache Keys

- `twitter_account_manager:rate_limited:account_{index}` - Rate limit status
- `twitter_account_manager:cooldown_until:account_{index}` - Cooldown expiration timestamp

# Rake Tasks

## Status Check

```bash
rake twitter:accounts:status
```

Shows the status of all configured Twitter accounts, including rate limit status and remaining cooldown time.

## Environment Verification

```bash
rake twitter:accounts:verify_env
```

Verifies that all required environment variables are configured correctly.

## Rotation Testing

```bash
rake twitter:accounts:test_rotation
```

Tests the account rotation mechanism by simulating rate limit scenarios.

## Clear Cooldowns

```bash
rake twitter:accounts:clear_cooldowns
```

Clears all rate limit cooldowns (useful after renewing tokens or for testing).

# Integration with Twitter Services

The AccountManager is integrated into the Twitter data collection services:

## GetPostsDataAuth

**Location**: `app/services/twitter_services/get_posts_data_auth.rb`

Uses the AccountManager for authenticated Twitter API calls with automatic rotation:

```ruby
@account_manager = TwitterServices::AccountManager.new

# Get credentials for next request
credentials = @account_manager.get_next_account_credentials

# Make API request with credentials
response = make_twitter_api_request(credentials)

# Handle rate limit errors
if TwitterServices::AccountManager.rate_limit_error?(error_message)
  @account_manager.mark_account_rate_limited(credentials[:index])
  # Retry with next account
end
```

## ProcessPosts

The `TwitterServices::ProcessPosts` service automatically uses the authenticated API when credentials are present, falling back to the guest token API if no credentials are found.

# Monitoring

## Log Messages

The system logs detailed information about account usage and rotation:

- `[TwitterAccountManager] Using Account 1 (Primary) (not rate limited)`
- `[TwitterAccountManager] Account 1 marked as RATE LIMITED until 15:45:00`
- `[TwitterAccountManager] Switching to Account 2 (Secondary)`
- `[TwitterServices::GetPostsDataAuth] Rotating to Account 2 (Secondary)`
- `[TwitterServices::GetPostsDataAuth] Request succeeded with Account 2`

## Real-time Monitoring

```bash
tail -f log/development.log | grep -E "Twitter|Rate|Account"
```

# Best Practices

1. **Use 3+ accounts**: With 3 accounts, it's very unlikely all will be rate limited simultaneously
2. **Different accounts**: Use different Twitter accounts for each slot (not the same account multiple times)
3. **Regular token refresh**: Twitter session cookies expire periodically (30-90 days)
4. **Monitor logs**: Watch for rate limit warnings to detect issues early
5. **Test rotation**: Periodically run `rake twitter:accounts:test_rotation` to verify the system works

# Related

- [Twitter Reports](twitter_reports/) - Twitter analytics dashboard infrastructure
- [Twitter Services](twitter_reports/twitter_services.md) - Twitter API integration services
- [Social Media Integration](business_rules/social_media_integration.md) - Twitter integration business rules
