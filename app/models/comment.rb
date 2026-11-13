class Comment < ApplicationRecord
  MAX_DEPTH = 6
  belongs_to :post
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :author_name, presence: true, length: { maximum: 60 }
  validates :body, presence: true, length: { maximum: 5000 }
  validate :parent_on_same_post

  scope :visible, -> { where(approved: true) }

  def depth = parent ? parent.depth + 1 : 0

  # { parent_id => [comments sorted best-first] }
  def self.tree_for(post)
    post.comments.visible.order(score: :desc, created_at: :asc).group_by(&:parent_id)
  end

  private
  def parent_on_same_post
    errors.add(:parent, "is invalid") if parent && parent.post_id != post_id
  end
end
