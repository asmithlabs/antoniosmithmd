module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate!
      rescue_from ActiveRecord::RecordNotFound, with: -> { render json: { error: "not found" }, status: :not_found }
      rescue_from ActionController::ParameterMissing, with: ->(e) { render json: { error: e.message }, status: :bad_request }

      private
      attr_reader :token

      def authenticate!
        raw = request.authorization.to_s[/\ABearer (.+)\z/, 1]
        @token = ApiToken.authenticate(raw)
        return render(json: { error: "invalid token" }, status: :unauthorized) unless @token
        @token.touch(:last_used_at)
      end

      def require_publish!
        render json: { error: "this token is draft-only" }, status: :forbidden unless token.publish?
      end

      def post_json(p, full: false)
        h = { slug: p.slug, title: p.title, status: p.published? ? "published" : (p.published_at ? "scheduled" : "draft"),
              published_at: p.published_at, category: p.category, tags: p.tag_list, excerpt: p.excerpt,
              source: p.source, url: (p.published? ? post_url(p) : nil), edit_url: edit_admin_post_url(p), updated_at: p.updated_at }
        h[:body_html] = p.body if full
        h
      end
    end
  end
end
