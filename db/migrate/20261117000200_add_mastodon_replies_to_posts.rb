# Show public Mastodon replies to a post's toot under the post. Admin can turn it off per post
# or hide individual replies (status ids, one per line).
class AddMastodonRepliesToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :mastodon_replies, :boolean, default: true, null: false
    add_column :posts, :mastodon_hidden, :text
  end
end
