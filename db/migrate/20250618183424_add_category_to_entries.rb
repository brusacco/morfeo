class AddCategoryToEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :category, :string
  end
end
