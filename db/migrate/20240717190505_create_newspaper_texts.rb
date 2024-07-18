class CreateNewspaperTexts < ActiveRecord::Migration[7.0]
  def change
    create_table :newspaper_texts do |t|
      t.string :title
      t.text :description
      t.references :newspaper, null: false, foreign_key: true

      t.timestamps
    end
  end
end
