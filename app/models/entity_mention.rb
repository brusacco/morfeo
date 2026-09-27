# frozen_string_literal: true

# A single entity detection inside a content item (Entry now; FacebookEntry,
# TwitterPost, InstagramPost later — polymorphic `content`).
#
# Stores the raw GLiNER detection: surface `text`, `entity_type`, `confidence`
# and character offsets `start`/`end`. The same canonical Entity can be
# mentioned many times with different surface forms and confidences.
#
# NOTE: `end` is a Ruby keyword — read it with `mention[:end]` and write it
# with the string key `'end' => value`.
class EntityMention < ApplicationRecord
  belongs_to :entity
  belongs_to :content, polymorphic: true

  validates :entity_id, uniqueness: { scope: %i[content_type content_id start] }
  validates :text, presence: true
  validates :entity_type, presence: true
end
