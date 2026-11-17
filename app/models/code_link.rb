# One line of Post#code_links, classified so the post can say what it is:
# a GitHub repo, commit, pull request, issue, release, file/folder, or any other https link.
# Only https links are accepted; labels and URLs are plain text and escaped on render.
class CodeLink
  MAX = 8
  KINDS = { "repo" => "repo", "commit" => "commit", "pr" => "pull request", "issue" => "issue",
            "release" => "release", "file" => "file", "folder" => "folder", "link" => "link" }.freeze

  attr_reader :url, :label, :kind, :repo

  # "Label | https://…" or just "https://…". Returns nil for a blank line; raises ArgumentError for a bad one.
  def self.parse(line)
    line = line.to_s.strip
    return if line.blank?
    label, url = line.include?("|") ? line.split("|", 2).map(&:strip) : [nil, line]
    uri = URI.parse(url) rescue nil
    raise ArgumentError, "“#{line.truncate(60)}” isn't an https:// link" unless uri.is_a?(URI::HTTPS) && uri.host.present? && url.length <= 300
    new(url.chomp("/"), label.presence&.first(80))
  end

  def self.parse_all(text)
    text.to_s.lines.filter_map { parse(_1) }.first(MAX)
  end

  def initialize(url, label = nil)
    @url = url
    uri = URI.parse(url)
    if uri.host.to_s.downcase.delete_prefix("www.") == "github.com" && (m = uri.path.match(%r{\A/([\w.-]+)/([\w.-]+)(?:/(.*))?\z}))
      @repo = "#{m[1]}/#{m[2].delete_suffix(".git")}"
      @kind, detail = classify(m[3].to_s)
      @label = label || [@repo, detail].compact.join(" ")
    else
      @kind = "link"
      @label = label || "#{uri.host.delete_prefix("www.")}#{uri.path unless uri.path.in?(["", "/"])}".truncate(60)
    end
  end

  def kind_label = KINDS[kind]

  private

  def classify(rest)
    case rest
    when "" then ["repo", nil]
    when %r{\Acommit/(\h{7,40})} then ["commit", "@ #{$1.first(7)}"]
    when %r{\Apull/(\d+)} then ["pr", "##{$1}"]
    when %r{\Aissues/(\d+)} then ["issue", "##{$1}"]
    when %r{\Areleases/tag/(.+)} then ["release", URI.decode_www_form_component($1)]
    when %r{\Ablob/[^/]+/(.+)} then ["file", URI.decode_www_form_component($1)]
    when %r{\Atree/[^/]+/(.+)} then ["folder", URI.decode_www_form_component($1)]
    else ["link", rest.truncate(40)]
    end
  end
end
