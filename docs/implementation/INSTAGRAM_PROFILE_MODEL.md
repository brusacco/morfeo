# InstagramProfile Model Implementation

## Overview

Modelo para almacenar perfiles de Instagram obtenidos de la API de Influencers.com.py.

## Database Schema

### Table: `instagram_profiles`

```ruby
create_table :instagram_profiles do |t|
  # Basic Profile Info
  t.string :uid, null: false                    # Instagram user ID
  t.string :username, null: false               # Instagram username (@ueno_py)
  t.string :full_name                           # Display name
  t.text :biography                             # Bio text
  t.string :profile_type                        # "marca", "persona", etc.

  # Follower/Following Counts
  t.integer :followers, default: 0
  t.integer :following, default: 0

  # Profile Status Flags
  t.boolean :is_verified, default: false
  t.boolean :is_business_account, default: false
  t.boolean :is_professional_account, default: false
  t.boolean :is_private, default: false

  # Profile Metadata
  t.string :country_string
  t.string :category_name
  t.string :business_category_name

  # Profile Images
  t.text :profile_pic_url                      # Standard resolution
  t.text :profile_pic_url_hd                   # High definition

  # Analytics & Metrics (from API)
  t.decimal :engagement_rate, precision: 10, scale: 2
  t.integer :total_posts, default: 0
  t.integer :total_videos, default: 0
  t.integer :total_likes_count, default: 0
  t.integer :total_comments_count, default: 0
  t.bigint :total_video_view_count, default: 0
  t.integer :total_interactions_count, default: 0
  t.integer :median_interactions, default: 0
  t.integer :median_video_views, default: 0

  # Reach Estimation (from API)
  t.integer :estimated_reach, default: 0
  t.decimal :estimated_reach_percentage, precision: 10, scale: 2

  # System Fields
  t.datetime :last_synced_at
  t.references :site, null: true, foreign_key: true

  t.timestamps
end

# Indexes
add_index :instagram_profiles, :uid, unique: true
add_index :instagram_profiles, :username, unique: true
add_index :instagram_profiles, :last_synced_at
```

## Model Relationships

```ruby
class InstagramProfile < ApplicationRecord
  # Associations
  belongs_to :site, optional: true
  has_many :instagram_posts, dependent: :destroy
  
  # Tagging
  acts_as_taggable_on :tags
end
```

### Relationships Diagram

```
Site
  ├─→ InstagramProfile (belongs_to)
  │     └─→ InstagramPost (has_many)
  │           ├─→ Tags (via acts_as_taggable_on)
  │           └─→ Entry (optional, for cross-linking)
  └─→ Page (Facebook)
  └─→ TwitterProfile
```

## Validations

```ruby
validates :uid, presence: true, uniqueness: true
validates :username, presence: true, uniqueness: true
```

## Scopes

```ruby
# Active profiles (synced in last 7 days)
InstagramProfile.active

# Verified profiles
InstagramProfile.verified

# Business accounts
InstagramProfile.business_accounts

# Public profiles
InstagramProfile.public_profiles

# Order by engagement
InstagramProfile.by_engagement

# Order by followers
InstagramProfile.by_followers
```

## Instance Methods

### Profile Information

```ruby
profile = InstagramProfile.find_by(username: 'ueno_py')

# Display name (full_name or username)
profile.display_name
# => "ueno bank"

# Instagram profile URL
profile.instagram_url
# => "https://www.instagram.com/ueno_py/"
```

### Engagement Metrics

```ruby
# Calculate engagement rate
# Formula: (total_interactions / (total_posts * followers)) * 100
profile.calculate_engagement_rate
# => 2.15

# Get average engagement per post
profile.average_engagement
# => 3772.5

# Total reach
profile.total_reach
# => 49187
```

### Sync Management

```ruby
# Check if profile needs sync (older than 24 hours)
profile.needs_sync?
# => true/false

# Get recent posts
profile.recent_posts(10)
# => [#<InstagramPost>, #<InstagramPost>, ...]
```

## Callbacks

### After Create

```ruby
after_create :update_profile_data
```

Automatically fetches and updates profile data from API after creation:

```ruby
profile = InstagramProfile.create!(username: 'ueno_py')
# Automatically calls InstagramServices::UpdateProfile
# Updates all profile fields from API
```

### After Update

```ruby
after_update :update_site_image
```

Updates associated site's image with Instagram profile picture (if site present).

## Usage Examples

### Creating a Profile

```ruby
# Simple creation (triggers API fetch via callback)
profile = InstagramProfile.create!(username: 'ueno_py')

# With site association
profile = InstagramProfile.create!(
  username: 'ueno_py',
  site: Site.find_by(name: 'Ueno Bank')
)

# Find or create
profile = InstagramProfile.find_or_create_by!(username: 'ueno_py')
```

### Updating a Profile

```ruby
profile = InstagramProfile.find_by(username: 'ueno_py')

# Manual data update (triggers site image update)
profile.update!(full_name: 'New Name')

# Sync from API
profile.update_profile_data
```

### Querying Profiles

```ruby
# Find by username
profile = InstagramProfile.find_by(username: 'ueno_py')

# Find by uid
profile = InstagramProfile.find_by(uid: '49695956067')

# Get all active profiles
active_profiles = InstagramProfile.active

# Top 10 by engagement
top_profiles = InstagramProfile.by_engagement.limit(10)

# Verified business accounts
verified_business = InstagramProfile.verified.business_accounts
```

### Analytics

