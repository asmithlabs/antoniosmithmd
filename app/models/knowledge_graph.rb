# Connections between published posts, the papers they cite, and tags — derived from content, nothing stored.
class KnowledgeGraph
  WEIGHTS = { link: 4, citation: 3, tag: 2, category: 1 }.freeze

  def self.current
    posts = Post.published
    key = ["kg/v1", posts.maximum(:updated_at)&.to_i, posts.count, Reference.maximum(:updated_at)&.to_i]
    Rails.cache.fetch(key) { new(posts.to_a) }
  end

  attr_reader :posts

  def initialize(posts)
    @posts = posts
    by_slug = posts.index_by(&:slug)
    @links = posts.to_h { |p| [p.id, internal_slugs(p).filter_map { by_slug[_1]&.id }.uniq - [p.id]] }
    @refs  = posts.to_h { |p| [p.id, p.cited_references.map { _1.citekey }] }
    @tags  = posts.to_h { |p| [p.id, p.tag_list.map(&:downcase)] }
    @ref_info = Reference.where(citekey: @refs.values.flatten.uniq).index_by(&:citekey)
  end

  # Ranked related posts with the reasons they're related.
  def related(post, limit: 5)
    others = posts.reject { _1.id == post.id }
    others.filter_map { |o|
      shared_refs = @refs[post.id].to_a & @refs[o.id].to_a
      shared_tags = @tags[post.id].to_a & @tags[o.id].to_a
      linked = @links[post.id].to_a.include?(o.id) || @links[o.id].to_a.include?(post.id)
      score = shared_refs.size * WEIGHTS[:citation] + shared_tags.size * WEIGHTS[:tag] +
              (linked ? WEIGHTS[:link] : 0) + (post.category.present? && post.category == o.category ? WEIGHTS[:category] : 0)
      next if score.zero?
      why = []
      why << "linked" if linked
      why << "#{shared_refs.size} shared #{"source".pluralize(shared_refs.size)}" if shared_refs.any?
      why << "tags: #{shared_tags.join(", ")}" if shared_tags.any?
      why << "same category" if why.empty?
      [o, score, why.join(" · ")]
    }.sort_by { -_2 }.first(limit)
  end

  def backlinks(post) = posts.select { @links[_1.id].to_a.include?(post.id) }

  # Nodes + edges for the graph page.
  def as_json(*)
    nodes, edges = [], []
    posts.each do |p|
      nodes << { id: "p:#{p.slug}", type: p.category == "projects" ? "project" : "post", label: p.title, url: "/blog/#{p.slug}", category: p.category }
      @links[p.id].each { |t| edges << { s: "p:#{p.slug}", t: "p:#{posts.find { _1.id == t }.slug}", kind: "link" } }
      @refs[p.id].each { |k| edges << { s: "p:#{p.slug}", t: "r:#{k}", kind: "cites" } }
      @tags[p.id].each { |t| edges << { s: "p:#{p.slug}", t: "t:#{t}", kind: "tag" } }
    end
    @refs.values.flatten.uniq.each do |k|
      r = @ref_info[k]
      nodes << { id: "r:#{k}", type: "paper", label: r ? r.short_label : k, title: r&.title, url: r&.link }
    end
    @tags.values.flatten.uniq.each { |t| nodes << { id: "t:#{t}", type: "tag", label: "##{t}", url: "/blog/tag/#{ERB::Util.url_encode(t)}" } }
    { nodes:, edges: }
  end

  private

  def internal_slugs(post)
    Nokogiri::HTML.fragment(post.rendered_html).css("a[href]").filter_map { |a|
      a["href"][%r{\A(?:https?://(?:www\.)?antoniosmithmd\.com)?/blog/([a-z0-9-]+)(?:[#?].*)?\z}, 1]
    }
  end
end
