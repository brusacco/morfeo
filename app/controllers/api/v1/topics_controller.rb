# frozen_string_literal: true

module Api
  module V1
    class TopicsController < ApplicationController
      before_action :set_default_response_format

      def popular
        topic = Topic.find_by(name: params[:query])
        tags = topic.tags.pluck(:name)
        @entries = Entry.includes(:site).a_week_ago.tagged_with(tags, any: true).order(total_count: :desc).limit(25)
      end

      def latest
        entries = Entry.order(published_at: :desc).limit(50)
        @tags = entries.tag_counts_on(:tags).order('count desc')
      end

      def search
        @tags = Tag.search(params[:q]).order('count desc')
      end

      private

      def set_default_response_format
        request.format = :json
      end
    end
  end
end
