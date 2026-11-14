class Post < ApplicationRecord
  CATEGORIES = {
    "informatics" => "Clinical informatics",
    "ai"          => "AI in healthcare",
    "medicine"    => "Hospital medicine",
    "notes"       => "Notes",
    "homelab"     => "Homelab & tinkering",
    "leadership"  => "Leadership & business",
    "projects"    => "Projects"
  }.freeze

  ALLOWED_TAGS = %w[p br h2 h3 h4 strong em s u code pre blockquote ul ol li a img hr table thead tbody tr th td
                    aside details summary div span mark sup sub figure figcaption].freeze
  ALLOWED_ATTRS = %w[href src alt title class id data-type data-kind data-cite data-locator open colspan rowspan target rel].freeze

  has_many :comments, dependent: :destroy
  has_many :revisions, -> { order(created_at: :desc) }, class_name: "PostRevision", dependent: :delete_all

  attr_accessor :revision_editor   # who made this change ("admin", "api:Hermes", "obsidian")
  before_update :snapshot_revision, if: -> { will_save_change_to_body? || will_save_change_to_title_html? || will_save_change_to_title? || will_save_change_to_excerpt? }
  after_save :reindex_search!
  after_destroy { self.class.connection.exec_delete("DELETE FROM post_search WHERE rowid = ?", "fts", [id]) }

  # ---- Full-text search (SQLite FTS5) ------------------------------------
  def reindex_search!
    c = self.class.connection
    c.exec_delete("DELETE FROM post_search WHERE rowid = ?", "fts", [id])
    c.exec_insert("INSERT INTO post_search(rowid, title, body, tags) VALUES (?, ?, ?, ?)", "fts", [id, title.to_s, plain_text, tags.to_s])
  end

  # Returns [[post, snippet_html], ...] for published posts, best match first.
  def self.search(q, limit: 30)
    terms = q.to_s.scan(/[\p{L}\p{N}]+/).first(8)
    return [] if terms.empty?
    match = terms.map { |t| %("#{t}"*) }.join(" ")
    rows = connection.select_rows(<<~SQL, "fts", [match, limit * 2])
      SELECT rowid, snippet(post_search, 1, '[[[', ']]]', '…', 18) FROM post_search
      WHERE post_search MATCH ? ORDER BY bm25(post_search, 10.0, 1.0, 5.0) LIMIT ?
    SQL
    posts = published.where(id: rows.map(&:first)).index_by(&:id)
    rows.filter_map { |id, snip| (p = posts[id]) && [p, ERB::Util.h(snip).gsub("[[[", "<mark>").gsub("]]]", "</mark>").html_safe] }.first(limit)
  end

  validates :title, :body, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :category, inclusion: { in: CATEGORIES.keys }, allow_blank: true
  TITLE_TAGS = %w[strong em u s code a mark sup sub].freeze
  before_validation :normalize_title
  before_validation { self.category = category.presence; self.tags = tags.presence; self.excerpt = excerpt.presence }
  before_validation { self.slug = (slug.presence || title).to_s.parameterize }

  # Rich title (bold/italic/code/links). `title` stays plain text for <title>, SEO, RSS, URLs.
  def display_title
    html = title_html.presence || ERB::Util.h(title)
    ActionController::Base.helpers.sanitize(html, tags: TITLE_TAGS, attributes: %w[href]).html_safe
  end

  scope :published, -> { where.not(published_at: nil).where(published_at: ..Time.current).order(published_at: :desc) }
  scope :in_category, ->(c) { c.present? ? where(category: c) : all }

  def published? = published_at.present? && published_at <= Time.current
  def to_param = slug
  def category_name = CATEGORIES[category]
  def tag_list = tags.to_s.split(",").map(&:strip).reject(&:blank?)
  # Text as written (citations as [@key]); used for revision diffs.
  def source_text = Nokogiri::HTML.fragment(body.to_s).xpath(".//text()").map(&:text).join(" ").squish
  def plain_text = Nokogiri::HTML.fragment(rendered_html).xpath(".//text()").map(&:text).join(" ").squish
  def reading_minutes = [(plain_text.split.size / 220.0).ceil, 1].max
  def description = excerpt.presence || plain_text.truncate(155)
  def updated_or_published = [updated_at, published_at].compact.max

  # Comments
  def comments_open? = comments_enabled && (comments_open_at.nil? || comments_open_at <= Time.current)
  def comments_pending_open? = comments_enabled && comments_open_at&.future?

  # Body: Tiptap HTML (legacy Markdown still supported). Returns [html, toc]
  def rendered_html = processed.first
  def toc = processed.last
  def cited_references = (processed; @cited || [])
  def citation_keys = Reference.keys_in(body)

  # Pull any newly cited papers from Zotero when a post is saved (best effort).
  after_save :sync_missing_references, if: -> { saved_change_to_body? }
  def missing_citation_keys = citation_keys.reject { Reference.lookup(_1) }

  private def sync_missing_references
    return unless ZoteroLibrary.configured? && missing_citation_keys.any?
    ZoteroLibrary.sync!
  rescue ZoteroLibrary::Error => e
    Rails.logger.warn("[zotero] #{e.message}")
  end
  public

  private

  def snapshot_revision
    revisions.create!(title: title_was, title_html: title_html_was, body: body_was, excerpt: excerpt_was,
                      editor: revision_editor.presence || "admin")
    revisions.offset(100).delete_all if revisions.count > 100   # keep the last 100 versions
  end

  def normalize_title
    return if title_html.blank?
    self.title_html = title_html.to_s.strip.sub(/\A<p>(.*)<\/p>\z/m, '\\1')
    plain = Nokogiri::HTML.fragment(title_html).text.squish
    self.title = plain if plain.present?
  end

  def processed
    @processed ||= begin
      raw = body.to_s.lstrip.start_with?("<") ? body.to_s : markdown(body.to_s)
      clean = ActionController::Base.helpers.sanitize(raw, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRS)
      doc = Nokogiri::HTML.fragment(clean)
      @cited = apply_citations(doc)
      toc, used = [], Hash.new(0)
      doc.css("h2, h3").each do |h|
        plain = h.dup.tap { |c| c.css("sup.cites, .cite-missing").remove }.text.strip
        base = plain.parameterize.presence || "section"
        id = used[base].zero? ? base : "#{base}-#{used[base]}"
        used[base] += 1
        h["id"] = id
        toc << { id:, text: plain, level: h.name == "h2" ? 2 : 3 }
      end
      doc.css("a[href^='http']").each { |a| a["rel"] = "noopener"; a["target"] = "_blank" }
      [doc.to_html.html_safe, toc]
    end
  end

  # [@key] / [@a; @b, p. 4] -> numbered superscripts + a References section (order of first citation)
  def apply_citations(doc)
    return [] unless doc.text.include?("@")
    doc.css("span[data-cite]").each { |sp| sp.replace(Nokogiri::XML::Text.new(sp.text, doc.document)) }
    merged = doc.to_html
    loop { nxt = merged.gsub(/(\[-?@[^\]\[]*)\][[:space:]\u00A0]*(?:&nbsp;)?[[:space:]\u00A0]*\[(-?@)/, '\\1; \\2'); break if nxt == merged; merged = nxt }
    doc.children.each(&:remove); doc.add_child(Nokogiri::HTML.fragment(merged))
    order, refs = [], {}
    doc.xpath(".//text()[not(ancestor::code) and not(ancestor::pre) and not(ancestor::a)]").each do |node|
      next unless node.text.match?(Reference::CITE)
      html = ERB::Util.h(node.text).gsub(/\[((?:-?@[^\]]+))\]/) do
        whole = $&
        parts = CGI.unescapeHTML($1).split(";").map(&:strip)
        cites = parts.filter_map do |part|
          m = part.match(/\A-?@([\w:.#$%&\-+?<>~\/]+?)[.,]?(?:,\s*(.+))?\z/) or next
          key, locator = m[1], m[2]
          ref = refs[key] ||= Reference.lookup(key)
          next %(<span class="cite-missing" title="Not found in Zotero — sync or check the key">@#{ERB::Util.h(key)}?</span>) unless ref
          order << key unless order.include?(key)
          n = order.index(key) + 1
          label = locator ? "#{n} (#{ERB::Util.h(locator)})" : n.to_s
          %(<a href="#ref-#{n}" class="cite" title="#{ERB::Util.h("#{ref.short_label} — #{ref.title}")}">#{label}</a>)
        end
        cites.empty? ? whole : %(<sup class="cites">[#{cites.join(", ")}]</sup>)
      end
      node.replace(Nokogiri::HTML.fragment(html))
    end
    return [] if order.empty?
    items = order.each_with_index.map do |key, i|
      r = refs[key]
      frag = Nokogiri::HTML.fragment(r.safe_bib.to_s)
      frag.css(".csl-left-margin").remove
      body = (frag.at_css(".csl-right-inline") || frag.at_css(".csl-entry"))&.inner_html&.strip.presence ||
             ERB::Util.h("#{r.authors.to_s.split(";").first(3).join(";")}. #{r.title}. #{r.year}.")
      body = body.sub(/\A\s*\d+\.\s*/, "")
      link = r.link ? %( <a class="ref-link" href="#{ERB::Util.h(r.link)}" rel="noopener" target="_blank" title="Open source">[↗]</a>) : ""
      %(<li id="ref-#{i + 1}"><span class="ref-body">#{body}</span>#{link} <a class="ref-back" href="#" onclick="history.back();return false" title="Back to text">↩</a></li>)
    end
    doc.add_child(%(<h2>References</h2><ol class="references">#{items.join}</ol>))
    order.map { refs[_1] }
  end

  def markdown(src)
    r = Redcarpet::Render::HTML.new(safe_links_only: true)
    Redcarpet::Markdown.new(r, autolink: true, tables: true, fenced_code_blocks: true, strikethrough: true).render(src)
  end
end
