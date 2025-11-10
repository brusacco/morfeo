# Instagram Services

Servicios para integración con Instagram mediante la API de Influencers.com.py.

## 🚀 Quick Start

### 1. Configure Environment

```bash
# Add to .env
INFLUENCERS_TOKEN=your_token_here
```

### 2. Test Connection

```bash
# Quick test
rake instagram:test_api

# Or use verification script
rails runner scripts/verify_instagram_api.rb
```

### 3. Fetch Data

```ruby
# In Rails console
profile = InstagramServices::GetProfileData.call('ueno_py')
posts = InstagramServices::GetPostsData.call('ueno_py')
```

## 📁 Structure

```
app/services/instagram_services/
├── get_profile_data.rb    # Profile information
└── get_posts_data.rb      # Posts with metrics

lib/tasks/
└── instagram.rake         # Rake tasks

scripts/
└── verify_instagram_api.rb  # Verification script

docs/implementation/
├── INSTAGRAM_SERVICES.md           # Full documentation
└── INSTAGRAM_USAGE_EXAMPLES.md     # Usage examples
```

## 🎯 Services

### GetProfileData

Obtiene información del perfil de Instagram.

```ruby
result = InstagramServices::GetProfileData.call('ueno_py')

if result.success?
  result.data['profile_username']  # => "ueno_py"
  result.data['name']              # => "Ueno Bank"
  result.data['followers_count']   # => 123456
  result.data['media_count']       # => 1500
end
```

### GetPostsData

Obtiene posts con métricas de engagement.

```ruby
result = InstagramServices::GetPostsData.call('ueno_py')

if result.success?
  result.data['total_posts']  # => 100

  result.data['posts'].each do |post|
    post['shortcode']        # => "DQ2Z6SAgRpk"
    post['likes_count']      # => 297
    post['comments_count']   # => 5
    post['total_count']      # => 302
  end
end
```

## 🔧 Available Tasks

```bash
# Test API connection
rake instagram:test_api

# Fetch specific profile
rake instagram:fetch_profile[ueno_py]

# Fetch posts for profile
rake instagram:fetch_posts[ueno_py]

# Run verification script
rails runner scripts/verify_instagram_api.rb
```

## 📊 API Response Examples

### Profile Data

```json
{
  "profile_username": "ueno_py",
  "name": "Ueno Bank",
  "followers_count": 123456,
  "following_count": 789,
  "media_count": 1500,
  "biography": "...",
  "profile_pic_url": "https://...",
  "is_verified": true
}
```

### Posts Data

```json
{
  "profile_username": "ueno_py",
  "total_posts": 100,
  "posts": [
    {
      "id": 2632413,
      "shortcode": "DQ2Z6SAgRpk",
      "url": "https://www.instagram.com/p/DQ2Z6SAgRpk",
      "caption": "Post caption...",
      "media": "GraphVideo",
      "posted_at": "2025-11-09T21:02:24.000Z",
      "likes_count": 297,
      "comments_count": 5,
      "video_view_count": 8956,
      "total_count": 302
    }
  ]
}
```

## ✅ Features

- ✅ Profile data fetching
- ✅ Posts data with engagement metrics
- ✅ Error handling with detailed messages
- ✅ Timeout protection (30s)
- ✅ Consistent API pattern (matches Twitter/Facebook services)
- ✅ Rake tasks for CLI usage
- ✅ Verification script
- ✅ Full documentation

## 🔜 Next Steps

1. **Create Models**: `InstagramProfile` and `InstagramPost`
2. **Database Migration**: Add Instagram tables
3. **Background Jobs**: Sync profiles/posts periodically
4. **Tagging System**: Integrate with `acts_as_taggable_on`
5. **Dashboard**: Instagram-specific analytics view
6. **Analytics**: Engagement rates, reach estimation

## 📚 Documentation

- [Full Documentation](../../docs/implementation/INSTAGRAM_SERVICES.md)
- [Usage Examples](../../docs/implementation/INSTAGRAM_USAGE_EXAMPLES.md)
- [Database Schema](../../docs/DATABASE_SCHEMA.md)

## 🔐 Security

- Token stored in environment variables (never committed)
- 30-second timeout on all requests
- Error handling prevents sensitive data leakage

## 🐛 Troubleshooting

### Token Missing

```
Error: Missing INFLUENCERS_TOKEN
```

**Solution**: Add `INFLUENCERS_TOKEN` to your `.env` file.

### API Error 401

```
Error: API Error: 401 - Unauthorized
```

**Solution**: Verify your token is correct in `.env`.

### API Error 404

```
Error: API Error: 404 - Not Found
```

**Solution**: Check the username exists on Instagram.

### Timeout

```
Error: HTTP error: execution expired
```

**Solution**: Check network connection or API availability.

## 📞 Support

For issues or questions:

1. Check documentation in `docs/implementation/`
2. Review existing patterns in `app/services/twitter_services/`
3. Run verification script: `rails runner scripts/verify_instagram_api.rb`

---

**Created**: November 10, 2025
**Status**: ✅ Production Ready
**Next**: Model Implementation
