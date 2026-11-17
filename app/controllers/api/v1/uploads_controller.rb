module Api
  module V1
    # POST /api/v1/uploads (multipart, field "file"). Any valid token, drafts-only included, so an agent
    # can attach an image to a draft. Returns the path to use as an <img src> or in Markdown.
    class UploadsController < BaseController
      def create
        name = ImageUpload.store(params[:file])
        render json: { url: upload_path(name), absolute_url: upload_url(name) }, status: :created
      rescue ImageUpload::Rejected => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
