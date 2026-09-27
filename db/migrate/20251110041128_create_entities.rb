# frozen_string_literal: true

class CreateEntities < ActiveRecord::Migration[7.0]
  def change
    create_table :entities do |t|
      t.string :name, null: false
      # 'entity_type' (not 'type') to avoid Rails STI on Entity < ApplicationRecord
      t.string :entity_type, null: false
      t.timestamps
    end

    add_index :entities, %i[name entity_type], unique: true, name: 'idx_entities_name_type_unique'
  end
end
