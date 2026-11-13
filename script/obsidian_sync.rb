#!/usr/bin/env ruby
# Sync notes from an Obsidian vault folder to the blog. Ruby stdlib only — no gems needed.
#
#   BLOG_URL=https://antoniosmithmd.com BLOG_TOKEN=asm_... ruby obsidian_sync.rb ~/Vault/Blog [--dry-run]
#
# Each .md file becomes a post. Slug = frontmatter `slug` or the filename.
#   publish: true   -> published (date: from frontmatter if set)
#   otherwise       -> draft (edit/publish later at /admin)
#   blog: false     -> skipped
# Only changed files are sent (tracked in .blog-sync.json inside the folder).
require "net/http"
require "json"
require "digest"
require "uri"
require "yaml"

dir = ARGV.find { !_1.start_with?("--") } or abort "usage: obsidian_sync.rb <vault-folder> [--dry-run] [--force]"
dry, force = ARGV.include?("--dry-run"), ARGV.include?("--force")
base = ENV.fetch("BLOG_URL") { abort "set BLOG_URL" }.chomp("/")
token = ENV.fetch("BLOG_TOKEN") { abort "set BLOG_TOKEN" }
state_file = File.join(dir, ".blog-sync.json")
state = File.exist?(state_file) ? JSON.parse(File.read(state_file)) : {}

def slugify(s) = s.downcase.gsub(/['’]/, "").gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")

sent = skipped = failed = 0
Dir.glob(File.join(dir, "**/*.md")).sort.each do |path|
  rel = path.delete_prefix(dir).delete_prefix("/")
  raw = File.read(path)
  fm = raw[/\A---\s*\n(.*?)\n---/m, 1].then { _1 ? (YAML.safe_load(_1, permitted_classes: [Date, Time]) rescue {}) : {} } || {}
  next skipped += 1 if fm["blog"] == false
  digest = Digest::SHA256.hexdigest(raw)
  next skipped += 1 if !force && state[rel] == digest
  slug = slugify(fm["slug"] || File.basename(path, ".md"))
  if dry
    puts "would send  #{rel} -> /blog/#{slug} (#{fm["publish"] == true ? "publish" : "draft"})"
    next
  end
  uri = URI("#{base}/api/v1/posts/#{slug}")
  req = Net::HTTP::Put.new(uri, "Authorization" => "Bearer #{token}", "Content-Type" => "application/json")
  req.body = JSON.generate(obsidian: raw, source_path: rel)
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { _1.request(req) }
  if res.is_a?(Net::HTTPSuccess)
    j = JSON.parse(res.body)
    puts "#{j["status"].ljust(10)} #{rel} -> #{j["url"] || j["edit_url"]}"
    state[rel] = digest; sent += 1
  else
    warn "FAILED     #{rel}: #{res.code} #{res.body}"; failed += 1
  end
end
File.write(state_file, JSON.pretty_generate(state)) unless dry
puts "done: #{sent} sent, #{skipped} unchanged/skipped, #{failed} failed"
exit(failed.zero? ? 0 : 1)
