---
name: obsidian-blog
description: Send notes from Antonio's Obsidian blog folder to his blog, and look up papers in his Zotero library to cite as [@key].
version: 1.0.0
platforms: [macos, linux]
metadata:
  hermes:
    tags: [Obsidian, Blog, Publishing, Writing]
---

# Obsidian → Blog

Moves notes from ONE Obsidian folder (`OBSIDIAN_BLOG_DIR`) to Antonio's Rails blog via its API.
All work goes through `${HERMES_SKILL_DIR}/scripts/blog.py`. Never read or send notes from anywhere else in the vault.

## When to use
- "What's ready to post?", "what's in my blog folder?"
- "Send <note> to the blog", "push my alert fatigue note as a draft"
- "Publish <note>" (requires explicit confirmation — see Rules)
- "Is <note> live?"
- "Find the paper on alert fatigue for me", "what's the cite key for Smith 2021?"
- "Check the citations in <note>"

## Procedure
1. **Find notes:** `python3 ${HERMES_SKILL_DIR}/scripts/blog.py list`
   Report as a short list: title, words, blog status (`not on blog` / `draft` / `scheduled` / `published`),
   and whether the note is marked `publish: true`. Point out notes marked publish that aren't live yet.
2. **Before sending, preview:** `blog.py preview "<note name or title>"` and tell Antonio the title, slug,
   word count and whether it goes up as a draft or would overwrite a live post.
3. **Send as draft (default):** `blog.py send "<note>"` → reply with the `edit_url` so he can review in the editor.
4. **Publish:** only if Antonio explicitly says to publish *this* note in his current message (e.g. "yes, publish it").
   Run `blog.py send "<note>" --publish`. If the API answers `this token is draft-only` / 403, say that the
   Hermes token can only make drafts and he can publish from the admin page (give the `edit_url`). Don't retry.
5. **Check:** `blog.py status "<note>"` to confirm state and give the link.

## Citing papers (Zotero)
- **Find a paper:** `blog.py cite "<words from title, author, year or DOI>"`. Reply with the best 1–5 matches as
  `[@key]` — Author Year — Title. Antonio pastes the key into his note himself; don't edit the note.
- **Before sending a note with citations:** `blog.py check "<note>"`. If anything is `missing`, tell him which keys
  and offer `cite` searches for them. Missing keys show as a red `@key?` on the blog.
- Only report papers the search actually returned. Never invent a citation, key, DOI or author.
- The library is the copy synced into the blog; if a paper he just added isn't found, tell him to press
  "sync from Zotero" in blog admin → references (saving a post with a new key also syncs).

## Rules
- Drafts by default. Never publish, or overwrite a published post, without an explicit yes for that specific note.
- Never edit the note files themselves. Don't rewrite Antonio's writing; send it as-is.
- Report what the script actually returned. If it errors, show the error — never claim a post was sent or published when it wasn't.
- If several notes match, list them and ask which one.

## Note conventions (frontmatter)
`title`, `publish: true`, `date`, `category` (informatics | ai | medicine | notes | homelab | leadership | projects — projects also appear on the home page),
`tags: [a, b]`, `description` (meta description), `slug`, `comments: false`, `blog: false` (never send).
Obsidian callouts (`> [!tip]`, `> [!pearl]`, `> [!tldr]`, `> [!warning]`, `> [!definition]`, foldable `> [!faq]-`),
`==highlights==`, `[[links]]` and `%%private comments%%` (stripped) are converted by the blog. Image embeds are not uploaded.

## Setup (once)
In `~/.hermes/.env`:
```
BLOG_URL=https://antoniosmithmd.com
BLOG_TOKEN=asm_...            # blog admin -> connections -> "Drafts only" (recommended) or "Full"
OBSIDIAN_BLOG_DIR=/path/to/Vault/Blog
```
The vault folder must be readable where Hermes runs (e.g. Obsidian Sync/Syncthing/iCloud copy mounted into the container).

## Verification
`blog.py list` returns JSON with `folder` = the configured folder and no error.
