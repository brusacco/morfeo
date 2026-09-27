# frozen_string_literal: true

class CreateEntityMentions < ActiveRecord::Migration[7.0]
  def change
    create_table :entity_mentions do |t|
      t.references :entity, null: false, foreign_key: true
      # Polymorphic content: Entry now, FacebookEntry/TwitterPost/InstagramPost later
      t.string :content_type, null: false
      t.bigint :content_id, null: false
      # Raw detection as returned by the GLiNER API
      t.string :text, null: false
      t.string :entity_type, null: false
      t.float :confidence
      t.integer :start
      t.integer :end
      t.timestamps
    end

    add_index :entity_mentions, %i[content_type content_id], name: 'idx_entity_mentions_on_content'
    add_index :entity_mentions,
              %i[entity_id content_type content_id start],
              unique: true,
              name: 'idx_entity_mentions_unique'
  end
end
