# Paragraph-level discussion: a top-level comment may be attached to one passage of the post.
# anchor = the passage's id ("para-1a2b3c4d", derived from its text); anchor_text = the passage
# as it read when the comment was made (taken from the post on the server, never from the browser).
class AddAnchorToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :anchor, :string
    add_column :comments, :anchor_text, :string
    add_index :comments, %i[post_id anchor]
  end
end
