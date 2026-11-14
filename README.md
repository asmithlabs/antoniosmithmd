# Antonio Smith, MD — personal site & blog

Rails 8 + SQLite. Plain vimhelp-style design in teal `#00485F` / slate `#677684` / gold `#986C2B` (brand shades adjusted to meet WCAG AA 4.5:1 contrast; dark mode also AA).

## Features
- **Home**: intro from `config/site.yml` (text, links, projects). CV served from `public/cv.pdf`.
- **Blog** with categories (informatics, ai, medicine, notes, homelab, leadership) and tags.
- **Tiptap editor** at `/admin` — headings, lists, links, code, tables, images, highlight, plus blocks:
  Note, Tip, Warning, **Clinical pearl**, **Key takeaways**, Definition, Collapsible section.
- **Vim-style table of contents** built from H2/H3 headings (numbered, dotted leaders, `*tag*` anchors).
  Inline on mobile; sticky sidebar with scroll highlighting on wide screens. Shows when a post has 2+ headings.
- **Threaded comments, Reddit-style**: nested replies, collapse `[–]`, up/down votes (click again to undo),
  sorted best-first, permalinks. Spam: honeypot + 5 comments / 10 min rate limit.
- **Comment controls per post**: on/off, **delay** (open at a date — quick +1 day / +3 days / +1 week from publish),
  and hold-for-approval. Moderate at `/admin/comments`.
- **SEO**: title/description/canonical, Open Graph + Twitter tags, JSON-LD (`Person` on home, `BlogPosting` on posts),
  `sitemap.xml`, `robots.txt`, RSS at `/feed.xml`, clean slugs.
- Drafts and scheduled posts; Ghost importer (`bin/rails "ghost:import[export.json]"`).

## Sign-in (admin) — two-factor
`/admin/login`: **password**, then **one** second factor: a **YubiKey / security key / passkey** or **Duo**.
- First ever sign-in: the password only lets you register a security key; nothing else in admin opens until you do.
- Register two keys (e.g. two YubiKeys) so losing one doesn't lock you out. You can't remove your last factor.
- When signed in, a teal bar on the public site gives "edit this post", "new post", "new project".
- Sessions last 12 hours; 10 attempts / 5 min.

**Duo (optional):** Duo Admin Panel → Applications → Protect an Application → **Web SDK** →
copy Client ID, Client secret, API hostname into `DUO_CLIENT_ID`, `DUO_CLIENT_SECRET`, `DUO_API_HOST`.
Set `DUO_USERNAME` to your username in Duo. Uses Duo Universal Prompt (OIDC), implemented directly — no third-party Duo gem.

## Dark mode
`[auto]` / `[light]` / `[dark]` toggle in the header; remembered per browser. Auto follows the system.

## Obsidian
1. Admin → **connections** → create a token with **Full** access.
2. In your vault, keep blog notes in a folder (e.g. `Blog/`). Frontmatter:
   ```yaml
   ---
   title: Alert fatigue is a design problem   # else first "# H1" or filename
   publish: true          # omit = draft
   date: 2026-11-20       # optional publish date
   category: informatics  # informatics | ai | medicine | notes | homelab | leadership | projects
   tags: [cds, epic]      # inline #tags are added too
   description: One-line summary for Google and post lists.
   slug: alert-fatigue    # optional, default = filename
   comments: false        # optional
   blog: false            # skip this note
   ---
   ```
3. Run: `BLOG_URL=https://antoniosmithmd.com BLOG_TOKEN=asm_... ruby script/obsidian_sync.rb ~/Vault/Blog`
   (only changed notes are sent; `--dry-run` to preview, `--force` to resend all). Run it from cron, or from
   Obsidian with the *Shell commands* community plugin.

Converted automatically: callouts `> [!tip] Title` → blog blocks (`[!pearl]`, `[!tldr]`/`[!summary]`, `[!warning]`,
`[!definition]`…), foldable callouts `> [!faq]-` → collapsible sections, `==highlight==`, `[[wikilinks]]`
(linked if that post is published, else plain text), `%%comments%%` removed. Image embeds `![[...]]` are not
uploaded — add images in the editor.

## Agents (API)
Give each agent (e.g. Hermes) its own **Drafts only** token. Agents can write and update drafts and read comments.
They can't publish, edit live posts, or moderate. Posts show their source in admin (`[api:Hermes]`, `[obsidian]`).

    GET    /api/v1/posts[?status=draft|published]
    GET    /api/v1/posts/:slug                  # includes body_html
    GET    /api/v1/posts/:slug/review            # read-only editorial check (see below)
    PUT    /api/v1/posts/:slug                  # upsert: {title, markdown|html, excerpt, category, tags[], publish, published_at}
                                                #     or {obsidian: "<raw note>", source_path}
    DELETE /api/v1/posts/:slug                  # full tokens only
    GET    /api/v1/comments[?since=ISO8601&pending=1]
    PATCH  /api/v1/comments/:id {approved}      # full tokens only
    Header: Authorization: Bearer asm_...

