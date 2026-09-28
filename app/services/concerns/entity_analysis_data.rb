# frozen_string_literal: true

# Shared entity-analysis loader for the digital dashboard and PDF services.
#
# Aggregates the GLiNER2 [EntityMention](../../../.okf/models/entity_mention.md)
# rows attached to a set of entries into a plain, cache-friendly payload:
#
#   {
#     entities: [ { name:, type:, mentions: }, ... ],  # top N by mentions, mentions >= MIN_MENTIONS
#     types:    { 'person' => { entities:, mentions: }, ... }
#   }
#
# Only entities detected more than once (mentions >= MIN_MENTIONS) are kept, so
# one-off detections don't clutter the report.
#
# The payload is plain data (no AR objects) so it can be stored in the
# dashboard snapshot cache and the PDF payload.
#
# `build_entity_analysis` is pure (no caching) so the PDF service can call it
# directly; the aggregator wraps it in `fetch_cached_with_race_protection`.
module EntityAnalysisData
  MAX_ENTITIES = 100
  MIN_MENTIONS = 2

  def build_entity_analysis(entries)
    return { entities: [], types: {} } if entries.nil? || entries.empty?

    entry_ids = entries.respond_to?(:distinct) ? entries.distinct.select(:id) : entries.map(&:id)

    rows = EntityMention
           .where(content_type: Entry.base_class.name, content_id: entry_ids)
           .group('entity_id', 'entity_type', 'text')
           .having('COUNT(*) >= ?', MIN_MENTIONS)
           .order(Arel.sql('COUNT(*) DESC'))
           .limit(MAX_ENTITIES)
           .select('entity_id, entity_type, text, COUNT(*) AS mentions')

    entities = rows.map { |row| { name: row.text, type: row.entity_type, mentions: row.mentions } }

    {
      entities: entities,
      types: entity_type_breakdown(entities)
    }
  end

  private

  def entity_type_breakdown(entities)
    entities.group_by { |e| e[:type] }
            .transform_values do |group|
      {
        entities: group.size,
        mentions: group.sum { |e| e[:mentions] }
      }
    end
  end
end
