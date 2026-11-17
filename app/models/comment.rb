class Comment < ApplicationRecord
  MAX_DEPTH = 6
  belongs_to :post
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :author_name, presence: true, length: { maximum: 60 }
  validates :body, presence: true, length: { maximum: 5000 }
  validate :parent_on_same_post
  before_validation :set_anchor

  scope :visible, -> { where(approved: true) }

  def depth = parent ? parent.depth + 1 : 0

  # { parent_id => [comments sorted best-first] }
  def self.tree_for(post)
    post.comments.visible.order(score: :desc, created_at: :asc).group_by(&:parent_id)
  end

  # "passage" = the anchored text still exists in the post as it reads now.
  def anchored? = anchor.present?
  def anchor_current?(post_paragraphs) = anchored? && post_paragraphs.key?(anchor)

  private
  # Only top-level comments anchor; the quote is taken from the post on the server, so a browser
  # can't attach a made-up quote. An unknown anchor makes it an ordinary comment.
  def set_anchor
    if parent_id.present? || anchor.blank?
      self.anchor = self.anchor_text = nil
      return
    end
    text = post&.paragraphs&.[](anchor.to_s)
    text ? (self.anchor_text = text.truncate(300, separator: " ")) : (self.anchor = self.anchor_text = nil)
  end

  def parent_on_same_post
    errors.add(:parent, "is invalid") if parent && parent.post_id != post_id
  end
end
