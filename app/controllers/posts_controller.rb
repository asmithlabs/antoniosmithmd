class PostsController < ApplicationController
  def index
    @category = params[:category].presence_in(Post::CATEGORIES.keys)
    @tag = params[:tag].presence
    @posts = Post.published.in_category(@category)
    @posts = @posts.where("',' || REPLACE(tags, ', ', ',') || ',' LIKE ?", "%,#{Post.sanitize_sql_like(@tag)},%") if @tag
  end

  def show
    @post = Post.published.find_by!(slug: params[:id])
    @tree = Comment.tree_for(@post)
    @comment = @post.comments.new
    graph = KnowledgeGraph.current
    @related = graph.related(@post)
    @backlinks = graph.backlinks(@post)
  end

  # Mastodon replies as an HTML fragment, loaded by the post page after it renders.
  def fediverse
    @post = Post.published.find_by!(slug: params[:id])
    @replies = MastodonReplies.for(@post)
    expires_in 5.minutes, public: true
    render layout: false
  end

  def feed = @posts = Post.published.limit(20)
end
