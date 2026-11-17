# Links from a post to the code and project it's about: repos, commits, PRs, docs, live apps.
# One per line, optionally "Label | https://…". Rendered as a "Code & project" box on the post.
class AddCodeLinksToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :code_links, :text
  end
end
