class AddBlogFieldsToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :category, :string
    add_column :posts, :tags, :string
    add_column :posts, :comments_enabled, :boolean, default: true, null: false
    add_column :posts, :comments_open_at, :datetime
    add_column :posts, :comments_moderated, :boolean, default: false, null: false
    add_column :posts, :featured, :boolean, default: false, null: false
  end
end