## Editorial review
`GET /api/v1/posts/:slug/review` flags things worth a second look before publishing — unresolved `[@key]`
citations, a link to a post that doesn't exist, images missing alt text, a short/thin post, no excerpt, no
category, or a long title — plus a `suggested_excerpt` when none is set. It's read-only: nothing is written
to the post. Agents (Hermes's `blog.py review "<note>"`) report these as suggestions; only Antonio edits the
post to act on them.

## Projects from GitHub
Public repos with the **`portfolio`** topic (from the accounts in `config/site.yml` → `github.owners`) appear on
/projects and the home page with description, language, last update and stars, refreshed hourly.
To add one: GitHub repo → ⚙ next to *About* → Topics → `portfolio`. Private repos never appear, even if tagged.
Optional `GITHUB_TOKEN` (no scopes needed) only raises the rate limit.

## Mastodon
Published posts are shared once to Mastodon within ~5 minutes of going live (scheduled posts too): title, summary,
link and tags as hashtags, under 500 characters. Per-post switch in the editor ("Share on Mastodon when published").
Setup: mastodon.social → Preferences → Development → New application → scope **write:statuses** only →
copy *Your access token* into `MASTODON_TOKEN`, and set `MASTODON_URL=https://mastodon.social`.
Only posts published in the last 2 days are shared, so turning it on doesn't flood your timeline with old posts.
The site links your profile with `rel="me"` → add https://antoniosmithmd.com to a profile field on Mastodon for a ✓.

## Zotero citations
1. zotero.org → Settings → Security → **Create new private key**: read-only access to your library.
   Your **userID** is shown on that page.
2. Set `ZOTERO_LIBRARY_ID=<userID>` and `ZOTERO_API_KEY=<key>` (for a group library: `ZOTERO_LIBRARY_TYPE=group`
   and the group ID). Optional: `ZOTERO_STYLE` = any CSL style id (default `american-medical-association`; e.g. `apa`, `vancouver`).
3. Admin → **references** → "sync from Zotero". After that, saving a post that cites a new key syncs automatically.

Cite anywhere (editor, Obsidian, API) with Pandoc-style keys: `[@key]`, `[@key, p. 4]`, `[@a; @b]`, or Obsidian
Citations-plugin `[[@key]]`. You can also cite by Zotero item ID: `[@zotero:ABCD1234]`.
Keys come from Zotero 7's *Citation Key* field / Better BibTeX; otherwise the blog generates `authorYear`
(e.g. `smith2021`, `smith2021a`). Find keys under admin → references, or with the editor's **cite** button.

On the post: numbered superscripts `[1]` `[2, p. 4]` with hover titles, a **References** list (in the TOC)
formatted in your CSL style with DOI/URL links, and `citation` entries in the JSON-LD for SEO.
Unknown keys show as a red `@key?` and are listed in the admin flash when you save.

## Hermes skill: Obsidian → blog
`hermes/skills/publishing/obsidian-blog/` lets Hermes look through ONE vault folder and send notes to the blog.

    cp -r hermes/skills/publishing/obsidian-blog ~/.hermes/skills/publishing/
    # ~/.hermes/.env
    BLOG_URL=https://antoniosmithmd.com
    BLOG_TOKEN=asm_...              # admin -> connections -> "Drafts only"
    OBSIDIAN_BLOG_DIR=/path/to/Vault/Blog

Then in Telegram: "what's in my blog folder?", "send the alert fatigue note to the blog".
Hermes sends drafts and replies with the editor link; you publish from /admin. With a drafts-only token the
server refuses any publish (403), so Hermes can't put anything live. Hermes can also search your Zotero library
("find the paper on alert fatigue" → `[@key]`) and check a note's citations before sending it. Use a "Full" token only if you want
Hermes to publish after you say yes in chat. The script won't read outside the folder and skips notes with `blog: false`.

## Starter posts
`bin/rails db:seed` creates 7 **draft outlines** (none published) across your categories. Write them in your words.

## Run locally
    bundle install && bin/rails db:setup && bin/rails s     # admin: /admin  (password: `password` in dev)

## Editor source
The editor is prebuilt into `public/js/editor.js`. To change it: `cd editor && npm install && npm run build`.

## Deploy (TrueNAS SCALE, Docker)
1. Copy this folder to a dataset, e.g. `/mnt/tank/apps/asmith-site` (SMB share or `scp`).
2. TrueNAS shell (System → Shell, or SSH):
       cd /mnt/tank/apps/asmith-site
       cp .env.example .env
       openssl rand -hex 64          # paste as SECRET_KEY_BASE in .env
       nano .env                     # ADMIN_PASSWORD, APP_ORIGIN=https://antoniosmithmd.com, TUNNEL_TOKEN
       mkdir -p storage && sudo chown -R 1000:1000 storage
3. Cloudflare (domain must use Cloudflare DNS): Zero Trust → Networks → Tunnels → Create tunnel →
   Cloudflared → copy the token into `TUNNEL_TOKEN`. Add a Public Hostname: `antoniosmithmd.com` → `HTTP` → `blog:3000`.
4. Start:  `sudo docker compose --profile tunnel up -d --build`
   (without Cloudflare: `sudo docker compose up -d --build`, site on http://truenas-ip:8080)
5. Open https://antoniosmithmd.com/admin/login → password → passkeys → add one per device.
6. Updates: copy new files over, then rerun step 4. Data lives in `storage/` — covered by dataset snapshots.
