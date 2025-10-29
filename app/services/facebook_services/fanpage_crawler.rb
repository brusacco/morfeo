# frozen_string_literal: true

require 'json'
require 'open-uri'
require 'uri'
require 'cgi'

module FacebookServices
  class FanpageCrawler < ApplicationService
    REACTION_TYPES = %w[like love wow haha sad angry thankful].freeze

    def initialize(page_uid, cursor = nil)
      @page_uid = page_uid
      @cursor = cursor
    end

    def call
      page = Page.find_by!(uid: @page_uid)
      data = call_api(page.uid, @cursor)

      entries =
        Array(data['data']).filter_map do |post|
          persist_entry(page, post)
        end

      result = { entries: entries, next: data.dig('paging', 'cursors', 'after') }

      handle_success(result)
    rescue StandardError => e
      handle_error(e)
    end

    private

    def persist_entry(page, post)
      facebook_entry = FacebookEntry.find_or_initialize_by(facebook_post_id: post['id'])
      attachments_data = post.dig('attachments', 'data') || []
      main_attachment = attachments_data.first || {}

      attachment_target_url = decode_facebook_url(main_attachment.dig('target', 'url'))
      attachment_url = decode_facebook_url(main_attachment['url'])
      permalink_url = decode_facebook_url(post['permalink_url']) if post['permalink_url']

      width = main_attachment.dig('media', 'image', 'width')
      height = main_attachment.dig('media', 'image', 'height')

      reaction_counts = build_reaction_counts(post)

      facebook_entry.assign_attributes(
        page: page,
        posted_at: parse_timestamp(post['created_time']),
        fetched_at: Time.current,
        message: post['message'],
        permalink_url: permalink_url || attachment_target_url || attachment_url,
        attachment_type: main_attachment['type'],
        attachment_title: main_attachment['title'],
        attachment_description: main_attachment['description'],
        attachment_url: attachment_url,
        attachment_target_url: attachment_target_url,
        attachment_media_src: main_attachment.dig('media', 'image', 'src'),
        attachment_media_width: width.present? ? width.to_i : nil,
        attachment_media_height: height.present? ? height.to_i : nil,
        attachments_raw: attachments_data,
        comments_count: extract_total(post['comments']),
        share_count: numeric_value(post.dig('shares', 'count')),
        payload: post
      )

      facebook_entry.assign_attributes(reaction_counts)
      facebook_entry.reactions_total_count = reaction_counts.values.sum

      facebook_entry.save!

      # Tag the entry immediately after saving
      tag_entry(facebook_entry)

      facebook_entry
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[FacebookServices::FanpageCrawler] Unable to persist post #{post['id']}: #{e.message}")
      nil
    end

    def tag_entry(facebook_entry)
      result = WebExtractorServices::ExtractFacebookEntryTags.call(facebook_entry.id)

      # If no tags found through text matching, try to inherit from linked entry
      if !result.success? && facebook_entry.entry.present? && facebook_entry.entry.tag_list.any?
        entry_tags = facebook_entry.entry.tag_list.dup
        entry_tags.delete('Facebook')
        entry_tags.delete('WhatsApp')

        facebook_entry.tag_list = entry_tags
        facebook_entry.save!
        Rails.logger.info("[FacebookServices::FanpageCrawler] Tagged post #{facebook_entry.facebook_post_id} with inherited tags: #{entry_tags.join(', ')}")
        return
      end

      if result.success?
        tags = result.data.dup
        tags.delete('Facebook')
        tags.delete('WhatsApp')
        
        facebook_entry.tag_list = tags
        facebook_entry.save!
        Rails.logger.info("[FacebookServices::FanpageCrawler] Tagged post #{facebook_entry.facebook_post_id} with tags: #{tags.join(', ')}")
      else
        Rails.logger.debug("[FacebookServices::FanpageCrawler] No tags found for post #{facebook_entry.facebook_post_id}: #{result.error}")
      end
    rescue StandardError => e
      # Log tagging errors but don't fail the crawl
      Rails.logger.error("[FacebookServices::FanpageCrawler] Error tagging post #{facebook_entry.facebook_post_id}: #{e.message}")
    end

    def build_reaction_counts(post)
      REACTION_TYPES.each_with_object({}) do |type, acc|
        acc[:"reactions_#{type}_count"] = extract_total(post["reactions_#{type}"])
      end
    end

    def extract_total(node)
      summary = node.is_a?(Hash) ? node['summary'] : nil
      value = summary ? summary['total_count'] : nil
      numeric_value(value)
    end

    def numeric_value(value)
      case value
      when String
        value.to_i
      when Numeric
        value.to_i
      else
        0
      end
    end

    def parse_timestamp(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end

    def decode_facebook_url(url)
      return if url.blank?

      uri = URI.parse(url)
      if uri.host&.include?('l.facebook.com') && uri.query.present?
        params = CGI.parse(uri.query)
        params['u']&.first || url
      else
        url
      end
    rescue URI::InvalidURIError
      url
    end

    def call_api(page_uid, cursor = nil)
      api_url = 'https://graph.facebook.com/v8.0/'
      token = '&access_token=1442100149368278|KS0hVFPE6HgqQ2eMYG_kBpfwjyo'
      reactions = '%2Creactions.type(LIKE).limit(0).summary(total_count).as(reactions_like)%2Creactions.type(LOVE).limit(0).summary(total_count).as(reactions_love)%2Creactions.type(WOW).limit(0).summary(total_count).as(reactions_wow)%2Creactions.type(HAHA).limit(0).summary(total_count).as(reactions_haha)%2Creactions.type(SAD).limit(0).summary(total_count).as(reactions_sad)%2Creactions.type(ANGRY).limit(0).summary(total_count).as(reactions_angry)%2Creactions.type(THANKFUL).limit(0).summary(total_count).as(reactions_thankful)'
      comments = '%2Ccomments.limit(0).summary(total_count)'
      shares = '%2Cshares'
      limit = '&limit=100'
      next_page = cursor ? "&after=#{cursor}" : ''

      url = "/#{page_uid}/posts?fields=id%2Cattachments%2Ccreated_time%2Cmessage%2Cpermalink_url"
      request = "#{api_url}#{url}#{shares}#{comments}#{reactions}#{limit}#{token}#{next_page}"

      response = HTTParty.get(request)
      JSON.parse(response.body)
    end
  end
end
