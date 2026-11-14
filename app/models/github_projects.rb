require "net/http"

# Public GitHub repos tagged with a topic (default "portfolio") for the Projects section.
# Unauthenticated by design: only PUBLIC repos can ever appear, even if a private repo has the topic.
# Cached 1 hour; if GitHub is unreachable the last good list is shown (kept 30 days).
class GithubProjects
  Repo = Struct.new(:name, :full_name, :description, :url, :homepage, :language, :stars, :pushed_at, :topics, keyword_init: true)

  def self.owners = Array(SITE.dig(:github, :owners)).presence || ["asmithlabs"]
  def self.topic  = SITE.dig(:github, :topic).presence || "portfolio"

  def self.all
    Rails.cache.fetch(["github-projects/v1", owners, topic], expires_in: 1.hour) { fetch! }
  rescue StandardError => e
    Rails.logger.warn("[github] #{e.class}: #{e.message}")
    Rails.cache.read(["github-projects/last-good", owners, topic]) || []
  end

  def self.fetch!
    q = (["topic:#{topic}", "archived:false", "is:public"] + owners.map { "user:#{_1}" }).join(" ")
    uri = URI("https://api.github.com/search/repositories")
    uri.query = URI.encode_www_form(q:, sort: "updated", per_page: 30)
    req = Net::HTTP::Get.new(uri, "Accept" => "application/vnd.github+json", "User-Agent" => "antoniosmithmd.com")
    req["Authorization"] = "Bearer #{ENV["GITHUB_TOKEN"]}" if ENV["GITHUB_TOKEN"].present?
    res = Net::HTTP.start(uri.host, 443, use_ssl: true, open_timeout: 4, read_timeout: 8) { _1.request(req) }
    raise "GitHub API #{res.code}" unless res.is_a?(Net::HTTPSuccess)
    repos = JSON.parse(res.body).fetch("items", []).reject { _1["private"] || _1["fork"] }.map { |r|
      Repo.new(name: r["name"], full_name: r["full_name"], description: r["description"], url: r["html_url"],
               homepage: r["homepage"].presence, language: r["language"], stars: r["stargazers_count"],
               pushed_at: Time.zone.parse(r["pushed_at"].to_s), topics: Array(r["topics"]) - [topic])
    }
    Rails.cache.write(["github-projects/last-good", owners, topic], repos, expires_in: 30.days)
    repos
  end
end
