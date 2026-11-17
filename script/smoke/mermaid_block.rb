# CI smoke: mermaid fences (editor and Markdown) become a figure with the source as text and an
# optional caption; the editorial review flags a diagram without one; the pinned bundle is present.
# Run with: bin/rails runner script/smoke/mermaid_block.rb
editor = %(<pre><code class="language-mermaid">%% caption: Flow\nflowchart LR\n  A --> B</code></pre><pre><code class="language-mermaid">flowchart LR\n  X --> Y</code></pre>)
post = Post.new(title: "m", body: editor)
figs = Nokogiri::HTML.fragment(post.rendered_html.to_s).css("figure.mermaid-figure")
fail "expected 2 figures, got #{figs.size}" unless figs.size == 2
fail "source not kept as text" unless figs[0].at_css('pre[data-type="mermaid"]').text.include?("A --> B")
fail "caption" unless figs[0].at_css("figcaption")&.text == "Flow" && figs[1].at_css("figcaption").nil?
fail "review should flag 1 uncaptioned diagram" unless PostReview.new(post).issues.count { _1.code == "diagram_without_caption" } == 1
md = Post.new(title: "m", body: ObsidianMarkdown.new("```mermaid\nsequenceDiagram\n  A->>B: hi\n```\n").to_html)
fail "markdown fence" unless md.rendered_html.to_s.include?('data-type="mermaid"')
plain = Post.new(title: "m", body: %(<pre><code class="language-ruby">puts 1</code></pre>))
fail "other code blocks must not change" if plain.rendered_html.to_s.include?("mermaid")
fail "pinned bundle missing" unless File.size?(Rails.root.join("public/js/vendor/mermaid-11.17.2.min.js")).to_i > 1_000_000
puts "mermaid block OK"
