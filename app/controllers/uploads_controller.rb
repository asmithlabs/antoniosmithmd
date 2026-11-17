# Serves images stored by ImageUpload. Public, like the posts that show them.
# Not an ApplicationController: its modern-browser check would turn away feed readers and crawlers.
class UploadsController < ActionController::Base
  def show
    path, type = ImageUpload.find(params[:name])
    return head(:not_found) unless path
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Content-Security-Policy"] = "default-src 'none'; sandbox"
    expires_in 1.year, public: true, immutable: true
    send_file path, type:, disposition: "inline"
  end
end
