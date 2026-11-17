# CI smoke: a citation's supporting passage reaches the reader escaped, and only on the cite it belongs to.
# Run with: bin/rails runner script/smoke/citation_evidence.rb
Reference.find_or_create_by!(citekey: "smoke-ev-a") { |r| r.title = "Smoke A"; r.authors = "Smoke, A"; r.year = "2020" }
Reference.find_or_create_by!(citekey: "smoke-ev-b") { |r| r.title = "Smoke B"; r.authors = "Smoke, B"; r.year = "2021" }
body = <<~HTML
  <p>One <span data-cite="smoke-ev-a" data-locator="p. 4" data-evidence="Fell by 12% &lt;script&gt;alert(1)&lt;/script&gt;">[@smoke-ev-a, p. 4]</span>
  two <span data-cite="smoke-ev-b">[@smoke-ev-b]</span>
  three <span data-cite="smoke-ev-a" data-locator="p. 9">[@smoke-ev-a, p. 9]</span></p>
HTML
html = Post.new(title: "smoke", body:).rendered_html.to_s
cites = Nokogiri::HTML.fragment(html).css("a.cite")
fail "expected 3 cites, got #{cites.size}" unless cites.size == 3
fail "evidence missing on first cite" unless cites[0]["data-evidence"].to_s.start_with?("Fell by 12%")
fail "evidence leaked to other cites" if cites[1]["data-evidence"] || cites[2]["data-evidence"]
fail "unescaped markup in output" if html.include?("<script")
puts "citation evidence OK"
