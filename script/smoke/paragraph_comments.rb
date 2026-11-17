# CI smoke: passages get stable ids; a comment anchors only to a real passage, quotes it from the
# server's copy, and replies never anchor.
# Run with: bin/rails runner script/smoke/paragraph_comments.rb
Post.where(slug: "smoke-para").destroy_all
post = Post.create!(title: "Para", slug: "smoke-para", published_at: 1.hour.ago, comments_enabled: true,
  body: %(<p>This is the first passage that is long enough.</p><ul><li><p>A list item paragraph long enough too.</p></li></ul><p>short</p><p>This is the first passage that is long enough.</p>))
paras = post.paragraphs
fail "expected 3 passages (short one skipped, duplicate suffixed), got #{paras.keys}" unless paras.size == 3 && paras.keys.last.end_with?("-1")
fail "ids not in html" unless paras.keys.all? { post.rendered_html.include?(%(id="#{_1}")) }
id = paras.keys.first
c1 = post.comments.create!(author_name: "A", body: "on passage", anchor: id)
c2 = post.comments.create!(author_name: "B", body: "made-up anchor", anchor: "para-deadbeef", anchor_text: "fake quote")
c3 = post.comments.create!(author_name: "C", body: "reply", parent: c1, anchor: id)
fail "anchor not kept" unless c1.anchor == id && c1.anchor_text.start_with?("This is the first")
fail "made-up anchor kept" if c2.anchor || c2.anchor_text
fail "reply anchored" if c3.anchor
post.update!(body: "<p>This passage was rewritten so its id changes.</p>")
fail "edited passage should no longer be current" if Post.find(post.id).comments.find(c1.id).anchor_current?(Post.find(post.id).paragraphs)
post.destroy
puts "paragraph comments OK"
