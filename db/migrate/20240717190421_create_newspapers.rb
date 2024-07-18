class CreateNewspapers < ActiveRecord::Migration[7.0]
  def change
    create_table :newspapers do |t|
      t.date :date
      t.references :site, null: false, foreign_key: true

      t.timestamps
    end
  end
end
