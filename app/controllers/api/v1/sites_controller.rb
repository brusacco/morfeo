# frozen_string_literal: true

module Api
  module V1
    class SitesController < ApplicationController
      before_action :set_default_response_format

      def popular
        site = Site.find_by(name: params[:query])
        @entries = site.entries.includes(:site).where(total_count: 1..).a_day_ago.order(total_count: :desc).limit(25)
      end

      def latest
        site = Site.find_by(name: params[:query])
        @entries = site.entries.includes(:site).order(published_at: :desc).limit(25)
      end

      def search
        site = Site.find_by(name: params[:query])
        tag = params[:query]
        @entries = site.entries.includes(:site).tagged_with(tag).order(published_at: :desc).limit(25)
      end

      private

      def set_default_response_format
        request.format = :json
      end
    end
  end
end
