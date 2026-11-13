module Admin
  # Two-factor sign-in:  1) password   2) security key / passkey (WebAuthn) OR Duo.
  # If no second factor exists yet, the password lets you in ONLY to enroll a security key.
  class SessionsController < ApplicationController
    layout "admin"
    MFA_WINDOW = 5.minutes
    rate_limit to: 10, within: 5.minutes, only: %i[create passkey duo_callback], with: -> { redirect_to admin_login_path, alert: "Too many attempts. Wait a few minutes." }
    before_action :require_password_step, only: %i[mfa passkey_options passkey duo_start duo_callback]

    def new
      return redirect_to(admin_root_path) if session[:admin_at]
      reset_session if session[:pw_at]
    end

    # Step 1: password
    def create
      expected = ENV.fetch("ADMIN_PASSWORD") { Rails.env.production? ? nil : "password" }
      unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(params[:password].to_s, expected)
        return redirect_to(admin_login_path, alert: "Wrong password.")
      end
      back = session[:return_to]
      reset_session
      session[:return_to] = back
      session[:pw_at] = Time.current.to_i
      if second_factor_available?
        redirect_to admin_mfa_path
      else
        session[:admin_at] = Time.current.to_i
        session[:enroll_only] = true          # can only add a security key until one exists
        redirect_to admin_passkeys_path, alert: "Set up your security key now — after this, sign-in always needs it."
      end
    end

    # Step 2: choose factor
    def mfa
      @duo = DuoClient.configured?
      @keys = Passkey.exists?
    end

    def passkey_options
      opts = WebAuthn::Credential.options_for_get(allow: Passkey.pluck(:external_id), user_verification: "preferred")
      session[:auth_challenge] = opts.challenge
      render json: opts
    end

    def passkey
      cred = WebAuthn::Credential.from_get(params.require(:credential).to_unsafe_h)
      key = Passkey.find_by!(external_id: cred.id)
      cred.verify(session.delete(:auth_challenge), public_key: key.public_key, sign_count: key.sign_count)
      key.update!(sign_count: cred.sign_count, last_used_at: Time.current)
      complete_sign_in!(json: true)
    rescue WebAuthn::Error, ActiveRecord::RecordNotFound => e
      render json: { error: "Security key not recognized (#{e.class.name.demodulize})." }, status: :unprocessable_entity
    end

    def duo_start
      duo = DuoClient.new(redirect_uri: admin_duo_callback_url)
      duo.health_check!
      session[:duo_state] = SecureRandom.hex(24)
      session[:duo_nonce] = SecureRandom.hex(24)
      redirect_to duo.auth_url(state: session[:duo_state], nonce: session[:duo_nonce]), allow_other_host: true
    rescue DuoClient::Error, KeyError => e
      redirect_to admin_mfa_path, alert: e.message
    end

    def duo_callback
      state, nonce = session.delete(:duo_state), session.delete(:duo_nonce)
      unless state.present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, state)
        return redirect_to(admin_mfa_path, alert: "Duo sign-in expired. Try again.")
      end
      DuoClient.new(redirect_uri: admin_duo_callback_url).exchange!(code: params.require(:duo_code), nonce:)
      complete_sign_in!
    rescue DuoClient::Error, ActionController::ParameterMissing => e
      redirect_to admin_mfa_path, alert: e.message
    end

    def destroy
      reset_session
      redirect_to root_path, notice: "Signed out."
    end

    private

    def second_factor_available? = Passkey.exists? || DuoClient.configured?

    def require_password_step
      ok = session[:pw_at] && Time.zone.at(session[:pw_at]) > MFA_WINDOW.ago
      return if ok
      respond_to do |f|
        f.json { render json: { error: "Session expired — enter your password again." }, status: :unauthorized }
        f.html { redirect_to admin_login_path, alert: "Enter your password first." }
      end
    end

    def complete_sign_in!(json: false)
      back = session[:return_to] || admin_root_path
      reset_session
      session[:admin_at] = Time.current.to_i
      json ? render(json: { redirect: back }) : redirect_to(back)
    end
  end
end
