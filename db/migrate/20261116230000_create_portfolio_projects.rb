class CreatePortfolioProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :portfolio_projects do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.text :summary
      t.string :status, null: false, default: "active"
      t.string :stage
      t.string :domain
      t.string :stack
      t.string :url
      t.string :repo_url
      t.integer :position, null: false, default: 0
      t.boolean :hidden, null: false, default: false
      t.datetime :last_activity_at
      t.string :source
      t.timestamps
    end
    add_index :portfolio_projects, :slug, unique: true
  end
end
