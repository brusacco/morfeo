# frozen_string_literal: true

class CreateReports < ActiveRecord::Migration[7.0]
  def change
    create_table :reports do |t|
      t.references :topic, null: false, foreign_key: true
      t.text :report_text

      t.timestamps
    end
  end
end
