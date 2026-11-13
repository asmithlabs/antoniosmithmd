class PagesController < ApplicationController
  def home
    @projects = Post.published.where(category: "projects").limit(6)
    @writing  = Post.published.where.not(category: "projects").or(Post.published.where(category: nil)).limit(5)
  end

  def projects
    @projects = Post.published.where(category: "projects")
  end
end
