# A snapshot of a post *before* an edit. `public` = that text was live on the site when it was
# replaced, so showing it hides nothing that wasn't already published. Drafts never become public.
# change_kind / change_note describe the edit that replaced this text (written by Antonio in admin).
class PostRevision < ApplicationRecord
  KINDS = { "update" => "Updated", "correction" => "Correction", "rethink" => "Changed my thinking" }.freeze

  belongs_to :post

  validates :change_kind, inclusion: { in: KINDS.keys }, allow_nil: true
  validates :change_note, length: { maximum: 500 }

  scope :shown, -> { where(public: true).order(created_at: :desc) }
  scope :noted, -> { shown.where.not(change_note: [nil, ""]) }

  def kind_label = KINDS[change_kind] || "Edited"

  def plain_text = Nokogiri::HTML.fragment(body.to_s).xpath(".//text()").map(&:text).join(" ").squish

  # Word-level diff of this version (old) against `other` text (new) → HTML with <del>/<ins>.
  def diff_html(other_text)
    a = plain_text.split(/(\s+)/)
    b = other_text.to_s.split(/(\s+)/)
    Diff::LCS.sdiff(a, b).chunk_while { |x, y| x.action == y.action }.map { |grp|
      old = ERB::Util.h(grp.filter_map { _1.old_element if _1.action != "+" }.join)
      new = ERB::Util.h(grp.filter_map { _1.new_element if _1.action != "-" }.join)
      case grp.first.action
      when "=" then old
      when "-" then %(<del>#{old}</del>)
      when "+" then %(<ins>#{new}</ins>)
      else %(<del>#{old}</del><ins>#{new}</ins>)
      end
    }.join.html_safe
  end
end
