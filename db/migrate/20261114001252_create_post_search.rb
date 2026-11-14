class CreatePostSearch < ActiveRecord::Migration[8.1]
  def up
    create_virtual_table :post_search, :fts5, ["title", "body", "tags", "tokenize='unicode61 remove_diacritics 2'", "prefix='2 3 4'"]
    Post.reset_column_information
    Post.find_each(&:reindex_search!)
  end

  def down
    drop_table :post_search
  end
end
