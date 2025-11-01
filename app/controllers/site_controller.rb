# frozen_string_literal: true

class SiteController < ApplicationController
  before_action :authenticate_user!

  def show
    @site = Site.find(params[:id])
    @entries_stats = @site.entries.enabled.normal_range.group_by_day(:published_at)
    @entries = @site.entries.enabled.normal_range.order(published_at: :desc)

    # Ensure entries are loaded for word/bigram analysis
    loaded_entries = @entries.to_a
    @word_occurrences = word_occurrences(loaded_entries)
    @bigram_occurrences = bigram_occurrences(loaded_entries)
  end
end
