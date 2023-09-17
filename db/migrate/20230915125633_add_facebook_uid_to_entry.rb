# frozen_string_literal: true

class AddFacebookUidToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :uid, :string
  end
end
