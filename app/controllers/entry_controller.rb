# frozen_string_literal: true

class EntryController < ApplicationController
  def show; end

  def popular
    @entries = Entry.has_interactions.a_day_ago.order(total_count: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc')
  end
end
