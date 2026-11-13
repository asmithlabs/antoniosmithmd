xml.instruct! :xml, version: "1.0"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  [root_url, posts_url, projects_url].each { |u| xml.url { xml.loc u } }
  Post::CATEGORIES.each_key { |c| xml.url { xml.loc category_url(c) } }
  @posts.each do |p|
    xml.url { xml.loc post_url(p); xml.lastmod p.updated_or_published.iso8601 }
  end
end
