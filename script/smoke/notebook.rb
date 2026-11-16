# CI smoke: notebook stages, open questions, frontmatter mapping, and the /notebook listing query.
# Also turns the first seed post into a working note so the page checks that follow render it.
# Run with: bin/rails runner script/smoke/notebook.rb
fail "bad stage accepted" if Post.new(title: "x", notebook_stage: "rotten").valid?
p = Post.new(title: "x", notebook_stage: "", questions: "  Q1?\n\n Q2? \n")
p.valid?
fail "blank stage should be nil" unless p.notebook_stage.nil? && p.question_list == ["Q1?", "Q2?"]
fm = ObsidianMarkdown.new("---\ntitle: T\nstage: Seedling\nquestions:\n  - Does it hold?\n---\nbody").frontmatter.transform_keys(&:to_s)
fail "frontmatter" unless (fm["stage"] || fm["maturity"]).to_s.downcase == "seedling" && Array(fm["questions"]) == ["Does it hold?"]
seed = Post.first
seed.update!(notebook_stage: "growing", questions: "Does this generalize?\nWhat would falsify it?")
seed.update!(published_at: 1.hour.ago) unless seed.published?
fail "notebook scope" unless Post.notebook.include?(seed)
puts "notebook OK"
