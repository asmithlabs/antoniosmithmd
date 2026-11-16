module Admin
  # Kill switch for the API-fed project cards: hide/unhide or delete. Editing the text
  # happens at the source (hermes-ops), so a later sync can't silently undo it.
  class PortfolioProjectsController < BaseController
    def index = @projects = PortfolioProject.ordered

    def update
      PortfolioProject.find(params[:id]).update!(hidden: ActiveModel::Type::Boolean.new.cast(params.require(:hidden)))
      redirect_to admin_portfolio_projects_path
    end

    def destroy
      PortfolioProject.find(params[:id]).destroy
      redirect_to admin_portfolio_projects_path, notice: "Project card deleted."
    end
  end
end
