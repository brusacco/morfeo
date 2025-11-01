class CreateEntryTopicAssociations < ActiveRecord::Migration[7.0]
  def change
    # Regular tags → entry_topics
    create_table :entry_topics do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true
      t.timestamps
    end
    
    # Composite indexes for fast lookups in both directions
    add_index :entry_topics, [:entry_id, :topic_id], unique: true, name: 'idx_entry_topics_unique'
    add_index :entry_topics, [:topic_id, :entry_id], name: 'idx_topic_entries'
    
    # Title tags → entry_title_topics
    create_table :entry_title_topics do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true
      t.timestamps
    end
    
    # Composite indexes for fast lookups in both directions
    add_index :entry_title_topics, [:entry_id, :topic_id], unique: true, name: 'idx_entry_title_topics_unique'
    add_index :entry_title_topics, [:topic_id, :entry_id], name: 'idx_topic_title_entries'
  end
end
