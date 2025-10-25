class AddViewsCountToFacebookEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :facebook_entries, :views_count, :integer, default: 0, null: false
  end
end
