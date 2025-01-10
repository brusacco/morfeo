class AddFieldsToReports < ActiveRecord::Migration[7.0]
  def change
    add_column :reports, :title, :string
    add_column :reports, :sumary, :text
    add_column :reports, :date, :date
  end
end
