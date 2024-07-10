class CreateTopicStatDailies < ActiveRecord::Migration[7.0]
  def change
    create_table :topic_stat_dailies do |t|
      t.integer :entry_count
      t.integer :total_count
      t.integer :average
      t.date :topic_date
      t.references :topic, null: false, foreign_key: true

      t.timestamps
    end
  end
end
