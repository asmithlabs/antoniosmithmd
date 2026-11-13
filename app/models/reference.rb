class Reference < ApplicationRecord
  CITE = /\[((?:-?@[\w:.#$%&\-+?<>~\/]+[^;\]]*;?\s*)+)\]/   # [@key], [@a; @b, p. 4], [-@key]

  def self.search(q, limit: 20)
    return order(updated_at: :desc).limit(limit) if q.blank?
    like = "%#{sanitize_sql_like(q.downcase)}%"
    where("LOWER(citekey) LIKE :l OR LOWER(title) LIKE :l OR LOWER(authors) LIKE :l OR year LIKE :l OR LOWER(doi) LIKE :l", l: like).limit(limit)
  end

  def self.lookup(key)
    key.start_with?("zotero:") ? find_by(zotero_key: key.delete_prefix("zotero:")) : find_by(citekey: key)
  end

  # Keys cited in a body (text or HTML)
  def self.keys_in(text)
    text.to_s.scan(CITE).flatten.flat_map { |grp| grp.scan(/-?@([\w:.#$%&\-+?<>~\/]+)/).flatten }.map { _1.chomp(".").chomp(",") }.uniq
  end

  def link = doi.present? ? "https://doi.org/#{doi}" : url.presence
  def short_label = [authors.to_s.split(";").first&.strip&.split(",")&.first, year].compact.join(" ")
  def safe_bib
    ActionController::Base.helpers.sanitize(bib_html.to_s, tags: %w[div span i b em strong a sup sub], attributes: %w[href class])
  end
end
