class AddMastodonToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :share_mastodon, :boolean, default: true, null: false
    add_column :posts, :mastodon_url, :string
    add_column :posts, :mastodon_posted_at, :datetime
  end
end
