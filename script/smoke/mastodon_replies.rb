# CI smoke: Mastodon replies are threaded, filtered, hidden on request and sanitized.
# No network: MastodonReplies.fetch is replaced with a canned /context response.
# Run with: bin/rails runner script/smoke/mastodon_replies.rb
acct = ->(n) { { "display_name" => n, "username" => n.downcase, "acct" => "#{n.downcase}@example.social", "url" => "https://example.social/@#{n.downcase}" } }
canned = [
  { "id" => "200", "in_reply_to_id" => "100", "visibility" => "public", "url" => "https://example.social/@ann/200", "created_at" => 1.hour.ago.iso8601,
    "account" => acct.("Ann <b>A</b>"), "content" => %(<p>Great post <a href="https://x.org" class="u-url">link</a><script>alert(1)</script><img src="https://evil/x.png" onerror="alert(2)"></p>) },
  { "id" => "201", "in_reply_to_id" => "200", "visibility" => "unlisted", "url" => "https://example.social/@bob/201", "created_at" => 30.minutes.ago.iso8601,
    "account" => acct.("Bob"), "content" => "<p>agree</p>", "spoiler_text" => "meds" },
  { "id" => "202", "in_reply_to_id" => "100", "visibility" => "direct", "url" => "https://example.social/@cat/202", "account" => acct.("Cat"), "content" => "<p>private</p>" },
  { "id" => "203", "in_reply_to_id" => "100", "visibility" => "public", "url" => "https://example.social/@dan/203", "account" => acct.("Dan"), "content" => "<p>spam</p>" },
  { "id" => "204", "in_reply_to_id" => "203", "visibility" => "public", "url" => "https://example.social/@eve/204", "account" => acct.("Eve"), "content" => "<p>under spam</p>" },
]
MastodonReplies.define_singleton_method(:fetch) { |_url, _root| canned }
Rails.cache.clear
post = Post.new(id: 900_100, slug: "smoke-fedi", title: "x", mastodon_url: "https://example.social/@me/100",
                mastodon_replies: true, mastodon_hidden: "https://example.social/@dan/203\n")
top = MastodonReplies.for(post)
fail "expected 1 top-level reply, got #{top.map(&:id)}" unless top.map(&:id) == ["200"]
fail "child missing" unless top[0].children.map(&:id) == ["201"] && top[0].children[0].warning == "meds"
html = top[0].html.to_s
fail "script/img survived: #{html}" if html.match?(/<script|<img|onerror/)
fail "link rel missing" unless html.include?('rel="nofollow ugc noopener"')
fail "status_id" unless MastodonReplies.status_id("https://mastodon.social/@a/123") == "123" && MastodonReplies.status_id("javascript:1").nil?
post.mastodon_replies = false
fail "disabled post still shows replies" if MastodonReplies.for(post).any?
puts "mastodon replies OK"
