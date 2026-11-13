class CreateReferences < ActiveRecord::Migration[8.1]
  def change
    create_table :references do |t|
      t.string :zotero_key
      t.string :citekey
      t.text :title
      t.string :authors
      t.string :year
      t.string :doi
      t.string :url
      t.string :item_type
      t.text :bib_html
      t.json :data
      t.integer :version

      t.timestamps
    end
    add_index :references, :zotero_key, unique: true
    add_index :references, :citekey, unique: true
  end
end
