class AddAvatarImageUrlToInstagramProfiles < ActiveRecord::Migration[7.0]
  def change
    add_column :instagram_profiles, :avatar_image_url, :text
  end
end
