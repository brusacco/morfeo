# frozen_string_literal: true

require 'json'
require 'pp'
require 'cgi'

desc 'Actualiza la info de los sitios'
task update_api: :environment do
  # Reset all delta values for entries from this site
  puts 'Resetting delta values for all entries'
  pages = Page.where("uid <> ''")

  pages.each do |site|
    puts '-' * 30
    puts "Processing site: #{site.name} (UID: #{site.uid})"
    puts '-' * 30

    # Retry logic for entire site processing
    site_max_retries = 2
    site_retry_count = 0

    begin
      posts = {}
      cursor = nil
      page_number = 1
      max_pages = 3

      # Loop through pages using pagination (limited to 3 pages)
      while page_number <= max_pages
        puts "Fetching page #{page_number}/#{max_pages}..."
        data = call_api(site.uid, cursor)

        # Break if no data returned
        break if data['data'].nil? || data['data'].empty?

        data['data'].each do |post|
          next unless post['attachments'] &&
                      post['attachments']['data'] &&
                      post['attachments']['data'][0] &&
                      post['attachments']['data'][0]['type'] == 'share'

          attachment = post['attachments']['data'][0]

          # Clean target URL if it exists
          if attachment['target'] && attachment['target']['url']
            attachment['target']['url'] = clean_facebook_url(attachment['target']['url'])
          end

          # Clean main URL if it exists
          attachment['url'] = clean_facebook_url(attachment['url']) if attachment['url']

          # Use the cleaned target URL for processing
          target_url = attachment['target'] ? attachment['target']['url'] : nil
          next if target_url.nil?

          # Calculate total engagement
          total_engagement = calculate_total_engagement(post)

          post_data = {
            url: target_url,
            total_engagement: total_engagement,
            details: get_engagement_breakdown(post),
            post_id: post['id']
          }

          # If we already have a post with this URL, keep the one with higher engagement
          if posts[target_url]
            if total_engagement > posts[target_url][:total_engagement]
              puts "  → Replacing duplicate URL with higher engagement: #{total_engagement} > #{posts[target_url][:total_engagement]}"
              posts[target_url] = post_data
            else
              puts "  → Skipping duplicate URL with lower engagement: #{total_engagement} <= #{posts[target_url][:total_engagement]}"
            end
          else
            posts[target_url] = post_data
          end
        end

        # Check if there's a next page and we haven't reached the limit
        if data['paging'] && data['paging']['next'] && data['paging']['cursors'] && data['paging']['cursors']['after'] && page_number < max_pages
          cursor = data['paging']['cursors']['after']
          page_number += 1
          puts "Found next page cursor: #{cursor}"
        else
          if page_number >= max_pages
            puts "Reached maximum pages limit (#{max_pages})."
          else
            puts 'No more pages available.'
          end
          break
        end
      end

      # Print all clean URLs at the end
      puts "\n" + ('=' * 50)
      puts 'CLEAN URLs EXTRACTED WITH ENGAGEMENT:'
      puts '=' * 50
      posts.each do |_url, post_data|
        puts "Post ID: #{post_data[:post_id]}"

        # Check if URL exists in database
        entry = Entry.find_by_url_and_site_id(post_data[:url], site.id)
        delta_change = 0 # Initialize delta_change for all posts

        if entry
          puts "Clean URL: #{post_data[:url]}"

          entry.reaction_count = post_data[:details][:reactions][:total]
          entry.comment_count = post_data[:details][:comments]
          entry.share_count = post_data[:details][:shares]
          entry.total_count = post_data[:total_engagement]
          entry.save!
          puts "  → Stats updated: R:#{entry.reaction_count} C:#{entry.comment_count} S:#{entry.share_count} T:#{entry.total_count}"
        else
          puts "Clean URL: #{post_data[:url]}"
        end

        puts "Total Engagement: #{post_data[:total_engagement]} - Delta: #{delta_change}"
        puts "Breakdown: #{post_data[:details]}"
        puts '-' * 30
      end
      puts "Total posts processed: #{posts.count}"
      puts '=' * 50
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, SocketError => e
      site_retry_count += 1
      if site_retry_count <= site_max_retries
        puts "  ⚠️  Site processing failed (attempt #{site_retry_count}/#{site_max_retries}): #{e.class.name}"
        puts "  🔄 Retrying entire site in #{site_retry_count * 5} seconds..."
        sleep(site_retry_count * 5) # Progressive delay: 5s, 10s
        retry
      else
        puts "  ❌ Site processing failed after #{site_max_retries} retries: #{e.class.name}"
        puts '  ⏭️  Skipping to next site...'
      end
    end
  end
