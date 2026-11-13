module Admin
  class PostsController < BaseController
    before_action :set_post, only: %i[edit update destroy]

    def index = @posts = Post.left_joins(:comments).group(:id).select('posts.*, COUNT(comments.id) AS comments_count').order(Arel.sql("published_at IS NULL DESC, published_at DESC"))
    def new   = @post = Post.new(category: params[:category].presence_in(Post::CATEGORIES.keys))
    def edit; end

    def create
      @post = Post.new(post_params)
      @post.save ? redirect_to(admin_root_path, notice: cite_note(@post, "Post created.")) : render(:new, status: :unprocessable_entity)
    end

    def update
      @post.update(post_params) ? redirect_to(admin_root_path, notice: cite_note(@post, "Post saved.")) : render(:edit, status: :unprocessable_entity)
    end

    def destroy
      @post.destroy
      redirect_to admin_root_path, notice: "Post deleted."
    end

    private
    def cite_note(post, msg)
      missing = post.missing_citation_keys
      missing.any? ? "#{msg} Not found in Zotero: #{missing.map { "@#{_1}" }.join(", ")}" : msg
    end
    def set_post = @post = Post.find_by!(slug: params[:id])
    def post_params = params.require(:post).permit(:title, :slug, :excerpt, :body, :published_at, :category, :tags, :featured, :comments_enabled, :comments_open_at, :comments_moderated)
  end
end
