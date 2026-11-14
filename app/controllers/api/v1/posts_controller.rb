module Api
  module V1
    class PostsController < BaseController
      before_action :require_publish!, only: :destroy
      # GET /api/v1/posts?status=draft|published
      def index
        posts = Post.order(updated_at: :desc).limit(200)
        posts = posts.published if params[:status] == "published"
        posts = posts.where(published_at: nil) if params[:status] == "draft"
        render json: posts.map { post_json(_1) }
      end

      def show = render(json: post_json(Post.find_by!(slug: params[:id]), full: true))

      # PUT /api/v1/posts/:slug  — upsert.
      #   { "obsidian": "<raw note with frontmatter>", "source_path": "Blog/My note.md" }
      #   or { "title":, "markdown"|"html":, "excerpt":, "category":, "tags": [..], "published_at":, "publish": true }
      def update
        post = Post.find_or_initialize_by(slug: params[:id].to_s.parameterize)
        if post.persisted? && post.published? && !token.publish?
          return render(json: { error: "draft-only tokens can't edit published posts" }, status: :forbidden)
        end
        attrs = params[:obsidian].present? ? from_obsidian(params[:obsidian]) : from_fields
        if attrs[:published_at].present? && !token.publish?
          return render(json: { error: "this token is draft-only — publish from the admin page", edit_url: (post.persisted? ? edit_admin_post_url(post) : nil) }, status: :forbidden)
        end
        attrs[:source] = params[:source].presence || (params[:obsidian].present? ? "obsidian" : "api:#{token.name}")
        attrs[:source_path] = params[:source_path] if params[:source_path]
        post.revision_editor = attrs[:source]
        post.assign_attributes(attrs.compact)
        post.published_at = nil if !token.publish? && post.new_record?
        if post.save
          render json: post_json(post), status: (post.previously_new_record? ? :created : :ok)
        else
          render json: { errors: post.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        Post.find_by!(slug: params[:id]).destroy
        head :no_content
      end

      private

      def from_fields
        p = params.permit(:title, :markdown, :html, :excerpt, :category, :published_at, :publish, tags: [])
        body = p[:html].presence || (p[:markdown] && ObsidianMarkdown.new(p[:markdown]).to_html)
        { title: p[:title], body:, excerpt: p[:excerpt], category: p[:category], tags: p[:tags]&.join(", "),
          published_at: p[:publish].to_s == "true" ? (p[:published_at].presence || Time.current) : p[:published_at] }
      end

      def from_obsidian(raw)
        note = ObsidianMarkdown.new(raw)
        fm = note.frontmatter.transform_keys(&:to_s)
        tags = Array(fm["tags"]).flat_map { _1.to_s.split(",") }.map(&:strip) + note.inline_tags
        publish = fm["publish"] == true || fm["status"].to_s == "published"
        date = fm["date"] || fm["published"] || fm["published_at"]
        {
          title: fm["title"].presence || note.first_h1 || params[:id].to_s.titleize,
          body: note.to_html,
          excerpt: fm["description"].presence || fm["excerpt"],
          category: (fm["category"].to_s.downcase.presence if Post::CATEGORIES.key?(fm["category"].to_s.downcase)),
          tags: tags.uniq.reject { %w[blog publish].include?(_1) }.join(", ").presence,
          comments_enabled: fm.key?("comments") ? fm["comments"] != false : nil,
          published_at: publish ? (date.present? ? Time.zone.parse(date.to_s) : Time.current) : nil
        }
      end
    end
  end
end
