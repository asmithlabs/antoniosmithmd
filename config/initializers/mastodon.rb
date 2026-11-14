# Every 5 minutes (in the web server process only), share posts that have gone live — including
# scheduled posts once their time arrives. Shares happen at most once per post.
if defined?(Rails::Server) || ENV["MASTODON_SCHEDULER"] == "1"
  Rails.application.config.after_initialize do
    next unless MastodonSyndication.configured?
    Concurrent::TimerTask.new(execution_interval: 300, run_now: true) {
      Rails.application.executor.wrap { MastodonSyndication.share_due! }
    }.execute
  end
end
