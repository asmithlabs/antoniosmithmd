#!/usr/bin/env python3
"""Obsidian -> blog bridge for Hermes. Python stdlib only.

Config (env or ~/.hermes/.env):
  BLOG_URL          https://antoniosmithmd.com
  BLOG_TOKEN        asm_...   (create in blog admin -> connections; "Drafts only" recommended)
  OBSIDIAN_BLOG_DIR /path/to/Vault/Blog   (the only folder this script will read)

Commands:
  blog.py list                      notes in the folder + their blog status
  blog.py preview "<note>"          what would be sent (title, slug, status, words) — sends nothing
  blog.py send "<note>" [--publish] upload as draft (or publish, full-access token only)
  blog.py status "<note>"           current state of that post on the blog
  blog.py cite "<query>"            search Antonio's Zotero library (via the blog) -> [@key] citations
  blog.py check "<note>"            list the note's [@key] citations and flag any not found in Zotero
  blog.py review "<note>"           editorial check of the note's current state on the blog (read-only)
"""
import json, os, re, sys, urllib.request, urllib.error
from pathlib import Path

def load_env():
    f = Path.home() / ".hermes" / ".env"
    if f.exists():
        for line in f.read_text().splitlines():
            m = re.match(r"\s*([A-Z_]+)\s*=\s*(.*)", line)
            if m and m.group(1) not in os.environ:
                os.environ[m.group(1)] = m.group(2).strip().strip('"').strip("'")
load_env()

def need(k):
    v = os.environ.get(k)
    if not v: sys.exit(f"error: {k} is not set (put it in ~/.hermes/.env)")
    return v

ROOT = Path(need("OBSIDIAN_BLOG_DIR")).expanduser().resolve()
BASE = need("BLOG_URL").rstrip("/")
TOKEN = need("BLOG_TOKEN")

def slugify(s): return re.sub(r"(^-|-$)", "", re.sub(r"[^a-z0-9]+", "-", re.sub(r"['’]", "", s.lower())))

def frontmatter(text):
    m = re.match(r"\A---\s*\n(.*?)\n---", text, re.S)
    fm = {}
    if m:
        for line in m.group(1).splitlines():
            kv = re.match(r"^([A-Za-z_]+):\s*(.*)$", line)
            if kv: fm[kv.group(1)] = kv.group(2).strip().strip('"').strip("'")
    return fm

def notes():
    return sorted(p for p in ROOT.rglob("*.md") if not any(part.startswith(".") for part in p.relative_to(ROOT).parts))

def find(name):
    """Resolve a note by filename, relative path or title — never outside OBSIDIAN_BLOG_DIR."""
    cand = (ROOT / name).resolve()
    if not str(cand).startswith(str(ROOT)): sys.exit("error: that path is outside the blog folder")
    if cand.is_file(): return cand
    if cand.with_suffix(".md").is_file(): return cand.with_suffix(".md")
    key = name.lower().removesuffix(".md")
    hits = [p for p in notes() if p.stem.lower() == key or frontmatter(p.read_text(errors="ignore")).get("title", "").lower() == key]
    if not hits: hits = [p for p in notes() if key in p.stem.lower()]
    if len(hits) == 1: return hits[0]
    if not hits: sys.exit(f"error: no note matching '{name}' in {ROOT}")
    sys.exit("error: several notes match, be more specific:\n  " + "\n  ".join(str(p.relative_to(ROOT)) for p in hits))

def info(p):
    raw = p.read_text(errors="ignore"); fm = frontmatter(raw)
    body = re.sub(r"\A---.*?\n---\s*", "", raw, flags=re.S)
    title = fm.get("title") or (re.search(r"^#\s+(.+)$", body, re.M) or [None, p.stem])[1]
    return dict(path=str(p.relative_to(ROOT)), title=title.strip(), slug=slugify(fm.get("slug") or p.stem),
                wants_publish=fm.get("publish", "").lower() == "true", skip=fm.get("blog", "").lower() == "false",
                category=fm.get("category"), words=len(re.sub(r"%%.*?%%", "", body, flags=re.S).split()), raw=raw)

def api(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method, headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "Accept": "application/json"},
                                 data=json.dumps(body).encode() if body is not None else None)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read() or b"{}")
        except Exception: return e.code, {"error": e.reason}
    except urllib.error.URLError as e:
        sys.exit(f"error: can't reach {BASE} ({e.reason})")

def remote(slug):
    code, j = api("GET", f"/api/v1/posts/{slug}")
    return j if code == 200 else None

