class AddRepeatedToEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :repeated, :boolean, default: false, null: false
  end
end
