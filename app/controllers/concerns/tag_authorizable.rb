# frozen_string_literal: true

# TagAuthorizable Concern
# Provides authorization logic for tag-based controllers
#
# Usage:
#   class TagController < ApplicationController
#     include TagAuthorizable
#     before_action :set_tag
#     before_action :authorize_tag_access!, only: [:show, :comments, :report]
#   end
#
# IMPORTANT: You must call authorize_tag_access! AFTER set_tag
#
# Requirements:
#   - Controller must have @tag instance variable set before authorization
#   - Controller must have current_user available (via Devise)
#   - Controller must have @topicos set (user's topics)
#
# This concern checks:
#   1. Tag exists
#   2. Current user has access to at least one topic that uses this tag
module TagAuthorizable
  extend ActiveSupport::Concern

  private

  # Main authorization method
  # Checks if current user can access the tag
  def authorize_tag_access!
    unless can_access_tag?
      handle_unauthorized_tag_access
    end
  end

  # Check if user can access the tag
  # Tag is accessible if user has access to at least one topic that uses it
  def can_access_tag?
    tag_exists? && user_has_tag_access?
  end

  # Check if tag exists
  def tag_exists?
    @tag.present?
  end

  # Check if current user has access to at least one topic using this tag
  # User can access tag if ANY of their topics use this tag
  def user_has_tag_access?
    return false unless @tag.present?
    
    # Get user's topic IDs
    user_topic_ids = @topicos.pluck(:id)
    
    # Check if tag is used by any of user's topics
    @tag.topics.where(id: user_topic_ids, status: true).exists?
  end

  # Handle unauthorized access
  # Override this method in controller for custom behavior
  def handle_unauthorized_tag_access
    redirect_to root_path, alert: 'No tienes acceso a este tag.'
  end
end

