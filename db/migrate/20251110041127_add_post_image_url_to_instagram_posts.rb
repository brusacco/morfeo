class AddPostImageUrlToInstagramPosts < ActiveRecord::Migration[7.0]
  def change
    add_column :instagram_posts, :post_image_url, :text
  end
end
