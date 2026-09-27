# frozen_string_literal: true

# Canonical named entity detected by the GLiNER2 extraction service.
#
# An Entity is the resolved identity (e.g. "Instituto de Previsión Social");
# the raw detections per content item live in EntityMention. Initial
# resolution is exact match on [name, entity_type]; alias resolution
# (e.g. "IPS" -> "Instituto de Previsión Social") is a later step.
#
# NOTE: the type column is `entity_type` (not `type`) to avoid Rails STI.
class Entity < ApplicationRecord
  has_many :entity_mentions, dependent: :destroy
  has_many :entries, through: :entity_mentions

  # Later, when social content is wired (no schema change needed):
  # has_many :facebook_entries, through: :entity_mentions, source: :facebook_entry
  # has_many :twitter_posts, through: :entity_mentions, source: :twitter_post
  # has_many :instagram_posts, through: :entity_mentions, source: :instagram_post

  validates :name, presence: true, uniqueness: { scope: :entity_type }
  validates :entity_type, presence: true
end
