# Converts an Obsidian note (frontmatter + Obsidian-flavored Markdown) into post attributes + HTML.
class ObsidianMarkdown
  CALLOUTS = { "note" => "note", "info" => "note", "abstract" => "tldr", "summary" => "tldr", "tldr" => "tldr",
               "tip" => "tip", "hint" => "tip", "important" => "tip", "success" => "tip",
               "warning" => "warning", "caution" => "warning", "danger" => "warning", "attention" => "warning", "bug" => "warning",
               "pearl" => "pearl", "example" => "pearl", "quote" => "note", "question" => "note", "faq" => "note",
               "definition" => "definition", "todo" => "note", "failure" => "warning" }.freeze

  attr_reader :frontmatter, :body

  def initialize(text)
    text = text.to_s.sub(/\A﻿/, "")
    if (m = text.match(/\A---\s*\n(.*?)\n---\s*\n?/m))
      @frontmatter = (YAML.safe_load(m[1], permitted_classes: [Date, Time]) || {}) rescue {}
      @body = m.post_match
    else
      @frontmatter, @body = {}, text
    end
  end

  def to_html
    md = body.dup
    md.gsub!(/%%.*?%%/m, "")                                   # Obsidian comments
    md.gsub!(/\[\[@([^\]|]+)(?:\|[^\]]*)?\]\]/) { "[@#{$1.strip}]" }  # Citations plugin style [[@key]]
    md.gsub!(/!\[\[([^\]]+)\]\]/) { "*[embed: #{$1}]*" }       # embeds (images/notes) — not uploaded
    md.gsub!(/\[\[([^\]|#]+)(?:#([^\]|]+))?(?:\|([^\]]+))?\]\]/) do
      target, heading, label = $1.strip, $2, $3
      slug = target.parameterize
      text = label || target
      Post.published.exists?(slug: slug) ? "[#{text}](/blog/#{slug}#{heading ? "##{heading.parameterize}" : ""})" : text
    end
    md.gsub!(/(?<![=\w])==([^=\n]+)==(?!=)/, '<mark>\1</mark>')
    md.gsub!(/(^|\s)#([A-Za-z][\w\/-]*)/) { $1 }                # strip inline #tags (they become post tags)
    html = render(md)
    html = convert_callouts(html)
    html.sub(/\A\s*<h1>.*?<\/h1>\s*/m, "")                     # title comes from frontmatter/filename
  end

  def first_h1 = body[/^#\s+(.+)$/, 1]&.strip
  def inline_tags = body.scan(/(?:^|\s)#([A-Za-z][\w\/-]*)/).flatten.uniq

  private

  def render(md)
    r = Redcarpet::Render::HTML.new(safe_links_only: true)
    Redcarpet::Markdown.new(r, autolink: true, tables: true, fenced_code_blocks: true, strikethrough: true,
                               no_intra_emphasis: true, lax_spacing: true).render(md)
  end

  # <blockquote><p>[!tip] Title\nbody</p>...</blockquote>  ->  <aside class="callout" data-kind="tip">
  def convert_callouts(html)
    doc = Nokogiri::HTML.fragment(html)
    doc.css("blockquote").each do |bq|
      first = bq.at_css("p") or next
      m = first.inner_html.match(/\A\s*\[!(\w+)\]([+-]?)[ \t]*([^\n<]*)(?:\n|<br>)?/) or next
      kind = CALLOUTS[m[1].downcase] || "note"
      fold, title = m[2], m[3].strip
      first.inner_html = m.post_match
      first.remove if first.inner_html.strip.empty?
      if fold.present?
        node = Nokogiri::XML::Node.new("details", doc)
        node["open"] = "open" if fold == "+"
        node.add_child("<summary>#{ERB::Util.h(title.presence || m[1].capitalize)}</summary><div class=\"details-body\">#{bq.inner_html}</div>")
      else
        node = Nokogiri::XML::Node.new("aside", doc)
        node["class"] = "callout"; node["data-kind"] = kind
        node.add_child("<p><strong>#{ERB::Util.h(title)}</strong></p>") if title.present?
        node.add_child(bq.inner_html)
      end
      bq.replace(node)
    end
    doc.to_html
  end
end
