# Magic Numbers Extracted to Constants ✅

**Date**: November 4, 2025  
**Issue**: Magic numbers scattered throughout Facebook crawler code  
**Priority**: 📊 Medium (Maintainability)  
**Status**: ✅ COMPLETE

---

## 🎯 Issue

### Problem
The Facebook crawler had **magic numbers** hardcoded throughout the code:
- `30` - timeout value
- `10` - connection timeout
- `100` - API page size
- `60` - default wait time
- `[4, 17, 32, 613]` - rate limit error codes
- `[190, 102]` - auth error codes
- `'v8.0'` - API version
- `'https://graph.facebook.com'` - API base URL

**Impact**:
- Hard to understand what numbers mean
- Difficult to change configuration
- No single source of truth
- Poor maintainability

---

## ✅ Solution Implemented

### Constants Extracted

All magic numbers have been extracted to well-named constants at the top of the class:

```ruby
module FacebookServices
  class FanpageCrawler < ApplicationService
    # Reaction types supported by Facebook
    REACTION_TYPES = %w[like love wow haha sad angry thankful].freeze
    
    # API Configuration
    API_VERSION = 'v8.0'
    API_BASE_URL = 'https://graph.facebook.com'
    
    # Timeout settings (in seconds)
    TIMEOUT_SECONDS = 30        # Read timeout: how long to wait for response
    OPEN_TIMEOUT_SECONDS = 10   # Connection timeout: how long to wait for connection
    
    # Pagination
    API_PAGE_SIZE = 100         # Number of posts per API request
    
    # Rate limiting
    DEFAULT_WAIT_TIME = 60      # Default wait time when rate limited (seconds)
    RATE_LIMIT_ERROR_CODES = [4, 17, 32, 613].freeze
    
    # Authentication errors
    AUTH_ERROR_CODES = [190, 102].freeze
  end
end
```

---

## 📊 Constants Breakdown

### 1. **API Configuration**
```ruby
API_VERSION = 'v8.0'
API_BASE_URL = 'https://graph.facebook.com'
```

**Usage**:
```ruby
# Before:
api_url = 'https://graph.facebook.com/v8.0/'

# After:
api_url = "#{API_BASE_URL}/#{API_VERSION}/"
```

**Benefits**:
- ✅ Easy to upgrade API version
- ✅ Clear configuration point
- ✅ Can be overridden for testing

---

### 2. **Timeout Settings**
```ruby
TIMEOUT_SECONDS = 30        # Read timeout
OPEN_TIMEOUT_SECONDS = 10   # Connection timeout
```

**Usage**:
```ruby
# Before:
response = HTTParty.get(
  request,
  timeout: 30,           # What does 30 mean?
  open_timeout: 10       # What does 10 mean?
)

# After:
response = HTTParty.get(
  request,
  timeout: TIMEOUT_SECONDS,
  open_timeout: OPEN_TIMEOUT_SECONDS
)
```

**Benefits**:
- ✅ Self-documenting code
- ✅ Easy to adjust timeouts
- ✅ Consistent across all API calls

---

### 3. **Pagination**
```ruby
API_PAGE_SIZE = 100
```

**Usage**:
```ruby
# Before:
limit = '&limit=100'  # Why 100?

# After:
limit = "&limit=#{API_PAGE_SIZE}"
```

**Benefits**:
- ✅ Clear purpose
- ✅ Easy to change page size
- ✅ Documented behavior

---

### 4. **Rate Limiting**
```ruby
DEFAULT_WAIT_TIME = 60
RATE_LIMIT_ERROR_CODES = [4, 17, 32, 613].freeze
```

**Usage**:
```ruby
# Before:
if [4, 17, 32, 613].include?(error_code)  # What are these codes?
  wait_time = extract_wait_time(data['error']) || 60  # Why 60?
  sleep(wait_time)
end

# After:
if RATE_LIMIT_ERROR_CODES.include?(error_code)
  wait_time = extract_wait_time(data['error']) || DEFAULT_WAIT_TIME
  sleep(wait_time)
end
```

**Benefits**:
- ✅ Clear intent (rate limit codes)
- ✅ Easy to add new error codes
- ✅ Documented default behavior

---

### 5. **Authentication Errors**
```ruby
AUTH_ERROR_CODES = [190, 102].freeze
```

**Usage**:
```ruby
# Before:
if [190, 102].include?(error_code)  # What are these?
  # Handle invalid token
end

# After:
if AUTH_ERROR_CODES.include?(error_code)
  # Handle invalid token
end
```

**Benefits**:
- ✅ Self-documenting code
- ✅ Clear error categorization
- ✅ Easy to add new auth error codes

---

## 📈 Impact

### Before:
```ruby
# Scattered magic numbers
api_url = 'https://graph.facebook.com/v8.0/'
timeout: 30
open_timeout: 10
limit = '&limit=100'
if [4, 17, 32, 613].include?(error_code)
  wait_time = extract_wait_time || 60
end
if [190, 102].include?(error_code)
  # ...
end
```

