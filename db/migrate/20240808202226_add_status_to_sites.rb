class AddStatusToSites < ActiveRecord::Migration[7.0]
  def change
    add_column :sites, :status, :boolean, default: true
  end
end
