# Usage: bin/rails "ghost:import[path/to/ghost-export.json]"
namespace :ghost do
  desc "Import posts from a Ghost JSON export (Settings → Labs → Export)"
  task :import, [:file] => :environment do |_, args|
    data = JSON.parse(File.read(args.fetch(:file)))
    posts = data.dig("db", 0, "data", "posts") || data.dig("data", "posts") || []
    count = 0
    posts.each do |g|
      next unless g["type"].nil? || g["type"] == "post"
      body = g["html"].present? ? ReverseMarkdown.convert(g["html"], unknown_tags: :bypass, github_flavored: true) : g["plaintext"].to_s
      post = Post.find_or_initialize_by(slug: g["slug"])
      post.update!(title: g["title"], excerpt: g["custom_excerpt"], body: body,
                   published_at: g["status"] == "published" ? g["published_at"] : nil)
      count += 1
    end
    puts "Imported #{count} posts."
  end
end