❌ Hard to understand  
❌ Hard to maintain  
❌ Scattered configuration  
❌ No documentation

---

### After:
```ruby
# Well-named constants at top of class
API_VERSION = 'v8.0'
API_BASE_URL = 'https://graph.facebook.com'
TIMEOUT_SECONDS = 30
OPEN_TIMEOUT_SECONDS = 10
API_PAGE_SIZE = 100
DEFAULT_WAIT_TIME = 60
RATE_LIMIT_ERROR_CODES = [4, 17, 32, 613].freeze
AUTH_ERROR_CODES = [190, 102].freeze

# Used throughout code
api_url = "#{API_BASE_URL}/#{API_VERSION}/"
timeout: TIMEOUT_SECONDS
open_timeout: OPEN_TIMEOUT_SECONDS
limit = "&limit=#{API_PAGE_SIZE}"
if RATE_LIMIT_ERROR_CODES.include?(error_code)
  wait_time = extract_wait_time || DEFAULT_WAIT_TIME
end
if AUTH_ERROR_CODES.include?(error_code)
  # ...
end
```

✅ Self-documenting  
✅ Easy to maintain  
✅ Centralized configuration  
✅ Well-documented

---

## 🎯 Benefits

### 1. **Readability**
```ruby
# Before: What does 30 mean?
timeout: 30

# After: Clear purpose!
timeout: TIMEOUT_SECONDS
```

---

### 2. **Maintainability**
```ruby
# Before: Need to change in multiple places
response = HTTParty.get(request, timeout: 30)
# ... somewhere else ...
response = HTTParty.get(request2, timeout: 30)

# After: Change once at the top
TIMEOUT_SECONDS = 45  # Changed from 30 to 45
```

---

### 3. **Documentation**
```ruby
# Constants serve as inline documentation
TIMEOUT_SECONDS = 30        # Read timeout: how long to wait for response
OPEN_TIMEOUT_SECONDS = 10   # Connection timeout: how long to wait for connection
```

---

### 4. **Testing**
```ruby
# Easy to stub constants in tests
stub_const('FacebookServices::FanpageCrawler::TIMEOUT_SECONDS', 1)
stub_const('FacebookServices::FanpageCrawler::API_VERSION', 'v9.0')
```

---

### 5. **Configuration**
```ruby
# Single place to configure all behavior
# Want faster timeouts? Change here:
TIMEOUT_SECONDS = 15        # Changed from 30
OPEN_TIMEOUT_SECONDS = 5    # Changed from 10

# Want to upgrade API? Change here:
API_VERSION = 'v18.0'       # Changed from v8.0
```

---

## 🔧 How to Change Configuration

### Increase Timeouts
```ruby
# app/services/facebook_services/fanpage_crawler.rb
TIMEOUT_SECONDS = 60        # From 30 to 60
OPEN_TIMEOUT_SECONDS = 20   # From 10 to 20
```

### Increase Page Size
```ruby
API_PAGE_SIZE = 200         # From 100 to 200 (more posts per request)
```

### Upgrade API Version
```ruby
API_VERSION = 'v18.0'       # From v8.0 to v18.0
```

### Adjust Rate Limit Wait Time
```ruby
DEFAULT_WAIT_TIME = 120     # From 60 to 120 seconds
```

### Add New Error Codes
```ruby
RATE_LIMIT_ERROR_CODES = [4, 17, 32, 613, 80007].freeze  # Added 80007
AUTH_ERROR_CODES = [190, 102, 2500].freeze               # Added 2500
```

---

## 📝 Naming Convention

All constants follow Rails/Ruby conventions:
- ✅ `SCREAMING_SNAKE_CASE`
- ✅ Descriptive names (not abbreviations)
- ✅ Grouped by category
- ✅ Comments explaining purpose
- ✅ `.freeze` for arrays (immutability)

---

## ✅ Checklist

- [x] Extract API configuration (version, base URL)
- [x] Extract timeout values
- [x] Extract pagination settings
- [x] Extract rate limit configuration
- [x] Extract error code arrays
- [x] Add inline comments
- [x] Use constants throughout code
- [x] Freeze arrays for immutability
- [x] Document all constants

---

## 🎉 Summary

**What changed**:
- ✅ 8 magic numbers extracted to constants
- ✅ Clear naming and documentation
- ✅ Centralized configuration
- ✅ Self-documenting code

**Impact**:
- ✅ **Readability**: Code is self-documenting
- ✅ **Maintainability**: Easy to change configuration
- ✅ **Testability**: Easy to stub/override
- ✅ **Consistency**: Single source of truth

**Files updated**:
- `app/services/facebook_services/fanpage_crawler.rb`

---

**Status**: ✅ **COMPLETE**

All magic numbers have been extracted to well-named constants! 🎉

