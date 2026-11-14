require "net/http"

# Shares newly published posts to Mastodon once.
#   MASTODON_URL=https://mastodon.social  MASTODON_TOKEN=<app token with write:statuses>
class MastodonSyndication
  LIMIT = 500

  def self.configured? = ENV["MASTODON_URL"].present? && ENV["MASTODON_TOKEN"].present?

  # Posts that are live, opted in, and not yet shared. Safe to call repeatedly.
  def self.share_due!
    return 0 unless configured?
    Post.published.where(share_mastodon: true, mastodon_posted_at: nil).where(published_at: 2.days.ago..).sum { share!(_1) ? 1 : 0 }
  end

  def self.share!(post)
    # Claim the post atomically so two workers/processes can never both share it.
    claimed = Post.where(id: post.id, mastodon_posted_at: nil).update_all(mastodon_posted_at: Time.current)
    return false if claimed.zero?
    url = post_status(text_for(post), idempotency_key: "antoniosmithmd-post-#{post.id}")
    Post.where(id: post.id).update_all(mastodon_url: url)
    Rails.logger.info("[mastodon] shared #{post.slug} → #{url}")
    true
  rescue StandardError => e
    Post.where(id: post.id).update_all(mastodon_posted_at: nil)   # release the claim so it retries later
    Rails.logger.warn("[mastodon] #{post.slug}: #{e.message}")
    false
  end

  def self.text_for(post)
    link = Rails.application.routes.url_helpers.post_url(post, host: URI(ENV.fetch("APP_ORIGIN", "https://antoniosmithmd.com")).host, protocol: "https")
    tags = post.tag_list.map { |t| "#" + t.split(/[^[:alnum:]]+/).reject(&:blank?).map { _1[0].upcase + _1[1..] }.join }.reject { _1.size < 2 }.uniq.first(5).join(" ")
    fixed = ["\n\n", link, (tags.present? ? "\n\n#{tags}" : "")].join   # URLs count as 23 chars on Mastodon
    budget = LIMIT - (fixed.size - link.size + 23) - 2
    body = [post.title, post.excerpt.presence].compact.join("\n\n")
    body = body.truncate(budget, separator: " ", omission: "…")
    body + fixed
  end

  def self.post_status(text, idempotency_key:)
    uri = URI.join(ENV.fetch("MASTODON_URL"), "/api/v1/statuses")
    req = Net::HTTP::Post.new(uri, "Authorization" => "Bearer #{ENV.fetch("MASTODON_TOKEN")}", "Idempotency-Key" => idempotency_key,
                                   "Content-Type" => "application/x-www-form-urlencoded")
    req.body = URI.encode_www_form(status: text, visibility: "public", language: "en")
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 15) { _1.request(req) }
    raise "Mastodon #{res.code}: #{res.body.to_s[0, 200]}" unless res.is_a?(Net::HTTPSuccess)
    JSON.parse(res.body).fetch("url")
  end
end
