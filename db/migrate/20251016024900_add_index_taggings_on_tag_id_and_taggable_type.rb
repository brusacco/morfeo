class AddIndexTaggingsOnTagIdAndTaggableType < ActiveRecord::Migration[7.0]
  def change
    add_index :taggings, [:tag_id, :taggable_type], name: 'index_taggings_on_tag_id_and_taggable_type' unless index_exists?(:taggings, [:tag_id, :taggable_type])
  end
end