end

def call_api(page_uid, cursor = nil)
  api_url = 'https://graph.facebook.com/v17.0/'
  token = '&access_token=1442100149368278|KS0hVFPE6HgqQ2eMYG_kBpfwjyo'
  reactions = '%2Creactions.type(LIKE).limit(0).summary(total_count).as(reactions_like)%2Creactions.type(LOVE).limit(0).summary(total_count).as(reactions_love)%2Creactions.type(WOW).limit(0).summary(total_count).as(reactions_wow)%2Creactions.type(HAHA).limit(0).summary(total_count).as(reactions_haha)%2Creactions.type(SAD).limit(0).summary(total_count).as(reactions_sad)%2Creactions.type(ANGRY).limit(0).summary(total_count).as(reactions_angry)%2Creactions.type(THANKFUL).limit(0).summary(total_count).as(reactions_thankful)'
  comments = '%2Ccomments.limit(0).summary(total_count)'
  shares = '%2Cshares'
  limit = '&limit=100'
  next_page = cursor ? "&after=#{cursor}" : ''

  url = "#{page_uid}/posts?fields=id%2Cattachments%2Ccreated_time%2Cmessage"
  request = "#{api_url}#{url}#{shares}#{comments}#{reactions}#{limit}#{token}#{next_page}"

  # Retry logic for API calls
  max_retries = 3
  retry_count = 0

  begin
    response = HTTParty.get(request, timeout: 60)
    JSON.parse(response.body)
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, SocketError => e
    retry_count += 1
    if retry_count <= max_retries
      puts "  ⚠️  API call failed (attempt #{retry_count}/#{max_retries}): #{e.class.name}"
      puts "  🔄 Retrying in #{retry_count * 2} seconds..."
      sleep(retry_count * 2) # Progressive delay: 2s, 4s, 6s
      retry
    else
      puts "  ❌ API call failed after #{max_retries} retries: #{e.class.name}"
      raise e
    end
  end
end

def clean_facebook_url(facebook_url)
  return if facebook_url.nil?

  # Check if it's a Facebook redirect URL
  return facebook_url if facebook_url.exclude?('https://l.facebook.com/l.php?u=')

  # Extract the URL parameter
  match = facebook_url.match(/u=([^&]+)/)
  return if match.nil?

  # Decode the URL
  CGI.unescape(match[1])

  # If it's not a redirect URL, return as is
end

def calculate_total_engagement(post)
  total = 0

  # Add shares
  total += post['shares'] ? post['shares']['count'] : 0

  # Add comments
  total += post['comments'] && post['comments']['summary'] ? post['comments']['summary']['total_count'] : 0

  # Add all reaction types
  %w[
    reactions_like
    reactions_love
    reactions_wow
    reactions_haha
    reactions_sad
    reactions_angry
    reactions_thankful
  ].each do |reaction_type|
    total += post[reaction_type]['summary']['total_count'] if post[reaction_type] && post[reaction_type]['summary']
  end

  total
end

def get_engagement_breakdown(post)
  breakdown = {}

  # Shares
  breakdown[:shares] = post['shares'] ? post['shares']['count'] : 0

  # Comments
  breakdown[:comments] =
    post['comments'] && post['comments']['summary'] ? post['comments']['summary']['total_count'] : 0

  # Reactions
  breakdown[:reactions] = {}
  total_reactions = 0
  %w[
    reactions_like
    reactions_love
    reactions_wow
    reactions_haha
    reactions_sad
    reactions_angry
    reactions_thankful
  ].each do |reaction_type|
    reaction_name = reaction_type.split('_').last
    reaction_count = post[reaction_type] && post[reaction_type]['summary'] ? post[reaction_type]['summary']['total_count'] : 0
    breakdown[:reactions][reaction_name] = reaction_count
    total_reactions += reaction_count
  end

  # Add total reactions count
  breakdown[:reactions][:total] = total_reactions

  breakdown
end
