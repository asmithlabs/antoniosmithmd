# Public revision history: a revision is shown to readers only if the text it holds was live
# when it was replaced. Existing rows default to private (we can't prove they were public).
class AddPublicHistoryToPostRevisions < ActiveRecord::Migration[8.1]
  def change
    add_column :post_revisions, :public, :boolean, default: false, null: false
    add_column :post_revisions, :change_kind, :string
    add_column :post_revisions, :change_note, :text
    add_index :post_revisions, %i[post_id public created_at]
  end
end
