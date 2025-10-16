class AddIndexTaggingsOnTagIdAndTaggableType < ActiveRecord::Migration[7.0]
  def change
    return if index_exists?(:taggings, %i[tag_id taggable_type])

    add_index :taggings, %i[tag_id taggable_type], name: 'index_taggings_on_tag_id_and_taggable_type'
  end
end
