# antoniosmithmd.com

Rails 8 + SQLite personal site/blog for Antonio Smith, MD. Deployed on TrueNAS via Portainer (stack in repository mode, GitOps polling `main`). Reached through a Cloudflare tunnel on the `asmithlabs-edge` Docker network as container `antoniosmithmd:3000`.

## Rules for agents (Claude Code, Hermes)
- **Never push to `main`.** Work on a branch, open a pull request, and wait for Antonio to merge. Merging = deploying to production.
- CI (`.github/workflows/ci.yml`) must pass: Brakeman, bundler-audit, production boot + page smoke test, Docker build.
- Never commit secrets or data: `.env`, `config/master.key`, `storage/*` (SQLite DB), API tokens, passwords.
- Don't weaken admin auth: password + second factor (WebAuthn security key or Duo) is required. Changes to `app/controllers/admin/sessions_controller.rb`, `admin/base_controller.rb`, `duo_client.rb`, `passkeys` need an explicit note in the PR description.
- Antonio's writing is his: don't rewrite or publish post content. Agents may create **drafts** via the API only.

## Map
- `config/site.yml` — home page text and links
- `app/assets/stylesheets/application.css` — whole design (vimhelp style; teal #00485F, slate #677684, gold #986C2B; keep WCAG AA)
- `editor/src/editor.js` → built to `public/js/editor.js` (`cd editor && npm install && npm run build`; commit the built file)
- `app/models/post.rb` — sanitizing, TOC, citations; `obsidian_markdown.rb`; `zotero_library.rb`; `duo_client.rb`
- `app/controllers/api/v1/*` — token API (Obsidian sync, Hermes); `hermes/skills/publishing/obsidian-blog/` — Hermes skill
- `portainer-stack.yml` — production stack (env vars set in Portainer, not in git)

## Run locally
    bundle install && bin/rails db:prepare db:seed && bin/rails s   # admin password in dev: "password"
