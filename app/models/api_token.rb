class ApiToken < ApplicationRecord
  SCOPES = {
    "draft"   => "Drafts only — can create/update unpublished posts and read comments (use for AI agents)",
    "publish" => "Full — can publish posts and moderate comments (use for your Obsidian sync)"
  }.freeze
  validates :name, presence: true
  validates :scope, inclusion: { in: SCOPES.keys }
  attr_reader :plaintext

  before_validation on: :create do
    @plaintext = "asm_#{SecureRandom.base58(32)}"
    self.token_digest = self.class.digest(@plaintext)
  end

  def self.digest(t) = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, t.to_s)
  def self.authenticate(t) = t.present? ? find_by(token_digest: digest(t)) : nil
  def publish? = scope == "publish"
end
