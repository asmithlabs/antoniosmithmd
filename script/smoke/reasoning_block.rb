# CI smoke: "Follow the reasoning" blocks render collapsed, drop empty template sections,
# and Obsidian's > [!reasoning] callout produces the same block.
# Run with: bin/rails runner script/smoke/reasoning_block.rb
body = %(<details class="reasoning" data-type="reasoning" open="open"><summary>Follow the reasoning</summary><div class="details-body">) +
       %(<h4>Conclusion</h4><p>X causes Y</p><h4>Evidence</h4><ul><li><p>Trial A</p></li></ul><h4>Assumptions</h4><ul><li><p></p></li></ul><h4>Confidence</h4><p></p></div></details>) +
       %(<details open="open"><summary>Plain</summary><div class="details-body"><p>stays open</p></div></details>)
doc = Nokogiri::HTML.fragment(Post.new(title: "t", body:).rendered_html.to_s)
r = doc.at_css("details.reasoning") or fail "reasoning block missing"
fail "reasoning block should be collapsed" if r["open"]
fail "empty sections not dropped: #{r.css("h4").map(&:text)}" unless r.css("h4").map(&:text) == %w[Conclusion Evidence]
fail "plain details lost its open state" unless doc.css("details")[1]["open"]
empty = %(<details class="reasoning"><summary>Follow the reasoning</summary><div class="details-body"><h4>Evidence</h4><ul><li><p></p></li></ul></div></details>)
fail "empty reasoning block not removed" if Nokogiri::HTML.fragment(Post.new(title: "t", body: empty).rendered_html.to_s).at_css("details")
md = ObsidianMarkdown.new("> [!reasoning] Why I think so\n> #### Evidence\n> - A\n").to_html
fail "obsidian callout: #{md}" unless md.include?('class="reasoning"') && md.include?("Why I think so")
puts "reasoning block OK"
