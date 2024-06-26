# frozen_string_literal: true

class AddStatusToTopics < ActiveRecord::Migration[7.0]
  def change
    add_column :topics, :status, :boolean, default: true
  end
end