```ruby
profile = InstagramProfile.find_by(username: 'ueno_py')

# Profile stats
puts "Followers: #{profile.followers}"
puts "Engagement Rate: #{profile.engagement_rate}%"
puts "Total Posts: #{profile.total_posts}"
puts "Total Interactions: #{profile.total_interactions_count}"
puts "Estimated Reach: #{profile.estimated_reach}"
puts "Median Interactions: #{profile.median_interactions}"

# Calculated metrics
puts "Average Engagement: #{profile.average_engagement}"
puts "Calculated Engagement Rate: #{profile.calculate_engagement_rate}%"
```

### With Tags

```ruby
profile = InstagramProfile.find_by(username: 'ueno_py')

# Add tags
profile.tag_list.add('banco', 'finanzas', 'paraguay')
profile.save!

# Find profiles by tag
finanzas_profiles = InstagramProfile.tagged_with('finanzas')

# Find profiles with any of multiple tags
banking_profiles = InstagramProfile.tagged_with(['banco', 'finanzas'], any: true)
```

## Rake Tasks

```bash
# Test API connection
rake instagram:test_api

# Sync specific profile (create or update)
rake instagram:sync_profile[ueno_py]

# Test model functionality
rake instagram:test_model
```

## Console Examples

```ruby
# Rails console
rails c

# Create profile
profile = InstagramProfile.create!(username: 'ueno_py')

# Check data
pp profile.attributes

# Get profile info
puts "#{profile.display_name} (@#{profile.username})"
puts "Followers: #{profile.followers.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "Engagement: #{profile.engagement_rate}%"
puts "Verified: #{profile.is_verified ? '✓' : '✗'}"

# Update from API
profile.update_profile_data

# Check sync status
puts "Last synced: #{profile.last_synced_at}"
puts "Needs sync: #{profile.needs_sync?}"

# Get posts (after implementing InstagramPost model)
profile.recent_posts.each do |post|
  puts "#{post.shortcode}: #{post.likes_count} likes"
end
```

## API Data Mapping

### From API Response to Model

```ruby
API Field                    → Model Field
-------------------------------------------
id                          → (not stored, API internal ID)
username                    → username
uid                         → uid
full_name                   → full_name
biography                   → biography
profile_type                → profile_type
followers                   → followers
following                   → following
is_verified                 → is_verified
is_business_account         → is_business_account
is_professional_account     → is_professional_account
is_private                  → is_private
country_string              → country_string
category_name               → category_name
business_category_name      → business_category_name
profile_pic_url             → profile_pic_url
profile_pic_url_hd          → profile_pic_url_hd
engagement_rate             → engagement_rate
total_posts                 → total_posts
total_videos                → total_videos
total_likes_count           → total_likes_count
total_comments_count        → total_comments_count
total_video_view_count      → total_video_view_count
total_interactions_count    → total_interactions_count
median_interactions         → median_interactions
median_video_views          → median_video_views
estimated_reach             → estimated_reach
estimated_reach_percentage  → estimated_reach_percentage
tags                        → (handled by acts_as_taggable_on)
```

## Performance Considerations

### Indexes

```ruby
# Unique indexes for lookups
uid (unique)
username (unique)

# Performance indexes
last_synced_at (for finding stale profiles)
```

### Caching

```ruby
# Cache profile data to avoid excessive API calls
Rails.cache.fetch("instagram:profile:#{username}", expires_in: 1.hour) do
  InstagramProfile.find_by(username: username)
end
```

### Batch Operations

```ruby
# Find profiles that need sync
stale_profiles = InstagramProfile.where('last_synced_at < ? OR last_synced_at IS NULL', 24.hours.ago)

# Update in batch
stale_profiles.find_each do |profile|
  profile.update_profile_data
  sleep(1) # Rate limiting
end
```

## Error Handling

```ruby
begin
  profile = InstagramProfile.create!(username: 'invalid_user')
rescue ActiveRecord::RecordInvalid => e
  puts "Validation error: #{e.message}"
rescue StandardError => e
  puts "Error: #{e.message}"
end
```

## Testing

### RSpec Examples

```ruby
# spec/models/instagram_profile_spec.rb
RSpec.describe InstagramProfile, type: :model do
  describe 'associations' do
    it { should belong_to(:site).optional }
    it { should have_many(:instagram_posts).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:uid) }
    it { should validate_uniqueness_of(:uid) }
    it { should validate_presence_of(:username) }
    it { should validate_uniqueness_of(:username) }
  end

  describe '#instagram_url' do
    let(:profile) { create(:instagram_profile, username: 'test_user') }
    
    it 'returns correct Instagram URL' do
      expect(profile.instagram_url).to eq('https://www.instagram.com/test_user/')
    end
  end

  describe '#calculate_engagement_rate' do
    let(:profile) do
      create(:instagram_profile,
        total_interactions_count: 1000,
        total_posts: 10,
        followers: 1000
      )
    end
    
    it 'calculates engagement rate correctly' do
      expect(profile.calculate_engagement_rate).to eq(10.0)
    end
  end
end
```

## Next Steps

1. **Implement InstagramPost model** - Store individual posts
2. **Create background jobs** - Periodic syncing
3. **Add ActiveAdmin interface** - Admin management
4. **Create dashboard** - Instagram-specific analytics view
5. **Implement tagging service** - Auto-tag posts by topic
6. **Add sentiment analysis** - Analyze captions
7. **Cross-linking** - Link Instagram posts to news entries

## Related Documentation

- [Instagram Services](./INSTAGRAM_SERVICES.md)
- [Instagram Usage Examples](./INSTAGRAM_USAGE_EXAMPLES.md)
- [Database Schema](../DATABASE_SCHEMA.md)
- [Twitter Profile Model](../../app/models/twitter_profile.rb)
- [Facebook Page Model](../../app/models/page.rb)

---

**Created**: November 10, 2025  
**Status**: ✅ Ready for Production  
**Next**: InstagramPost Model Implementation

