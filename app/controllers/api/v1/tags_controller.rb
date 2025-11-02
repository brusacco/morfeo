# frozen_string_literal: true

module Api
  module V1
    class TagsController < ApplicationController
      before_action :set_default_response_format

      def popular
        entries = Entry.where(total_count: 1..).a_day_ago.order(total_count: :desc).limit(50)
        @tags = entries.tag_counts_on(:tags).order('count desc')
      end

      def latest
        entries = Entry.order(published_at: :desc).limit(50)
        @tags = entries.tag_counts_on(:tags).order('count desc')
      end

      def search
        if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
          # NEW: Direct database query (no Elasticsearch required)
          @tags = Tag.where('name LIKE ?', "%#{params[:q]}%").order('taggings_count DESC')
        else
          # OLD: Elasticsearch
          @tags = Tag.search(params[:q]).order('count desc')
        end
      end

      private

      def set_default_response_format
        request.format = :json
      end
    end
  end
end
