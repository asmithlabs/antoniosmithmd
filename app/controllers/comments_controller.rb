class CommentsController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_back fallback_location: root_path, alert: "Slow down — try again in a few minutes." }
  before_action :set_post

  def create
    return redirect_to(post_path(@post)) if params[:website].present? # honeypot
    unless @post.comments_open?
      return redirect_to post_path(@post, anchor: "comments"), alert: "Comments aren't open on this post."
    end
    @comment = @post.comments.new(comment_params)
    @comment.ip_hash = Digest::SHA256.hexdigest("#{request.remote_ip}-#{Rails.application.secret_key_base}")[0, 16]
    @comment.approved = !@post.comments_moderated
    if @comment.parent && @comment.parent.depth >= Comment::MAX_DEPTH
      @comment.parent = @comment.parent.parent
    end
    if @comment.save
      cookies.permanent[:commenter] = @comment.author_name
      msg = @comment.approved ? "Comment posted." : "Thanks — your comment is awaiting approval."
      redirect_to post_path(@post, anchor: @comment.approved ? "c#{@comment.id}" : "comments"), notice: msg
    else
      redirect_to post_path(@post, anchor: "comments"), alert: @comment.errors.full_messages.to_sentence
    end
  end

  def vote
    comment = @post.comments.visible.find(params[:id])
    voted = (session[:votes] ||= {})
    dir = params[:dir] == "down" ? -1 : 1
    prev = voted[comment.id.to_s].to_i
    delta = prev == dir ? -dir : dir - prev   # click again to undo
    comment.increment!(:score, delta)
    voted[comment.id.to_s] = prev == dir ? 0 : dir
    redirect_to post_path(@post, anchor: "c#{comment.id}")
  end

  private
  def set_post = @post = Post.published.find_by!(slug: params[:post_id])
  def comment_params = params.require(:comment).permit(:author_name, :body, :parent_id)
end
