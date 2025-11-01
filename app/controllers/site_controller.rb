# frozen_string_literal: true

class SiteController < ApplicationController
  before_action :authenticate_user!

  def show
    @site = Site.find(params[:id])
    
    # Use optimized service for data aggregation
    data = SiteDashboardServices::AggregatorService.call(site: @site)
    
    @entries_stats = data[:entries_stats]
    @entries = data[:entries]
    @word_occurrences = data[:word_occurrences]
    @bigram_occurrences = data[:bigram_occurrences]
    @tags = data[:tags_data][:tags]
    @tags_interactions = data[:tags_data][:tags_interactions]
  end
end
