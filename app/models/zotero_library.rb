require "net/http"

# Syncs a Zotero library (user or group) into the local `references` cache via the Zotero Web API v3.
#   ZOTERO_LIBRARY_TYPE=user|group  ZOTERO_LIBRARY_ID=123456  ZOTERO_API_KEY=... (read-only key; optional for public libraries)
#   ZOTERO_STYLE=american-medical-association (any CSL style id)
class ZoteroLibrary
  class Error < StandardError; end
  API = "https://api.zotero.org"

  def self.configured? = ENV["ZOTERO_LIBRARY_ID"].present?
  def self.style = ENV.fetch("ZOTERO_STYLE", "american-medical-association")
  def self.prefix = "/#{ENV.fetch("ZOTERO_LIBRARY_TYPE", "user") == "group" ? "groups" : "users"}/#{ENV["ZOTERO_LIBRARY_ID"]}"
  def self.web_url = ENV["ZOTERO_WEB_URL"]

  # Incremental sync: only items changed since the last sync. Returns {added:, updated:, deleted:}
  def self.sync!(full: false)
    raise Error, "Zotero isn't configured (set ZOTERO_LIBRARY_ID)" unless configured?
    since = full ? 0 : Reference.maximum(:version).to_i
    stats = { added: 0, updated: 0, deleted: 0 }
    start = 0
    loop do
      res = get("#{prefix}/items/top", since:, start:, limit: 100, format: "json", include: "data,bib", style:, sort: "dateModified")
      items = JSON.parse(res.body)
      items.each do |it|
        next if %w[attachment note annotation].include?(it.dig("data", "itemType"))
        ref = Reference.find_or_initialize_by(zotero_key: it["key"])
        stats[ref.new_record? ? :added : :updated] += 1
        upsert(ref, it)
      end
      total = res["Total-Results"].to_i
      start += 100
      break if items.empty? || start >= total
    end
    if since.positive?
      del = JSON.parse(get("#{prefix}/deleted", since:).body)
      stats[:deleted] = Reference.where(zotero_key: del["items"]).destroy_all.size
    end
    stats
  end

  def self.upsert(ref, it)
    d = it["data"]
    authors = Array(d["creators"]).select { %w[author editor].include?(_1["creatorType"]) }
                .map { _1["lastName"].present? ? [_1["lastName"], _1["firstName"]].compact.join(", ") : _1["name"] }.compact
    year = d["date"].to_s[/\b(1[5-9]|20)\d\d\b/] || ""
    ref.assign_attributes(title: d["title"], authors: authors.join("; "), year:, doi: d["DOI"].presence&.strip,
                          url: d["url"].presence, item_type: d["itemType"], bib_html: it["bib"], data: d, version: it["version"])
    ref.citekey = citekey_for(d, authors, year, ref)
    ref.save!
  end

  # Zotero 7 citationKey field > Better BibTeX "Citation Key:" in Extra > generated authorYear(+a,b,c…)
  def self.citekey_for(d, authors, year, ref)
    explicit = d["citationKey"].presence || d["extra"].to_s[/^Citation Key:\s*(\S+)/i, 1]
    return explicit if explicit
    return ref.citekey if ref.citekey.present? && ref.citekey_was.present?          # keep stable once assigned
    base = "#{authors.first.to_s.split(",").first.to_s.parameterize(separator: "")}#{year}".presence || "ref#{ref.zotero_key.downcase}"
    base = "anon#{year}" if base == year
    key, n = base, 0
    while Reference.where(citekey: key).where.not(zotero_key: ref.zotero_key).exists?
      n += 1; key = base + ("a".ord + n - 1).chr
    end
    key
  end

  def self.get(path, **params)
    uri = URI(API + path); uri.query = URI.encode_www_form(params)
    req = Net::HTTP::Get.new(uri, "Zotero-API-Version" => "3")
    req["Zotero-API-Key"] = ENV["ZOTERO_API_KEY"] if ENV["ZOTERO_API_KEY"].present?
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) { _1.request(req) }
    raise Error, "Zotero API #{res.code}: #{res.body.to_s[0, 200]}" unless res.is_a?(Net::HTTPSuccess)
    res
  rescue SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
    raise Error, "Can't reach Zotero (#{e.class.name.demodulize})"
  end
end
