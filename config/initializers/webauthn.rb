origin = ENV.fetch("APP_ORIGIN") { "http://localhost:3999" }
WebAuthn.configure do |c|
  c.allowed_origins = [origin] + (Rails.env.development? ? %w[http://localhost:3000 http://localhost:3999] : [])
  c.rp_name = "Antonio Smith, MD"
  c.rp_id = ENV["APP_RP_ID"].presence || URI(origin).host   # passkeys are bound to this domain
end
