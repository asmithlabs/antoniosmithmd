module Admin
  # POST /admin/uploads (multipart, field "file") from the post editor's upload button.
  class UploadsController < BaseController
    def create
      name = ImageUpload.store(params[:file])
      render json: { url: upload_path(name) }, status: :created
    rescue ImageUpload::Rejected => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
