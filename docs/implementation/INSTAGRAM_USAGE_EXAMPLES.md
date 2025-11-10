# Instagram Services - Usage Examples

## Basic Usage

### 1. Console Testing

```ruby
# Rails console
rails c

# Test profile data
profile = InstagramServices::GetProfileData.call('ueno_py')
puts profile.success? ? profile.data : profile.error

# Test posts data
posts = InstagramServices::GetPostsData.call('ueno_py')
puts posts.success? ? posts.data : posts.error
```

### 2. Rake Tasks

```bash
# Test API connection
rake instagram:test_api

# Fetch specific profile
rake instagram:fetch_profile[ueno_py]

# Fetch posts for profile
rake instagram:fetch_posts[ueno_py]
```

### 3. Verification Script

```bash
# Run full verification
rails runner scripts/verify_instagram_api.rb
```

## Integration Examples

### Example 1: Sync Profile Data

```ruby
# Future implementation with InstagramProfile model
class InstagramProfileSyncService < ApplicationService
  def initialize(username)
    @username = username
  end
  
  def call
    result = InstagramServices::GetProfileData.call(@username)
    
    return handle_error(result.error) unless result.success?
    
    profile = InstagramProfile.find_or_initialize_by(username: @username)
    profile.update!(
      name: result.data['name'],
      followers_count: result.data['followers_count'],
      following_count: result.data['following_count'],
      media_count: result.data['media_count'],
      biography: result.data['biography'],
      profile_pic_url: result.data['profile_pic_url'],
      is_verified: result.data['is_verified'],
      last_synced_at: Time.current
    )
    
    handle_success(profile)
  end
end
```

### Example 2: Fetch and Store Posts

```ruby
# Future implementation with InstagramPost model
class InstagramPostsSyncService < ApplicationService
  def initialize(username)
    @username = username
  end
  
  def call
    result = InstagramServices::GetPostsData.call(@username)
    
    return handle_error(result.error) unless result.success?
    
    profile = InstagramProfile.find_by!(username: @username)
    posts_created = 0
    posts_updated = 0
    
    result.data['posts'].each do |post_data|
      post = InstagramPost.find_or_initialize_by(
        instagram_post_id: post_data['shortcode']
      )
      
      is_new = post.new_record?
      
      post.update!(
        profile: profile,
        url: post_data['url'],
        caption: post_data['caption'],
        media_type: post_data['media'],
        product_type: post_data['product_type'],
        posted_at: post_data['posted_at'],
        likes_count: post_data['likes_count'],
        comments_count: post_data['comments_count'],
        video_view_count: post_data['video_view_count'],
        total_count: post_data['total_count'],
        fetched_at: Time.current
      )
      
      is_new ? posts_created += 1 : posts_updated += 1
    end
    
    handle_success(
      posts_created: posts_created,
      posts_updated: posts_updated,
      total: posts_created + posts_updated
    )
  end
end
```

### Example 3: Background Job

```ruby
# app/jobs/sync_instagram_profile_job.rb
class SyncInstagramProfileJob < ApplicationJob
  queue_as :default
  
  def perform(username)
    # Sync profile
    profile_sync = InstagramProfileSyncService.call(username)
    return unless profile_sync.success?
    
    # Sync posts
    posts_sync = InstagramPostsSyncService.call(username)
    
    if posts_sync.success?
      Rails.logger.info "Instagram sync complete for @#{username}: #{posts_sync.posts_created} new, #{posts_sync.posts_updated} updated"
    else
      Rails.logger.error "Instagram posts sync failed for @#{username}: #{posts_sync.error}"
    end
  end
end
```

### Example 4: Scheduled Sync

```ruby
# config/schedule.rb (whenever gem)
every 1.hour do
  runner "InstagramProfile.where(active: true).find_each { |p| SyncInstagramProfileJob.perform_later(p.username) }"
end
```

## Error Handling Examples

### Example 1: Handle API Errors

```ruby
def fetch_instagram_data(username)
  result = InstagramServices::GetProfileData.call(username)
  
  if result.success?
    render json: result.data
  else
    case result.error
    when /Missing INFLUENCERS_TOKEN/
      render json: { error: 'API token not configured' }, status: :internal_server_error
    when /API Error: 404/
      render json: { error: 'Profile not found' }, status: :not_found
    when /API Error: 401/
      render json: { error: 'Invalid API token' }, status: :unauthorized
    when /timeout/i
      render json: { error: 'Request timeout' }, status: :gateway_timeout
    else
      render json: { error: 'API error occurred' }, status: :bad_gateway
    end
  end
end
```

