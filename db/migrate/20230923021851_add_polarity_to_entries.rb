class AddPolarityToEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :polarity, :integer
    add_column :entries, :delta, :integer, default: 0
  end
end
