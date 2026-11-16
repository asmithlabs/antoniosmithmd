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

  # Research notebook: working notes by stage, most recently tended first, and every open question.
  def notebook
    @notes = Post.notebook.to_a
    @questions = @notes.flat_map { |p| p.question_list.map { [_1, p] } }
  end

  def feed = @posts = Post.published.limit(20)
end
