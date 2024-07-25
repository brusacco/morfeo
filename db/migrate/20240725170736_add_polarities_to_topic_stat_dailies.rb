class AddPolaritiesToTopicStatDailies < ActiveRecord::Migration[7.0]
  def change
    add_column :topic_stat_dailies, :positive_quantity, :integer
    add_column :topic_stat_dailies, :negative_quantity, :integer
    add_column :topic_stat_dailies, :neutral_quantity, :integer
    add_column :topic_stat_dailies, :positive_interaction, :integer
    add_column :topic_stat_dailies, :negative_interaction, :integer
    add_column :topic_stat_dailies, :neutral_interaction, :integer
  end
end
