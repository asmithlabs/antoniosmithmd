class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :post, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :comments }
      t.string :author_name
      t.text :body
      t.integer :score, default: 0, null: false
      t.boolean :approved, default: true, null: false
      t.string :ip_hash

      t.timestamps
    end
  end
end
