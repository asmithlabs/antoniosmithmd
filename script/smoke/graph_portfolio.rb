# CI smoke: listed portfolio projects join the knowledge graph; hidden ones never do.
# Run with: bin/rails runner script/smoke/graph_portfolio.rb
PortfolioProject.where(slug: %w[smoke-kg smoke-kg-hidden]).delete_all
shown = PortfolioProject.create!(slug: "smoke-kg", name: "Smoke KG", status: "active", domain: "medicine",
                                 stack: "rails", repo_url: "https://github.com/example/smoke-kg", position: 0)
PortfolioProject.create!(slug: "smoke-kg-hidden", name: "Hidden", status: "active", hidden: true, position: 0)
a = Post.new(id: 900_001, slug: "smoke-kg-a", title: "A", tags: "medicine",
             body: %(<p><a href="/projects#smoke-kg">card</a> <a href="https://github.com/example/smoke-kg/">repo</a> <a href="/projects#smoke-kg-hidden">h</a></p>))
b = Post.new(id: 900_002, slug: "smoke-kg-b", title: "B", tags: "rails", body: "<p>none</p>")
g = KnowledgeGraph.new([a, b], PortfolioProject.listed.ordered.to_a)
j = g.as_json
fail "project node missing" unless j[:nodes].any? { _1[:id] == "pf:smoke-kg" && _1[:type] == "project" }
fail "hidden project leaked" if j[:nodes].any? { _1[:id] == "pf:smoke-kg-hidden" }
fail "post→project link missing" unless j[:edges].include?({ s: "p:smoke-kg-a", t: "pf:smoke-kg", kind: "link" })
fail "topic edges wrong" unless j[:edges].count { _1[:s] == "pf:smoke-kg" && _1[:kind] == "tag" } == 2
fail "projects_for wrong" unless g.projects_for(a) == [shown] && g.projects_for(b).empty?
fail "posts_about wrong" unless g.posts_about(shown).map(&:slug) == ["smoke-kg-a"]
PortfolioProject.where(slug: %w[smoke-kg smoke-kg-hidden]).delete_all
puts "graph portfolio OK"
