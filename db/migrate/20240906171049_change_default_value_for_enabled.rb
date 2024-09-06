class ChangeDefaultValueForEnabled < ActiveRecord::Migration[7.0]
  def change
    change_column_default :entries, :enabled, from: false, to: true
  end
end
