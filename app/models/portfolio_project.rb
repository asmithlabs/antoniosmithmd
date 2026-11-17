# A public project card on /projects, written by hermes-ops through the API
# (token scope "portfolio"). Everything here is public: the sender is responsible for
# sending only de-identified text. Fields are plain text and are always HTML-escaped
# on render — no markup is ever stored or interpreted.
#
# `hidden` can only be set from the admin page, so an admin "hide" survives later API
# updates (the kill switch wins over the sync).
class PortfolioProject < ApplicationRecord
  STATUSES = %w[idea active paused shipped archived].freeze
  API_FIELDS = %i[name summary status stage domain stack url repo_url position last_activity_at].freeze

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9][a-z0-9-]{0,62}\z/ }
  validates :name, presence: true, length: { maximum: 80 }
  validates :summary, length: { maximum: 600 }
  validates :status, inclusion: { in: STATUSES }
  validates :stage, :domain, length: { maximum: 40 }
  validates :stack, length: { maximum: 200 }
  validates :position, numericality: { only_integer: true, in: -1000..1000 }
  validate :links_are_https

  scope :listed, -> { where(hidden: false).where.not(status: "archived") }
  scope :ordered, -> { order(:position, Arel.sql("last_activity_at IS NULL"), last_activity_at: :desc, name: :asc) }

  def stack_list = stack.to_s.split(",").map(&:strip).reject(&:blank?)

  def as_api_json
    { slug:, name:, summary:, status:, stage:, domain:, stack: stack_list, url:, repo_url:, position:,
      hidden:, last_activity_at:, updated_at: }
  end

  private

  def links_are_https
    %i[url repo_url].each do |attr|
      v = self[attr]
      next if v.blank?
      uri = URI.parse(v) rescue nil
      errors.add(attr, "must be an https:// link") unless uri.is_a?(URI::HTTPS) && uri.host.present? && v.length <= 300
    end
  end
end
