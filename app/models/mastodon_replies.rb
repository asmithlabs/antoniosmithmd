require "net/http"

# Public replies to a post's toot, fetched from the toot's own instance
# (GET /api/v1/statuses/:id/context, no auth needed for public statuses).
#
# Remote content is untrusted: status HTML is re-sanitized to p/br/a/span with href only, links get
# rel="nofollow ugc noopener", and no remote images (avatars, media, emoji) are loaded.
# Fetched with short timeouts, cached 10 minutes, last good result kept 30 days. A post page never
# waits on this — the page loads the replies afterwards from /blog/:slug/fediverse.
class MastodonReplies
  Reply = Struct.new(:id, :url, :parent_id, :created_at, :name, :acct, :account_url, :html, :warning, :children, keyword_init: true)
  MAX = 60

  def self.for(post)
    return [] unless post.mastodon_url.present? && post.mastodon_replies?
    root = status_id(post.mastodon_url) or return []
    key = ["mastodon-replies/v1", post.id, post.mastodon_url]
    data = Rails.cache.fetch(key, expires_in: 10.minutes) do
      fetched = fetch(post.mastodon_url, root)
      Rails.cache.write(key + ["last-good"], fetched, expires_in: 30.days)
      fetched
    end
    tree(data, root, hidden_ids(post))
  rescue StandardError => e
    Rails.logger.warn("[mastodon-replies] #{post.slug}: #{e.class}: #{e.message}")
    key = ["mastodon-replies/v1", post.id, post.mastodon_url]
    data = Rails.cache.read(key + ["last-good"]) || []
    Rails.cache.write(key, data, expires_in: 2.minutes)   # don't retry an unreachable instance on every page view
    root ? tree(data, root, hidden_ids(post)) : []
  end

  def self.status_id(url) = url.to_s[%r{\Ahttps://[^/]+/@[^/]+/(\d+)\z}, 1]

  # Accepts reply links or bare ids, one per line.
  def self.hidden_ids(post) = post.mastodon_hidden.to_s.lines.filter_map { _1.strip[%r{(?:\A|/)(\d+)\z}, 1] }.to_set

  def self.fetch(toot_url, root)
    uri = URI.join(toot_url, "/api/v1/statuses/#{root}/context")
    req = Net::HTTP::Get.new(uri, "Accept" => "application/json", "User-Agent" => "antoniosmithmd.com")
    res = Net::HTTP.start(uri.host, 443, use_ssl: true, open_timeout: 3, read_timeout: 5) { _1.request(req) }
    raise "Mastodon #{res.code}" unless res.is_a?(Net::HTTPSuccess)
    JSON.parse(res.body).fetch("descendants", [])
  end

  # descendants JSON -> nested replies (public/unlisted only, hidden ones and their sub-threads dropped).
  def self.tree(descendants, root, hidden = Set.new)
    replies = Array(descendants).first(MAX).filter_map do |s|
      next unless %w[public unlisted].include?(s["visibility"]) && s["url"].to_s.start_with?("https://")
      next if hidden.include?(s["id"].to_s)
      acc = s["account"] || {}
      Reply.new(id: s["id"].to_s, url: s["url"], parent_id: s["in_reply_to_id"].to_s,
                created_at: (Time.zone.parse(s["created_at"].to_s) rescue nil),
                name: (acc["display_name"].presence || acc["username"]).to_s.first(80), acct: acc["acct"].to_s.first(100),
                account_url: (acc["url"].to_s if acc["url"].to_s.start_with?("https://")),
                html: clean(s["content"]), warning: s["spoiler_text"].to_s.first(200).presence, children: [])
    end
    by_id = replies.index_by(&:id)
    top = []
    replies.each { |r| r.parent_id == root.to_s ? top << r : by_id[r.parent_id]&.children&.push(r) }
    top
  end

  def self.clean(html)
    safe = Rails::HTML5::SafeListSanitizer.new.sanitize(html.to_s, tags: %w[p br a span], attributes: %w[href])
    frag = Nokogiri::HTML.fragment(safe)
    frag.css("a").each do |a|
      href = a["href"].to_s
      href.start_with?("https://", "http://") ? a.set_attribute("rel", "nofollow ugc noopener") : a.remove_attribute("href")
      a["target"] = "_blank" if a["href"]
    end
    frag.to_html.html_safe
  end
end