def main(argv):
    if not argv or argv[0] in ("-h", "--help"): print(__doc__); return
    cmd, args = argv[0], argv[1:]
    if cmd == "list":
        code, posts = api("GET", "/api/v1/posts")
        by_slug = {p["slug"]: p for p in posts} if code == 200 else {}
        rows = []
        for p in notes():
            i = info(p); r = by_slug.get(i["slug"])
            rows.append(dict(note=i["path"], title=i["title"], slug=i["slug"], words=i["words"],
                             blog=("skipped (blog: false)" if i["skip"] else (r["status"] if r else "not on blog")),
                             marked_publish=i["wants_publish"], url=(r or {}).get("url") or (r or {}).get("edit_url")))
        print(json.dumps({"folder": str(ROOT), "notes": rows}, indent=2))
    elif cmd in ("preview", "status"):
        if not args: sys.exit(f"usage: blog.py {cmd} \"<note>\"")
        i = info(find(args[0])); r = remote(i["slug"])
        out = {k: i[k] for k in ("path", "title", "slug", "category", "words", "wants_publish")}
        out["currently_on_blog"] = r["status"] if r else "not on blog"
        if cmd == "preview":
            out["would_send_as"] = "published" if ("--publish" in args) else "draft"
            if r and r["status"] == "published": out["note"] = "This post is already live; sending will overwrite it (needs a full-access token)."
        else:
            out["url"] = r and (r.get("url") or r.get("edit_url"))
        print(json.dumps(out, indent=2))
    elif cmd == "send":
        if not args: sys.exit('usage: blog.py send "<note>" [--publish]')
        i = info(find(args[0]))
        if i["skip"]: sys.exit("error: note has 'blog: false' in its frontmatter")
        raw = i["raw"]
        if "--publish" not in args:   # force draft regardless of frontmatter
            raw = re.sub(r"^publish:\s*true\s*$", "publish: false", raw, count=1, flags=re.M | re.I)
        elif not re.search(r"^publish:\s*true", raw, re.M | re.I):
            raw = re.sub(r"\A---\s*\n", "---\npublish: true\n", raw, count=1) if raw.startswith("---") else f"---\npublish: true\n---\n{raw}"
        code, j = api("PUT", f"/api/v1/posts/{i['slug']}", {"obsidian": raw, "source_path": i["path"], "source": "hermes"})
        if code in (200, 201):
            print(json.dumps({"ok": True, "status": j["status"], "title": j["title"], "url": j.get("url"), "edit_url": j["edit_url"]}, indent=2))
        else:
            print(json.dumps({"ok": False, "http": code, **j}, indent=2)); sys.exit(1)
    elif cmd == "cite":
        if not args: sys.exit('usage: blog.py cite "<query>"')
        from urllib.parse import quote
        code, j = api("GET", f"/api/v1/references?q={quote(' '.join(a for a in args if not a.startswith('--')))}")
        if code != 200: print(json.dumps({"ok": False, "http": code, **(j if isinstance(j, dict) else {})})); sys.exit(1)
        print(json.dumps({"results": j, "hint": "Paste the 'cite' value into the note, e.g. [@key] or [@key, p. 4]."}, indent=2))
    elif cmd == "check":
        if not args: sys.exit('usage: blog.py check "<note>"')
        i = info(find(args[0]))
        body = re.sub(r"\[\[@([^\]|]+)[^\]]*\]\]", r"[@\1]", i["raw"])
        keys = sorted(set(k.rstrip(".,") for grp in re.findall(r"\[(-?@[^\]]+)\]", body) for k in re.findall(r"-?@([\w:.#$%&\-+?<>~/]+)", grp)))
        found, missing = [], []
        for k in keys:
            c, r = api("GET", f"/api/v1/references?limit=50&q={k}")
            (found if c == 200 and any(x["key"] == k for x in r) else missing).append(k)
        print(json.dumps({"note": i["path"], "citations": len(keys), "found": found, "missing": missing,
                          "hint": "Missing keys: check spelling with `cite`, or sync Zotero in blog admin -> references." if missing else "All citations resolve."}, indent=2))
    elif cmd == "review":
        if not args: sys.exit('usage: blog.py review "<note>"')
        i = info(find(args[0]))
        r = remote(i["slug"])
        if not r: sys.exit(f"error: '{i['title']}' isn't on the blog yet — send it first.")
        code, j = api("GET", f"/api/v1/posts/{i['slug']}/review")
        if code != 200: print(json.dumps({"ok": False, "http": code, **(j if isinstance(j, dict) else {})})); sys.exit(1)
        print(json.dumps({"note": i["path"], "slug": i["slug"], "status": r["status"], **j}, indent=2))
    else:
        sys.exit(f"unknown command '{cmd}'. Try: list | preview | send | status | cite | check | review")

if __name__ == "__main__":
    main(sys.argv[1:])
