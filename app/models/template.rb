class Template < ApplicationRecord
  belongs_to :topic
  belongs_to :admin_user
end
