# frozen_string_literal: true

class Report < ApplicationRecord
  belongs_to :topic, touch: true

  # after_save :generate_report

  # private

  # def generate_report
    
  # end
  
end
