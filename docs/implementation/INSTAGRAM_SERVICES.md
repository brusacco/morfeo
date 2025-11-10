# Instagram Services Implementation

## Overview

Servicios para integración con la API de Influencers.com.py para obtener datos de perfiles y posts de Instagram.

## Architecture

```
app/services/instagram_services/
├── get_profile_data.rb   # Obtiene datos del perfil
└── get_posts_data.rb     # Obtiene posts del perfil
```

## Services

### 1. GetProfileData

Obtiene información básica del perfil de Instagram.

**Usage:**
```ruby
result = InstagramServices::GetProfileData.call('ueno_py')

if result.success?
  puts result.data['profile_username']  # => "ueno_py"
  puts result.data['name']              # => "Ueno Bank"
  puts result.data['followers_count']   # => 123456
  puts result.data['following_count']   # => 789
  puts result.data['media_count']       # => 1500
  puts result.data['biography']         # => "Bio text..."
else
  puts "Error: #{result.error}"
end
```

**API Endpoint:**
```
GET https://www.influencers.com.py/api/v1/profiles/:username
```

**Expected Response:**
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

### 2. GetPostsData

Obtiene los posts del perfil con métricas de engagement.

**Usage:**
```ruby
result = InstagramServices::GetPostsData.call('ueno_py')

if result.success?
  puts result.data['profile_username']  # => "ueno_py"
  puts result.data['total_posts']       # => 100
  
  result.data['posts'].each do |post|
    puts post['shortcode']              # => "DQ2Z6SAgRpk"
    puts post['url']                    # => "https://www.instagram.com/p/..."
    puts post['caption']                # => "Caption text..."
    puts post['likes_count']            # => 297
    puts post['comments_count']         # => 5
    puts post['video_view_count']       # => 8956 (if video)
    puts post['total_count']            # => 302 (likes + comments)
    puts post['posted_at']              # => "2025-11-09T21:02:24.000Z"
    puts post['media']                  # => "GraphVideo" | "GraphImage" | "GraphSidecar"
  end
else
  puts "Error: #{result.error}"
end
```

**API Endpoint:**
```
GET https://www.influencers.com.py/api/v1/profiles/:username/posts
```

**Expected Response:**
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
      "media": "GraphSidecar",
      "product_type": "feed",
      "posted_at": "2025-11-09T21:02:24.000Z",
      "likes_count": 0,
      "comments_count": 0,
      "video_view_count": null,
      "total_count": 0,
      "profile_id": 3801,
      "created_at": "2025-11-09T21:02:42.960Z",
      "updated_at": "2025-11-09T21:02:44.329Z"
    }
  ]
}
```

## Environment Variables

### Required

- `INFLUENCERS_TOKEN`: Token de autenticación para la API de Influencers.com.py

**Setup:**
```bash
# Add to .env
INFLUENCERS_TOKEN=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
```

## Testing

### Verification Script

```bash
rails runner scripts/verify_instagram_api.rb
```

Este script verifica:
- ✅ Existencia del token en variables de entorno
- ✅ Conexión exitosa a la API
- ✅ Formato correcto de respuestas
- ✅ Datos del perfil
- ✅ Datos de posts

### Console Testing

```ruby
# Test profile data
profile = InstagramServices::GetProfileData.call('ueno_py')
pp profile.data if profile.success?

# Test posts data
posts = InstagramServices::GetPostsData.call('ueno_py')
pp posts.data if posts.success?
```

## Error Handling

Todos los servicios manejan errores consistentemente:

```ruby
result = InstagramServices::GetProfileData.call('username')

if result.success?
  # Process data
  data = result.data
else
  # Handle error
  case result.error
  when /Missing INFLUENCERS_TOKEN/
    # Token not configured
  when /API Error: 401/
    # Invalid token
  when /API Error: 404/
    # Profile not found
  when /timeout/i
    # Request timeout
  else
    # Other errors
  end
end
```

## Performance

- **Timeout**: 30 segundos por request
- **Caching**: Implementar en capa superior (modelos/jobs)
- **Rate Limiting**: Considerar límites de la API de Influencers.com.py

## Next Steps

1. **Crear modelos**: `InstagramProfile` e `InstagramPost`
2. **Crear jobs**: Background jobs para sincronización
3. **Implementar tagging**: Integrar con `acts_as_taggable_on`
4. **Dashboard**: Vista similar a Facebook/Twitter dashboards
5. **Analytics**: Métricas de engagement y alcance

## Related Documentation

- [Facebook Services](../facebook_services/)
- [Twitter Services](../twitter_services/)
- [Database Schema](../../../docs/DATABASE_SCHEMA.md)

## API Reference

**Base URL**: `https://www.influencers.com.py/api/v1`

**Authentication**: Query parameter `token`

**Endpoints**:
- `GET /profiles/:username` - Profile data
- `GET /profiles/:username/posts` - Posts data

## Implementation Notes

### Media Types
- `GraphImage`: Single image post
- `GraphVideo`: Video post (includes `video_view_count`)
- `GraphSidecar`: Carousel/album (multiple images/videos)

### Product Types
- `feed`: Regular feed post
- `clips`: Reels/clips
- `igtv`: IGTV videos

### Metrics
- `likes_count`: Number of likes
- `comments_count`: Number of comments
- `video_view_count`: Views (video posts only)
- `total_count`: Sum of likes + comments

### Date Format
- All dates in ISO 8601 format: `"2025-11-09T21:02:24.000Z"`
- Store as `datetime` in database

---

**Created**: November 10, 2025
**Status**: ✅ Ready for model implementation

