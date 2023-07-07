# frozen_string_literal: true

module Api
  module V1
    class EntriesController < ApplicationController
      before_action :set_default_response_format

      def show
        @entry = Entry.find(params[:id])
      end

      def popular
        @entries = Entry.includes(:site, :tags).where(total_count: 1..).a_day_ago.order(total_count: :desc).limit(25)
      end

      def latest
        @entries = Entry.includes(:site, :tags).order(published_at: :desc).limit(30)
      end

      def search
        tag = params[:query]
        @entries = Entry.includes(:site, :tags).tagged_with(tag).order(published_at: :desc).limit(25)
      end

      def similar
        @entry = Entry.find_by(url: params[:url])
        @entries = Entry.tagged_with(@entry.tags, any: true).order(published_at: :desc).limit(25) if @entry.present?
      end

      private

      def set_default_response_format
        request.format = :json
      end
    end
  end
end
