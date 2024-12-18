class CreateTitleTopicStatDailies < ActiveRecord::Migration[7.0]
  def change
    create_table :title_topic_stat_dailies do |t|
      t.integer :entry_quantity
      t.integer :entry_interaction
      t.integer :average
      t.date :topic_date
      t.references :topic, null: false, foreign_key: true

      t.timestamps
    end
  end
end
