module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_admin
    before_action :require_enrollment

    private
    def require_admin
      return if session[:admin_at] && Time.zone.at(session[:admin_at]) > 12.hours.ago
      session[:return_to] = request.fullpath if request.get?
      redirect_to admin_login_path
    end

    # First-ever sign-in (password only) may do nothing but add a security key.
    def require_enrollment
      return unless session[:enroll_only]
      if Passkey.exists? || DuoClient.configured?
        session.delete(:enroll_only)
      elsif controller_name != "passkeys"
        redirect_to admin_passkeys_path, alert: "Add a security key before using admin."
      end
    end
  end
end
