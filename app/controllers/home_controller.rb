# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @tag_interacions = []
    @sites = Site.where(total_count: 1..).order(total_count: :desc)
    @entries = Entry.has_interactions.has_image.includes(:site).order(published_at: :desc).limit(300)
    @tags = @entries.tag_counts_on(:tags).order('count desc')
  end

  def check
    @url = params[:url]
    @doc = Nokogiri::HTML(URI.parse(@url).open)
    @result = WebExtractorServices::ExtractDate.call(@doc)
  end
end
