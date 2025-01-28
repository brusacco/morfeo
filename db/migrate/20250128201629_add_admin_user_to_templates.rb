class AddAdminUserToTemplates < ActiveRecord::Migration[7.0]
  def change
    add_reference :templates, :admin_user, foreign_key: true
  end
end
