# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @tag_interacions = []
    @sites = Site.where(total_count: 1..).order(total_count: :desc)
    @entries = Entry.where(total_count: 10..)
                    .where.not(image_url: nil)
                    .includes(:site)
                    .order(published_at: :desc)
                    .limit(300)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    @entries.each do |entry|
      entry.tags.each do |tag|
        @tags.each do |t|
          t.interactions = 0 if t.interactions.nil?
          t.interactions += entry.total_count if tag.id == t.id
        end
      end
    end
  end

  def check
    @url = params[:url]
    @doc = Nokogiri::HTML(URI.parse(@url).open)
    @result = WebExtractorServices::ExtractDate.call(@doc)
  end
end
