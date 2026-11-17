class PagesController < ApplicationController
  def home
    @projects = Post.published.where(category: "projects").limit(6)
    @repos = GithubProjects.all.first(6)
    @portfolio = PortfolioProject.listed.ordered.limit(6)
    @writing  = Post.published.where.not(category: "projects").or(Post.published.where(category: nil)).limit(5)
  end

  def projects
    @portfolio = PortfolioProject.listed.ordered
    @projects = Post.published.where(category: "projects")
    @repos = GithubProjects.all
  end
end
