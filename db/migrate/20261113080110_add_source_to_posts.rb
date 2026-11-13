class AddSourceToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :source, :string
    add_column :posts, :source_path, :string
  end
end
