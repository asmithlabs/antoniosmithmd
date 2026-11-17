# Research notebook: a post can be a working note with a growth stage and open research questions.
class AddNotebookToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :notebook_stage, :string   # nil = finished essay; seedling | growing | mature
    add_column :posts, :questions, :text          # open research questions, one per line
    add_index :posts, :notebook_stage
  end
end
