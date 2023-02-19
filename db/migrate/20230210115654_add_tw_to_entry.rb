# frozen_string_literal: true

class AddTwToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :tw_fav, :integer, default: 0
    add_column :entries, :tw_rt, :integer, default: 0
    add_column :entries, :tw_total, :integer, default: 0
  end
end
