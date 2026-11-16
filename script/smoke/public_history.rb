# CI smoke: only text that was live becomes public history; draft text never does.
# Run with: bin/rails runner script/smoke/public_history.rb
Post.where(slug: "smoke-history").destroy_all
p = Post.create!(title: "Smoke history", slug: "smoke-history", body: "<p>draft only text</p>")
p.update!(body: "<p>first live text</p>", published_at: 1.minute.ago)   # published in the same save: snapshot is draft text
p.update!(body: "<p>second live text</p>")                               # snapshot of first live text: public
p.change_kind = "correction"; p.change_note = "Fixed a <b>number</b>."
p.update!(body: "<p>third live text</p>")
revs = p.revisions.reorder(:created_at).to_a
fail "expected 3 revisions, got #{revs.size}" unless revs.size == 3
fail "draft text became public" if revs[0].public || PostRevision.shown.where(post: p).any? { _1.plain_text.include?("draft only") }
fail "live text not public" unless revs[1].public && revs[2].public
fail "correction note missing" unless revs[2].change_kind == "correction" && revs[2].change_note.include?("number")
puts "public history OK (#{p.slug})"
