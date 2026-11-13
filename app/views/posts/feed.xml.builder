xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title SITE[:name]
    xml.link root_url
    xml.description SITE[:tagline]
    @posts.each do |post|
      xml.item do
        xml.title post.title
        xml.link post_url(post)
        xml.guid post_url(post)
        xml.pubDate post.published_at.rfc2822
        xml.category post.category_name if post.category
        xml.description post.rendered_html
      end
    end
  end
end
