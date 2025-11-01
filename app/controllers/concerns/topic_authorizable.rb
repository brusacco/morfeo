# frozen_string_literal: true

# TopicAuthorizable Concern
# Provides consistent authorization logic for topic-based controllers
#
# Usage:
#   class MyTopicController < ApplicationController
#     include TopicAuthorizable
#     before_action :set_topic
#     before_action :authorize_topic_access!, only: [:show, :pdf]
#   end
#
# IMPORTANT: You must call authorize_topic_access! AFTER set_topic
#
# Requirements:
#   - Controller must have @topic instance variable set before authorization
#   - Controller must have current_user available (via Devise)
#
# This concern checks:
#   1. Topic exists
#   2. Topic is active (status == true)
#   3. Current user has access to the topic
module TopicAuthorizable
  extend ActiveSupport::Concern

  # NOTE: We do NOT add before_action here because it needs to run AFTER set_topic
  # Controllers must explicitly add: before_action :authorize_topic_access!, only: [:show, :pdf]

  private

  # Main authorization method
  # Checks if current user can access the topic
  def authorize_topic_access!
    unless can_access_topic?
      handle_unauthorized_topic_access
    end
  end

  # Check if user can access the topic
  # Override this method in controller if custom logic is needed
  def can_access_topic?
    topic_exists? && topic_active? && user_has_topic_access?
  end

  # Check if topic exists
  def topic_exists?
    @topic.present?
  end

  # Check if topic is active
  def topic_active?
    @topic.status == true
  end

  # Check if current user has access to the topic
  def user_has_topic_access?
    @topic.users.exists?(current_user.id)
  end

  # Handle unauthorized access
  # Override this method in controller for custom behavior
  def handle_unauthorized_topic_access
    Rails.logger.warn "Unauthorized topic access attempt: user=#{current_user&.id}, topic=#{@topic&.id}"
    
    redirect_to root_path,
                alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado'
  end

  # Helper method to get detailed authorization status
  # Useful for debugging or custom error messages
  def topic_authorization_status
    {
      topic_exists: topic_exists?,
      topic_active: topic_active?,
      user_has_access: user_has_topic_access?,
      can_access: can_access_topic?
    }
  end
end

