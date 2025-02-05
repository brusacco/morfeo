class Template < ApplicationRecord
  belongs_to :topic
  belongs_to :admin_user

  before_save :correct_date_range

  private

  # Asegurar que start_date sea menor o igual a end_date
  def correct_date_range
    if start_date.present? && end_date.present? && start_date > end_date
      self.start_date, self.end_date = end_date, start_date
    end
  end  
end
