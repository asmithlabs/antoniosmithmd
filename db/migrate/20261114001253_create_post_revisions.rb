class CreatePostRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :post_revisions do |t|
      t.references :post, null: false, foreign_key: true
      t.string :title
      t.text :title_html
      t.text :body
      t.text :excerpt
      t.string :editor

      t.datetime :created_at, null: false
    end
  end
end
