require "net/http"

# Duo Universal Prompt (OIDC, Web SDK v4 protocol) — implemented directly per Duo's docs.
#   DUO_CLIENT_ID, DUO_CLIENT_SECRET, DUO_API_HOST (api-xxxx.duosecurity.com), DUO_USERNAME (your Duo username)
class DuoClient
  class Error < StandardError; end
  ALG = "HS512"

  def self.configured? = %w[DUO_CLIENT_ID DUO_CLIENT_SECRET DUO_API_HOST].all? { ENV[_1].present? }
  def self.username = ENV.fetch("DUO_USERNAME", "admin")

  def initialize(redirect_uri:)
    @id, @secret, @host = ENV.fetch("DUO_CLIENT_ID"), ENV.fetch("DUO_CLIENT_SECRET"), ENV.fetch("DUO_API_HOST")
    @redirect_uri = redirect_uri
    raise Error, "DUO_CLIENT_ID must be 20 characters" unless @id.length == 20
    raise Error, "DUO_CLIENT_SECRET must be 40 characters" unless @secret.length == 40
  end

  def health_check!
    url = "https://#{@host}/oauth/v1/health_check"
    res = post(url, client_id: @id, client_assertion: assertion(url))
    raise Error, "Duo is unavailable (#{res["message"] || res["stat"]})" unless res["stat"] == "OK"
  end

  def auth_url(state:, nonce:)
    req = JWT.encode({ scope: "openid", redirect_uri: @redirect_uri, client_id: @id, iss: @id, aud: "https://#{@host}",
                       exp: 5.minutes.from_now.to_i, state:, response_type: "code", duo_uname: self.class.username,
                       use_duo_code_attribute: true, nonce: }, @secret, ALG)
    "https://#{@host}/oauth/v1/authorize?" + URI.encode_www_form(response_type: "code", client_id: @id, request: req)
  end

  # Returns the verified id_token claims; raises unless Duo says "allow" for our user.
  def exchange!(code:, nonce:)
    url = "https://#{@host}/oauth/v1/token"
    res = post(url, grant_type: "authorization_code", code:, redirect_uri: @redirect_uri,
                    client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer", client_assertion: assertion(url))
    raise Error, "Duo token exchange failed (#{res["error_description"] || res["error"] || "no token"})" unless res["id_token"]
    claims, = JWT.decode(res["id_token"], @secret, true, algorithm: ALG, iss: url, verify_iss: true,
                         aud: @id, verify_aud: true, verify_iat: true, leeway: 60)
    raise Error, "Duo response was for a different user" unless claims["preferred_username"] == self.class.username
    raise Error, "Duo response didn't match this sign-in" unless ActiveSupport::SecurityUtils.secure_compare(claims["nonce"].to_s, nonce.to_s)
    raise Error, "Duo denied the sign-in" unless claims.dig("auth_result", "status") == "allow"
    claims
  rescue JWT::DecodeError => e
    raise Error, "Invalid Duo response (#{e.message})"
  end

  private

  def assertion(aud)
    JWT.encode({ iss: @id, sub: @id, aud:, exp: 5.minutes.from_now.to_i, jti: SecureRandom.hex(18), iat: Time.now.to_i }, @secret, ALG)
  end

  def post(url, form)
    uri = URI(url)
    res = Net::HTTP.start(uri.host, 443, use_ssl: true, open_timeout: 5, read_timeout: 15) { _1.post(uri.path, URI.encode_www_form(form)) }
    JSON.parse(res.body)
  rescue JSON::ParserError, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "Can't reach Duo (#{e.class.name.demodulize})"
  end
end
