module Admin
  class ApiTokensController < BaseController
    def index = @tokens = ApiToken.order(:created_at)
    def create
      t = ApiToken.create!(params.require(:api_token).permit(:name, :scope))
      flash[:token] = t.plaintext
      redirect_to admin_api_tokens_path
    end
    def destroy
      ApiToken.find(params[:id]).destroy
      redirect_to admin_api_tokens_path, notice: "Token revoked."
    end
  end
end
