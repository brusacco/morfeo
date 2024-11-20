# frozen_string_literal: true

class RecentEntry < ApplicationRecord
  self.table_name = 'recent_entries' # Explicitly set the table to use the SQL view
  acts_as_taggable_on :tags # Enables tagging functionality for RecentEntry
end
