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
    @post_projects = graph.projects_for(@post)
    @changes = @post.revisions.noted.limit(20).to_a
    @last_public_edit = @post.revisions.shown.first&.created_at
  end

  # Public history: only versions that were live on the site, newest first, each with a
  # word diff to the version that replaced it.
  def history
    @post = Post.published.find_by!(slug: params[:id])
    revs = @post.revisions.shown.limit(50).to_a
    current = PostRevision.new(title: @post.title, body: @post.body)
    @versions = revs.each_with_index.map { |r, i| [r, i.zero? ? current : revs[i - 1]] }
  end

  def feed = @posts = Post.published.limit(20)
end