### Example 2: Retry Logic

```ruby
def fetch_with_retry(username, max_retries: 3)
  retries = 0
  
  begin
    result = InstagramServices::GetPostsData.call(username)
    
    if result.success?
      return result
    elsif result.error.match?(/timeout|network/i) && retries < max_retries
      retries += 1
      sleep(2 ** retries) # Exponential backoff
      retry
    else
      return result
    end
  rescue StandardError => e
    Rails.logger.error "Instagram API error: #{e.message}"
    OpenStruct.new(success?: false, error: e.message)
  end
end
```

## Data Processing Examples

### Example 1: Calculate Engagement Rate

```ruby
def calculate_engagement_rate(posts_data)
  return 0 if posts_data['posts'].blank?
  
  total_engagement = posts_data['posts'].sum { |p| p['total_count'] }
  avg_engagement = total_engagement.to_f / posts_data['posts'].size
  
  # Assuming we have followers_count from profile data
  (avg_engagement / followers_count * 100).round(2)
end
```

### Example 2: Identify Top Posts

```ruby
def find_top_posts(username, limit: 10)
  result = InstagramServices::GetPostsData.call(username)
  return [] unless result.success?
  
  result.data['posts']
    .sort_by { |p| -p['total_count'] }
    .first(limit)
    .map do |post|
      {
        shortcode: post['shortcode'],
        url: post['url'],
        engagement: post['total_count'],
        caption: post['caption']&.truncate(100)
      }
    end
end
```

### Example 3: Media Type Analysis

```ruby
def analyze_media_types(username)
  result = InstagramServices::GetPostsData.call(username)
  return {} unless result.success?
  
  posts = result.data['posts']
  
  {
    total: posts.size,
    by_media_type: posts.group_by { |p| p['media'] }
                       .transform_values(&:count),
    by_product_type: posts.group_by { |p| p['product_type'] }
                         .transform_values(&:count),
    avg_engagement_by_media: posts.group_by { |p| p['media'] }
                                  .transform_values { |p| p.sum { |x| x['total_count'] } / p.size.to_f }
  }
end
```

## Testing Examples

### RSpec Example

```ruby
# spec/services/instagram_services/get_profile_data_spec.rb
require 'rails_helper'

RSpec.describe InstagramServices::GetProfileData do
  describe '#call' do
    let(:username) { 'ueno_py' }
    
    context 'when token is missing' do
      before { allow(ENV).to receive(:[]).with('INFLUENCERS_TOKEN').and_return(nil) }
      
      it 'returns error' do
        result = described_class.call(username)
        expect(result.success?).to be false
        expect(result.error).to include('Missing INFLUENCERS_TOKEN')
      end
    end
    
    context 'when API call succeeds', :vcr do
      it 'returns profile data' do
        result = described_class.call(username)
        
        expect(result.success?).to be true
        expect(result.data['profile_username']).to eq(username)
        expect(result.data).to have_key('followers_count')
      end
    end
    
    context 'when profile not found' do
      it 'returns error' do
        result = described_class.call('nonexistent_profile_12345')
        
        expect(result.success?).to be false
        expect(result.error).to include('404')
      end
    end
  end
end
```

## Performance Considerations

### Caching Example

```ruby
# Cache profile data for 1 hour
def cached_profile_data(username)
  Rails.cache.fetch("instagram:profile:#{username}", expires_in: 1.hour) do
    result = InstagramServices::GetProfileData.call(username)
    result.success? ? result.data : nil
  end
end

# Cache posts data for 30 minutes
def cached_posts_data(username)
  Rails.cache.fetch("instagram:posts:#{username}", expires_in: 30.minutes) do
    result = InstagramServices::GetPostsData.call(username)
    result.success? ? result.data : nil
  end
end
```

### Batch Processing Example

```ruby
# Process multiple profiles efficiently
def sync_multiple_profiles(usernames)
  usernames.each_with_index do |username, index|
    # Add delay to avoid rate limiting
    sleep(1) if index > 0
    
    begin
      SyncInstagramProfileJob.perform_later(username)
    rescue StandardError => e
      Rails.logger.error "Failed to queue sync for @#{username}: #{e.message}"
    end
  end
end
```

---

**Last Updated**: November 10, 2025
**Status**: Ready for model implementation

