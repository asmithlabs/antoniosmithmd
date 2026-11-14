class PagesController < ApplicationController
  def home
    @projects = Post.published.where(category: "projects").limit(6)
    @repos = GithubProjects.all.first(6)
    @writing  = Post.published.where.not(category: "projects").or(Post.published.where(category: nil)).limit(5)
  end

  def projects
    @projects = Post.published.where(category: "projects")
    @repos = GithubProjects.all
  end
end
