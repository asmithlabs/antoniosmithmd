class Passkey < ApplicationRecord
  ADMIN_HANDLE = "asmith-admin" # single-admin site
  validates :external_id, :public_key, presence: true
  validates :nickname, length: { maximum: 60 }
end
