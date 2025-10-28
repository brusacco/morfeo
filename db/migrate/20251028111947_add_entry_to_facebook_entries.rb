class AddEntryToFacebookEntries < ActiveRecord::Migration[7.0]
  def change
    add_reference :facebook_entries, :entry, foreign_key: true
  end
end
