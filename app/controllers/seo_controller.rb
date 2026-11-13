class SeoController < ApplicationController
  def sitemap = @posts = Post.published
  def robots = render(plain: "User-agent: *\nDisallow: /admin\nSitemap: #{root_url}sitemap.xml\n")
end
