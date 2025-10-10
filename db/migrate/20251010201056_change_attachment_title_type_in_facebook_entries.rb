class ChangeAttachmentTitleTypeInFacebookEntries < ActiveRecord::Migration[7.0]
  def up
    change_column :facebook_entries, :attachment_title, :text
  end

  def down
    change_column :facebook_entries, :attachment_title, :string
  end
end
