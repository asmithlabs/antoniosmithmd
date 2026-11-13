module Admin
  class CommentsController < BaseController
    def index = @comments = Comment.includes(:post).order(approved: :asc, created_at: :desc).limit(200)
    def update
      Comment.find(params[:id]).update!(approved: params[:approved] == "1")
      redirect_to admin_comments_path, notice: "Updated."
    end
    def destroy
      Comment.find(params[:id]).destroy
      redirect_to admin_comments_path, notice: "Deleted."
    end
  end
end
