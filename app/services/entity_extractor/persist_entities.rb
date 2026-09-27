# frozen_string_literal: true

module EntityExtractor
  # Persists the entities detected in a piece of content.
  #
  # Calls the GLiNER extraction API, keeps only detections whose confidence is
  # strictly greater than MIN_CONFIDENCE, resolves each to a canonical Entity
  # (exact match on [name, entity_type]) and records an EntityMention on the
  # given content object (Entry now; FacebookEntry/TwitterPost/InstagramPost
  # later — the polymorphic association makes this transparent).
  #
  # Example:
  #   result = EntityExtractor::PersistEntities.call(text: '...', content: entry)
  #   if result.success?
  #     result.entities_created # => 3
  #     result.mentions_created # => 5
  #     result.ignored          # => 2 (confidence <= 0.9)
  #   else
  #     result.error # => "HTTP 500: ..." (extraction failed; nothing persisted)
  #   end
  #
  # On extraction failure nothing is persisted and the result is a failure —
  # callers (e.g. a Sidekiq worker) should retry, never mark as completed.
  class PersistEntities < ApplicationService
    MIN_CONFIDENCE = 0.9

    def initialize(text:, content:)
      @text = text.to_s
      @content = content
    end

    def call
      extraction = EntityExtractor::ExtractEntities.call(text: @text)
      return handle_error(extraction.error) unless extraction.success?

      entities_created = 0
      mentions_created = 0
      ignored = 0

      ActiveRecord::Base.transaction do
        extraction.entities.each do |detected|
          confidence = Float(detected['confidence'] || 0)
          ignored += 1 if confidence <= MIN_CONFIDENCE
          next unless confidence > MIN_CONFIDENCE

          entity = Entity.find_or_create_by!(name: detected['text'], entity_type: detected['type'])
          entities_created += 1 if entity.saved_change_to_id?

          mention = EntityMention.find_or_create_by!(
            entity: entity,
            content_type: @content.class.base_class.name,
            content_id: @content.id,
            text: detected['text'],
            entity_type: detected['type'],
            confidence: confidence,
            start: detected['start'],
            'end' => detected['end']
          )
          mentions_created += 1 if mention.saved_change_to_id?
        end
      end

      handle_success({ entities_created:, mentions_created:, ignored: })
    end
  end
end
