class RemoveDateAndAddDatesRangeToTemplates < ActiveRecord::Migration[7.0]
  def change
    remove_column :templates, :date
    add_column :templates, :start_date, :date
    add_column :templates, :end_date, :date
  end
end
