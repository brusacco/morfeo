# frozen_string_literal: true

module WithAnyTagIds
  extend ActiveSupport::Concern

  included do
    scope :with_any_tag_ids,
          lambda { |tag_ids, context: nil|
            if tag_ids.is_a?(ActiveRecord::Relation)
              tag_ids = tag_ids.select(:id)
              context_clause = 'AND taggings.context = ?' if context.present?
              bind_values = [base_class.name]
              bind_values << context.to_s if context.present?

              return where(
                "EXISTS (SELECT 1 FROM taggings WHERE taggings.taggable_id = #{connection.quote_table_name(table_name)}.id " \
                "AND taggings.taggable_type = ? #{context_clause} AND taggings.tag_id IN (#{tag_ids.to_sql}))",
                *bind_values
              )
            end

            tag_ids = Array(tag_ids).compact

            if tag_ids.empty?
              none
            else
              context_clause = 'AND taggings.context = ?' if context.present?
              bind_values = [base_class.name]
              bind_values << context.to_s if context.present?
              bind_values << tag_ids

              where(
                "EXISTS (SELECT 1 FROM taggings WHERE taggings.taggable_id = #{connection.quote_table_name(table_name)}.id " \
                "AND taggings.taggable_type = ? #{context_clause} AND taggings.tag_id IN (?))",
                *bind_values
              )
            end
          }
  end
end
