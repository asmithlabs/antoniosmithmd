module Admin
  class PasskeysController < BaseController
    def index = @passkeys = Passkey.order(:created_at)

    def options
      opts = WebAuthn::Credential.options_for_create(
        user: { id: WebAuthn.standard_encoder.encode(Passkey::ADMIN_HANDLE), name: "admin", display_name: "Antonio Smith (admin)" },
        exclude: Passkey.pluck(:external_id),
        authenticator_selection: { resident_key: "discouraged", user_verification: "preferred" })
      session[:reg_challenge] = opts.challenge
      render json: opts
    end

    def create
      cred = WebAuthn::Credential.from_create(params.require(:credential).to_unsafe_h)
      cred.verify(session.delete(:reg_challenge))
      Passkey.create!(external_id: cred.id, public_key: cred.public_key, sign_count: cred.sign_count,
                      nickname: params[:nickname].presence || "Passkey #{Passkey.count + 1}")
      session.delete(:enroll_only)
      render json: { ok: true }
    rescue WebAuthn::Error => e
      render json: { error: "Couldn't register passkey (#{e.class.name.demodulize})." }, status: :unprocessable_entity
    end

    def destroy
      if Passkey.count <= 1 && !DuoClient.configured?
        return redirect_to(admin_passkeys_path, alert: "That's your only second factor. Add another key (or set up Duo) before removing it.")
      end
      Passkey.find(params[:id]).destroy
      redirect_to admin_passkeys_path, notice: "Passkey removed."
    end
  end
end
