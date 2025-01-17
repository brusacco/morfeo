class CreateTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :templates do |t|
      t.references :topic, null: false, foreign_key: true
      t.string :title
      t.text :sumary
      t.date :date

      t.timestamps
    end
  end
end
