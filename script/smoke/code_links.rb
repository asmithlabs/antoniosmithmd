# CI smoke: post code links are classified, https-only, capped, and taken from Obsidian frontmatter.
# Also gives the first seed post some links so the page check that follows renders the box.
# Run with: bin/rails runner script/smoke/code_links.rb
links = CodeLink.parse_all(<<~T)
  https://github.com/example/repo
  https://github.com/example/repo/commit/abc1234def
  Design doc | https://github.com/example/repo/blob/main/docs/a.md
  https://example.org/app/
T
fail "kinds wrong: #{links.map(&:kind)}" unless links.map(&:kind) == %w[repo commit file link]
fail "label wrong" unless links[2].label == "Design doc" && links[1].label.end_with?("@ abc1234")
%w[http://example.org javascript:alert(1)].each do |bad|
  fail "accepted #{bad}" if Post.new(title: "x", code_links: bad).valid?
end
fail "cap not enforced" if Post.new(title: "x", code_links: (["https://a.org"] * 9).join("\n")).valid?
note = ObsidianMarkdown.new("---\ntitle: T\ncode:\n  - https://github.com/example/repo\nrepo: https://github.com/example/other\n---\nbody")
fm = note.frontmatter.transform_keys(&:to_s)
fail "frontmatter keys" unless (Array(fm["code"]) + Array(fm["repo"])).size == 2
Post.first.update!(code_links: "https://github.com/example/repo\nLive <b>app</b> | https://example.org/app")
fail "seed links not saved" unless Post.first.code_link_list.size == 2
puts "code links OK"
