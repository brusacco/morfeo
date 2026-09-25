# frozen_string_literal: true

module HomeServices
  class CacheWarmerService < ApplicationService
    def initialize(days_range: DAYS_RANGE)
      @days_range = days_range
    end

    def call
      topic_id_sets.map do |topic_ids|
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        DashboardAggregatorService.call(topics: Topic.active.where(id: topic_ids), days_range: @days_range)

        {
          success: true,
          topic_ids: topic_ids,
          duration: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        }
      rescue StandardError => e
        {
          success: false,
          topic_ids: topic_ids,
          duration: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at,
          error_class: e.class.name,
          error: e.message
        }
      end
    end

    private

    def topic_id_sets
      active_topic_ids_by_user = UserTopic.joins(:topic)
                                          .where(topics: { status: true })
                                          .pluck(:user_id, :topic_id)
                                          .group_by(&:first)

      User.pluck(:id).map do |user_id|
        active_topic_ids_by_user.fetch(user_id, []).map(&:last).uniq.sort
      end.uniq
    end
  end
end
