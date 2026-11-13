class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  helper_method :admin_signed_in?

  private
  def admin_signed_in? = session[:admin_at].present? && Time.zone.at(session[:admin_at]) > 12.hours.ago && !session[:enroll_only]
end
