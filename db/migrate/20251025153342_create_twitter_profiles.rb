class CreateTwitterProfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :twitter_profiles do |t|
      t.string :uid
      t.string :name
      t.string :username
      t.text :picture
      t.integer :followers, default: 0
      t.text :description
      t.boolean :verified, default: false
      t.references :site, null: true, foreign_key: true

      t.timestamps
    end

    add_index :twitter_profiles, :uid, unique: true
  end
end
