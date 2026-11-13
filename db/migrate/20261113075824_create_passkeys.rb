class CreatePasskeys < ActiveRecord::Migration[8.1]
  def change
    create_table :passkeys do |t|
      t.string :external_id
      t.text :public_key
      t.integer :sign_count, default: 0, null: false
      t.string :nickname
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :passkeys, :external_id, unique: true
  end
end
