# Read-only editorial check for a post. Flags things worth a second look before publishing;
# never edits the post. Agents (Hermes) surface these as suggestions — Antonio decides what to change.
class PostReview
  Issue = Struct.new(:severity, :code, :message, keyword_init: true) do
    def as_json(*) = { severity: severity, code: code, message: message }
  end

  SEVERITIES = %w[info warning].freeze
  MIN_WORDS = 80
  MAX_TITLE_CHARS = 60
  EXCERPT_LENGTH = 155

  def initialize(post) = @post = post

  def issues
    @issues ||= begin
      list = []
      check_citations(list)
      check_excerpt(list)
      check_internal_links(list)
      check_images(list)
      check_length(list)
      check_category(list)
      check_title_length(list)
      list
    end
  end

  def clean? = issues.empty?

  # A suggested meta description, only offered when the post doesn't already have one.
  # Never written automatically — the API response surfaces it, a human (or an explicit
  # admin action) decides whether to use it.
  def suggested_excerpt
    return nil if @post.excerpt.present?
    text = @post.plain_text
    text.present? ? text.truncate(EXCERPT_LENGTH, separator: " ") : nil
  end

  def as_json(*)
    { clean: clean?, issues: issues.map(&:as_json), suggested_excerpt: suggested_excerpt }
  end

  private

  def check_citations(list)
    missing = @post.missing_citation_keys
    return if missing.empty?
    list << Issue.new(severity: "warning", code: "missing_citations",
                      message: "Unresolved citation key#{"s" if missing.size > 1}: #{missing.map { "@#{_1}" }.join(", ")} — " \
                                "not found in the Zotero library.")
  end

  def check_internal_links(list)
    doc = Nokogiri::HTML.fragment(@post.body.to_s)
    broken = doc.css("a[href]").filter_map do |a|
      href = a["href"].to_s
      next unless href.start_with?("/blog/")
      slug = href.delete_prefix("/blog/").split("?").first.to_s.split("#").first
      next if slug.blank? || Post.exists?(slug: slug)
      href
    end.uniq
    return if broken.empty?
    list << Issue.new(severity: "warning", code: "broken_internal_link",
                      message: "Link#{"s" if broken.size > 1} to a post that doesn't exist: #{broken.join(", ")}")
  end

  def check_images(list)
    doc = Nokogiri::HTML.fragment(@post.body.to_s)
    missing_alt = doc.css("img").count { |img| img["alt"].to_s.strip.empty? }
    return if missing_alt.zero?
    list << Issue.new(severity: "info", code: "missing_alt_text",
                      message: "#{missing_alt} image#{"s" if missing_alt > 1} without alt text (helps accessibility and SEO).")
  end

  def check_excerpt(list)
    return if @post.excerpt.present?
    list << Issue.new(severity: "info", code: "missing_excerpt",
                      message: "No excerpt set — previews and search results fall back to a truncated auto-summary.")
  end

  def check_length(list)
    words = @post.plain_text.split.size
    return if words >= MIN_WORDS
    list << Issue.new(severity: "info", code: "thin_content",
                      message: "Short post (#{words} words) — fine for a note, worth a second look if this is meant as an article.")
  end

  def check_category(list)
    return if @post.category.present?
    list << Issue.new(severity: "info", code: "missing_category", message: "No category set.")
  end

  def check_title_length(list)
    len = @post.title.to_s.length
    return if len <= MAX_TITLE_CHARS || len.zero?
    list << Issue.new(severity: "info", code: "long_title",
                      message: "Title is #{len} characters; search results usually truncate past ~#{MAX_TITLE_CHARS}.")
  end
end
