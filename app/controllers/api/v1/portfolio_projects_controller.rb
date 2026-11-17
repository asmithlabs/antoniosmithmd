module Api
  module V1
    # Project cards for /projects, pushed by hermes-ops.
    #   GET    /api/v1/portfolio          list (including hidden, so the sender can see what the admin hid)
    #   GET    /api/v1/portfolio/:slug
    #   PUT    /api/v1/portfolio/:slug    upsert { name, summary, status, stage, domain, stack: [..] | "a, b",
    #                                              url, repo_url, position, last_activity_at }
    #   DELETE /api/v1/portfolio/:slug
    # `hidden` is not accepted here: only the admin page can hide or unhide a card.
    class PortfolioProjectsController < BaseController
      self.allowed_scopes = %w[portfolio publish].freeze

      def index = render(json: PortfolioProject.ordered.map(&:as_api_json))
      def show = render(json: PortfolioProject.find_by!(slug: params[:id]).as_api_json)

      def update
        project = PortfolioProject.find_or_initialize_by(slug: params[:id].to_s)
        attrs = params.permit(*(PortfolioProject::API_FIELDS - [:stack]), :stack, stack: [])
        attrs[:stack] = Array(attrs[:stack]).join(", ") if attrs[:stack].is_a?(Array)
        project.assign_attributes(attrs.to_h.merge(source: "api:#{token.name}"))
        if project.save
          render json: project.as_api_json, status: (project.previously_new_record? ? :created : :ok)
        else
          render json: { errors: project.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        PortfolioProject.find_by!(slug: params[:id]).destroy
        head :no_content
      end
    end
  end
end
