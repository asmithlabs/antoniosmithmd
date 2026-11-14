class PostRevision < ApplicationRecord
  belongs_to :post

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
