# frozen_string_literal: true

object @entry
attributes :id,
           :title,
           :description,
           :published_date,
           :tag_list,
           :total_count,
           :reaction_count,
           :comment_count,
           :share_count,
           :comment_plugin_count,
           :total_count
node(:news_source) { |entry| entry.site.name }
node(:news_url, &:url)
