class AddIsJsToSites < ActiveRecord::Migration[7.0]
  def change
    add_column :sites, :is_js, :boolean, default: false
  end
end
