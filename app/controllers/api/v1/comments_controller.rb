module Api
  module V1
    class CommentsController < BaseController
      before_action :require_publish!, only: :update

      # GET /api/v1/comments?since=ISO8601&pending=1   (for briefings / agents)
      def index
        c = Comment.includes(:post).order(created_at: :desc).limit(200)
        c = c.where(created_at: Time.zone.parse(params[:since])..) if params[:since].present?
        c = c.where(approved: false) if params[:pending].present?
        render json: c.map { |x| { id: x.id, post: x.post.slug, parent_id: x.parent_id, author: x.author_name, body: x.body,
                                   score: x.score, approved: x.approved, created_at: x.created_at,
                                   url: post_url(x.post, anchor: "c#{x.id}") } }
      end

      # PATCH /api/v1/comments/:id  { "approved": true|false }
      def update
        Comment.find(params[:id]).update!(approved: ActiveModel::Type::Boolean.new.cast(params.require(:approved)))
        head :no_content
      end
    end
  end
end
