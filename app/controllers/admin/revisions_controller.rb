module Admin
  class RevisionsController < BaseController
    before_action { @post = Post.find_by!(slug: params[:post_id]) }

    def index = @revisions = @post.revisions.limit(100)

    def show
      @revision = @post.revisions.find(params[:id])
      @diff = @revision.diff_html(@post.source_text)
    end

    def restore
      rev = @post.revisions.find(params[:id])
      @post.revision_editor = "admin (restored #{rev.created_at.to_fs(:short)})"
      @post.update!(title: rev.title, title_html: rev.title_html, body: rev.body, excerpt: rev.excerpt)
      redirect_to edit_admin_post_path(@post), notice: "Restored the version from #{rev.created_at.strftime('%b %-d, %Y %-l:%M %p')}. The version you replaced is saved in history."
    end
  end
end
