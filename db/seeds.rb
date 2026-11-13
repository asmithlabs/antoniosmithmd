# Starter DRAFTS — outlines for Antonio to write. None are published.
def outline(*sections, intro:, tldr: nil, extra: "")
  html = +"<p><em>[Draft outline — replace with your own words.]</em> #{intro}</p>"
  html << %(<aside class="callout" data-kind="tldr"><ul>#{tldr.map { "<li><p>#{_1}</p></li>" }.join}</ul></aside>) if tldr
  sections.each do |h2, bullets|
    html << "<h2>#{h2}</h2>"
    html << "<ul>#{bullets.map { "<li><p>#{_1}</p></li>" }.join}</ul>" if bullets
  end
  html << extra
end

[
  { slug: "how-i-stumbled-into-clinical-informatics", category: "informatics", tags: "career, fellowship, regenstrief",
    title: "How I stumbled into clinical informatics",
    excerpt: "From the hospitalist workroom to an informatics fellowship: why impact at scale and good problems pulled me in.",
    body: outline(["The moment it clicked", ["The workflow problem that wouldn't leave me alone"]],
                  ["Bedside vs. at scale", ["One patient at a time vs. thousands at once"]],
                  ["Why Regenstrief / IU", nil], ["Advice for clinicians curious about informatics", nil],
                  intro: "Origin story.", tldr: ["What drew me in", "What the fellowship looks like", "How to explore the field"]) },
  { slug: "cutting-discharge-summaries-in-half", category: "informatics", tags: "documentation, epic, quality improvement",
    title: "Cutting discharge summaries in half",
    excerpt: "How we reduced discharge summary length by 50% — and why shorter notes were better notes.",
    body: outline(["The problem", ["Note bloat; what receiving clinicians actually read"]],
                  ["What we changed", ["Template edits", "Smart links / auto-pulled data"]],
                  ["Results", ["50% reduction", "Feedback from PCPs"]], ["Lessons", nil],
                  intro: "QI case study.",
                  extra: %(<aside class="callout" data-kind="pearl"><p>The best note is the one the next clinician actually reads.</p></aside>)) },
  { slug: "risk-tiering-clinical-ai-with-chai", category: "ai", tags: "ai governance, chai, ambient documentation",
    title: "Risk-tiering clinical AI: field notes on the CHAI framework",
    excerpt: "What I learned applying the Coalition for Health AI risk categorization to ambient documentation, summaries and CDS.",
    body: outline(["Why risk-tier at all", nil], ["The framework in brief", ["Patient safety vs. technology/data domains", "Risk modifiers"]],
                  ["Applying it: three use cases", ["Ambient documentation", "Automated clinical summaries", "Clinical decision support"]],
                  ["Mitigations that kept coming up", ["Clinician oversight", "Monitoring", "Data quality"]], ["Open questions", nil],
                  intro: "Governance in practice.") },
  { slug: "prompt-design-for-patient-messages", category: "ai", tags: "generative ai, epic, in-basket",
    title: "Designing modular prompts for AI-drafted patient messages",
    excerpt: "Notes on building safe, structured prompts for in-basket message drafts inside Epic.",
    body: outline(["Why modular prompts", nil], ["Message categories", ["Medications", "Results", "Referrals", "Scheduling"]],
                  ["Safety rails", ["Escalation conditions", "Formatting", "What the model should never do"]],
                  intro: "Prompt engineering meets clinical workflow.",
                  extra: %(<aside class="callout" data-kind="warning"><p>Drafts are drafts: a clinician reviews every message before it is sent.</p></aside>)) },
  { slug: "computational-phenotyping-notes", category: "notes", tags: "phenotyping, research, heat illness",
    title: "Notes: computational phenotyping 101",
    excerpt: "Working notes on building EHR phenotypes from codes, labs and meds — using heat-related illness as the example.",
    body: outline(["What a phenotype is", nil], ["Ingredients", ["Diagnosis codes", "Lab findings", "Medications"]],
                  ["Validation", nil], ["References", nil],
                  intro: "Learning in public.",
                  extra: %(<aside class="callout" data-kind="definition"><p><strong>Computational phenotype:</strong> a reproducible rule set that identifies patients with a condition from EHR data.</p></aside>)) },
  { slug: "homelab-self-hosted-chief-of-staff", category: "projects", tags: "truenas, docker, hermes, self-hosting",
    title: "My homelab: TrueNAS, Docker and a self-hosted AI chief of staff",
    excerpt: "The hardware, the stack, and why a physician runs his own servers.",
    body: outline(["The hardware", nil], ["The stack", ["TrueNAS SCALE", "Docker", "Ollama"]], ["Hermes", nil], ["What broke", nil],
                  intro: "Tinkering log.",
                  extra: %(<details open><summary>Full parts list</summary><div class="details-body"><p>…</p></div></details>)) },
  { slug: "what-an-mba-taught-a-hospitalist", category: "leadership", tags: "mba, kelley, leadership",
    title: "What an MBA taught a hospitalist",
    excerpt: "Finance, operations and strategy from Kelley — and how they changed how I see the hospital.",
    body: outline(["Why an MBA", nil], ["Three lessons that transfer to medicine", nil], ["Medical director years", nil], intro: "Business of medicine.") },
].each do |attrs|
  Post.find_or_create_by!(slug: attrs[:slug]) { |p| p.assign_attributes(attrs.merge(published_at: nil)) }
end
Post.find_by(slug: "welcome")&.destroy
puts "Seeded #{Post.count} posts (drafts)."
