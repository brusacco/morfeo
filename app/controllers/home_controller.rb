# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @tag_interacions = []
    @sites = Site.where(total_count: 1..).order(total_count: :desc)
    @entries = Entry.has_interactions.has_image.includes(:site).order(published_at: :desc).limit(300)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    @tags.each do |tag|
      @entries.each do |entry|
        tag.interactions ||= 0
        tag.interactions += entry.total_count
      end
    end

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }

    @tags_interactions = {}
    @entries.each do |entry|
      entry.tags.each do |tag|
        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.total_count
      end
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
    @tags_interactions.reverse
  end

  def check
    @url = params[:url]
    @doc = Nokogiri::HTML(URI.parse(@url).open)
    @result = WebExtractorServices::ExtractDate.call(@doc)
  end
end
