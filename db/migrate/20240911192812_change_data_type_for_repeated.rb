class ChangeDataTypeForRepeated < ActiveRecord::Migration[7.0]
  def up
    change_column :entries, :repeated, :integer, null: false, default: 0
  end

  def down
    change_column :entries, :repeated, :boolean
  end
end
