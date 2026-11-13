import { Editor, Node, mergeAttributes } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Image from "@tiptap/extension-image"
import { TableKit } from "@tiptap/extension-table"
import Highlight from "@tiptap/extension-highlight"
import { Placeholder, CharacterCount } from "@tiptap/extensions"
import Document from "@tiptap/extension-document"
import Paragraph from "@tiptap/extension-paragraph"
import Text from "@tiptap/extension-text"
import Bold from "@tiptap/extension-bold"
import Italic from "@tiptap/extension-italic"
import Underline from "@tiptap/extension-underline"
import Strike from "@tiptap/extension-strike"
import Code from "@tiptap/extension-code"
import Link from "@tiptap/extension-link"
import { UndoRedo } from "@tiptap/extensions"

// <aside class="callout" data-kind="note|tip|warning|pearl|tldr|definition">
export const KINDS = { note: "Note", tip: "Tip", warning: "Warning", pearl: "Clinical pearl", tldr: "Key takeaways", definition: "Definition" }
const Callout = Node.create({
  name: "callout", group: "block", content: "block+", defining: true,
  addAttributes: () => ({ kind: { default: "note", parseHTML: el => el.getAttribute("data-kind") || "note", renderHTML: a => ({ "data-kind": a.kind }) } }),
  parseHTML: () => [{ tag: "aside.callout" }],
  renderHTML: ({ HTMLAttributes }) => ["aside", mergeAttributes(HTMLAttributes, { class: "callout" }), 0],
  addCommands() {
    return { setCallout: kind => ({ commands }) => commands.wrapIn(this.name, { kind }) }
  },
})
// Collapsible <details><summary>
const Summary = Node.create({ name: "detailsSummary", content: "text*", defining: true, selectable: false,
  parseHTML: () => [{ tag: "summary" }], renderHTML: () => ["summary", 0] })
const DetailsBody = Node.create({ name: "detailsBody", content: "block+", defining: true,
  parseHTML: () => [{ tag: "div.details-body" }], renderHTML: () => ["div", { class: "details-body" }, 0] })
const Details = Node.create({ name: "details", group: "block", content: "detailsSummary detailsBody", defining: true,
  parseHTML: () => [{ tag: "details" }], renderHTML: () => ["details", { open: "open" }, 0],
  addCommands() {
    return { insertDetails: () => ({ commands }) => commands.insertContent({ type: "details", content: [
      { type: "detailsSummary", content: [{ type: "text", text: "Click to expand" }] },
      { type: "detailsBody", content: [{ type: "paragraph" }] }] }) }
  },
})

// ---- Word-style citations -------------------------------------------------
// Stored as <span data-cite="key" data-locator="p. 4">[@key, p. 4]</span> — the server numbers them
// and builds the bibliography. In the editor each shows as its live number, like Word's citation fields.
const refCache = new Map()   // key -> {label, title}
async function loadRefs(keys) {
  const missing = keys.filter(k => !refCache.has(k)); if (!missing.length) return
  try {
    const r = await fetch(`/admin/references.json?keys=${encodeURIComponent(missing.join(","))}`, { credentials: "same-origin" })
    for (const x of await r.json()) refCache.set(x.key, x)
  } catch {}
  for (const k of missing) if (!refCache.has(k)) refCache.set(k, null)
}

const Citation = Node.create({
  name: "citation", group: "inline", inline: true, atom: true, selectable: true,
  addAttributes: () => ({
    key: { default: null, parseHTML: el => el.getAttribute("data-cite"), renderHTML: a => ({ "data-cite": a.key }) },
    locator: { default: "", parseHTML: el => el.getAttribute("data-locator") || "", renderHTML: a => (a.locator ? { "data-locator": a.locator } : {}) },
  }),
  parseHTML: () => [{ tag: "span[data-cite]" }],
  renderHTML: ({ node, HTMLAttributes }) => ["span", mergeAttributes(HTMLAttributes, { class: "cite-chip" }), `[@${node.attrs.key}${node.attrs.locator ? ", " + node.attrs.locator : ""}]`],
  renderText: ({ node }) => `[@${node.attrs.key}${node.attrs.locator ? ", " + node.attrs.locator : ""}]`,
  addNodeView() {
    return ({ node, getPos, editor }) => {
      const dom = document.createElement("span")
      dom.className = "cite-chip"; dom.contentEditable = "false"
      dom.dataset.cite = node.attrs.key; dom.dataset.locator = node.attrs.locator || ""
      dom.addEventListener("click", e => { e.preventDefault(); editor.storage.citation.open?.(dom, getPos(), node) })
      return {
        dom,
        update: n => { if (n.type.name !== "citation") return false; dom.dataset.cite = n.attrs.key; dom.dataset.locator = n.attrs.locator || ""; node = n; editor.storage.citation.relabel?.(); return true },
      }
    }
  },
  addStorage: () => ({ open: null, relabel: null }),
})

// Turn legacy plain-text [@a; @b, p. 4] in existing posts into citation chips (outside code).
function upgradeLegacyCitations(html) {
  return html.replace(/(<(code|pre)[\s\S]*?<\/\2>)|\[((?:-?@[^\]\[<]+?;?\s*)+)\]/g, (m, codeBlock, _t, grp) => {
    if (codeBlock) return codeBlock
    return grp.split(";").map(part => {
      const mm = part.trim().match(/^-?@([\w:.#$%&\-+?<>~\/]+?)[.,]?(?:,\s*(.+))?$/)
      if (!mm) return m
      const loc = (mm[2] || "").replace(/"/g, "&quot;")
      return `<span data-cite="${mm[1]}"${loc ? ` data-locator="${loc}"` : ""}>[@${mm[1]}${loc ? ", " + loc : ""}]</span>`
    }).join("")
  })
}

function button(label, title, run, isActive) {
  const b = document.createElement("button")
  b.type = "button"; b.textContent = label; b.title = title
  b.addEventListener("click", e => { e.preventDefault(); run() })
  b._isActive = isActive
  return b
}

export function mount(textarea) {
  const wrap = document.createElement("div"); wrap.className = "tt"
  const bar = document.createElement("div"); bar.className = "tt-bar"
  const area = document.createElement("div"); area.className = "tt-area prose"
  const foot = document.createElement("div"); foot.className = "tt-foot"
  textarea.style.display = "none"
  textarea.after(wrap); wrap.append(bar, area, foot)

  const editor = new Editor({
    element: area,
    extensions: [
      StarterKit.configure({ heading: { levels: [2, 3, 4] }, link: { openOnClick: false, autolink: true } }),
      Image, TableKit.configure({ table: { resizable: false } }), Highlight,
      Placeholder.configure({ placeholder: "Start writing… H2/H3 headings build the table of contents." }),
      CharacterCount, Callout, Summary, DetailsBody, Details, Citation,
    ],
    content: upgradeLegacyCitations(textarea.value),
    onUpdate: ({ editor }) => { textarea.value = editor.getHTML(); refresh() },
    onSelectionUpdate: () => refresh(),
  })
  const c = () => editor.chain().focus()
  const groups = [
    [ ["H2", "Section heading (in TOC)", () => c().toggleHeading({ level: 2 }).run(), () => editor.isActive("heading", { level: 2 })],
      ["H3", "Subheading (in TOC)", () => c().toggleHeading({ level: 3 }).run(), () => editor.isActive("heading", { level: 3 })],
      ["¶", "Paragraph", () => c().setParagraph().run()] ],
    [ ["B", "Bold", () => c().toggleBold().run(), () => editor.isActive("bold")],
      ["I", "Italic", () => c().toggleItalic().run(), () => editor.isActive("italic")],
      ["U", "Underline", () => c().toggleUnderline().run(), () => editor.isActive("underline")],
      ["S", "Strike", () => c().toggleStrike().run(), () => editor.isActive("strike")],
      ["`", "Inline code", () => c().toggleCode().run(), () => editor.isActive("code")],
      ["≡", "Highlight", () => c().toggleHighlight().run(), () => editor.isActive("highlight")],
      ["link", "Link", () => { const prev = editor.getAttributes("link").href; const url = prompt("URL (blank to remove)", prev || "https://"); if (url === null) return; url ? c().extendMarkRange("link").setLink({ href: url }).run() : c().unsetLink().run() }, () => editor.isActive("link")] ],
    [ ["• list", "Bullet list", () => c().toggleBulletList().run(), () => editor.isActive("bulletList")],
      ["1. list", "Numbered list", () => c().toggleOrderedList().run(), () => editor.isActive("orderedList")],
      ["quote", "Blockquote", () => c().toggleBlockquote().run(), () => editor.isActive("blockquote")],
      ["{ }", "Code block", () => c().toggleCodeBlock().run(), () => editor.isActive("codeBlock")],
      ["—", "Divider", () => c().setHorizontalRule().run()] ],
    [ ["table", "Insert 3×3 table", () => c().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()],
      ["+row", "Add row", () => c().addRowAfter().run()], ["+col", "Add column", () => c().addColumnAfter().run()],
      ["×tbl", "Delete table", () => c().deleteTable().run()],
      ["img", "Image by URL", () => { const src = prompt("Image URL"); if (src) c().setImage({ src, alt: prompt("Alt text (for accessibility/SEO)") || "" }).run() }] ],
  ]
  for (const g of groups) {
    const span = document.createElement("span"); span.className = "tt-group"
    for (const [l, t, r, a] of g) span.append(button(l, t, r, a))
    bar.append(span)
  }
  const sel = document.createElement("select"); sel.title = "Insert block"
  sel.innerHTML = `<option value="">+ block…</option>` + Object.entries(KINDS).map(([k, v]) => `<option value="${k}">${v}</option>`).join("") + `<option value="details">Collapsible</option>`
  sel.addEventListener("change", () => { const v = sel.value; sel.value = ""; if (!v) return; v === "details" ? c().insertDetails().run() : c().setCallout(v).run() })
  const span = document.createElement("span"); span.className = "tt-group"; span.append(sel)
  span.append(button("unwrap", "Remove callout around selection", () => c().lift("callout").run()))
  span.append(button("Insert citation", "Insert a citation from Zotero (like Word → References → Insert Citation)", () => openCite()))
  span.append(button("↶", "Undo", () => c().undo().run()), button("↷", "Redo", () => c().redo().run()))
  bar.append(span)

  // Zotero citation picker
  const pop = document.createElement("div"); pop.className = "cite-pop"; pop.hidden = true
  pop.innerHTML = `<input type="search" placeholder="search Zotero: author, title, year…" aria-label="Search references"><ul role="listbox"></ul><p class="muted"></p>`
  wrap.append(pop)
  const q = pop.querySelector("input"), ul = pop.querySelector("ul"), hint = pop.querySelector("p")
  let timer, pick = 0, items = []
  const render = () => {
    ul.innerHTML = items.map((r, i) => `<li role="option" class="${i === pick ? "on" : ""}" data-i="${i}"><code>@${r.key}</code> ${r.label ? r.label + " — " : ""}${(r.title || "").replace(/</g, "&lt;").slice(0, 90)}</li>`).join("")
    hint.textContent = items.length ? "↑↓ choose · Enter insert · Esc close" : (q.value ? "No matches. Sync Zotero under admin → references." : "Type to search your library.")
  }
  const search = () => fetch(`/admin/references.json?q=${encodeURIComponent(q.value)}`, { credentials: "same-origin" })
    .then(r => r.json()).then(j => { items = j; pick = 0; render() }).catch(() => { hint.textContent = "Search failed." })
  const choose = r => { if (!r) return; pop.hidden = true; refCache.set(r.key, r); c().insertContent({ type: "citation", attrs: { key: r.key } }).insertContent(" ").run() }
  function openCite() { pop.hidden = false; q.value = ""; items = []; render(); search(); q.focus() }
  q.addEventListener("input", () => { clearTimeout(timer); timer = setTimeout(search, 150) })
  q.addEventListener("keydown", e => {
    if (e.key === "ArrowDown") { pick = Math.min(pick + 1, items.length - 1); render(); e.preventDefault() }
    else if (e.key === "ArrowUp") { pick = Math.max(pick - 1, 0); render(); e.preventDefault() }
    else if (e.key === "Enter") { choose(items[pick]); e.preventDefault() }
    else if (e.key === "Escape") { pop.hidden = true; editor.commands.focus() }
  })
  ul.addEventListener("mousedown", e => { const li = e.target.closest("li"); if (li) { e.preventDefault(); choose(items[+li.dataset.i]) } })

  // Live numbering, like Word: order of first appearance → [1], [2, p. 4]; unknown keys flagged.
  function relabel() {
    const chips = [...area.querySelectorAll(".cite-chip")]
    loadRefs([...new Set(chips.map(ch => ch.dataset.cite))]).then(() => {
      const order = []
      for (const ch of area.querySelectorAll(".cite-chip")) {
        const k = ch.dataset.cite, ref = refCache.get(k)
        if (!ref) { ch.textContent = `@${k}?`; ch.classList.add("missing"); ch.title = "Not found in Zotero — sync under admin → references"; continue }
        if (!order.includes(k)) order.push(k)
        ch.classList.remove("missing")
        ch.textContent = `[${order.indexOf(k) + 1}${ch.dataset.locator ? " (" + ch.dataset.locator + ")" : ""}]`
        ch.title = `${ref.label} — ${ref.title}  (click to edit)`
      }
      bib.innerHTML = order.length ? `<strong>References</strong> <span class="muted">(added automatically when published)</span><ol>${order.map(k => `<li>${refCache.get(k).label} — ${(refCache.get(k).title || "").replace(/</g, "&lt;")}</li>`).join("")}</ol>` : ""
    })
  }
  const bib = document.createElement("div"); bib.className = "tt-bib"; area.after(bib)
  editor.storage.citation.relabel = relabel

  // Click a citation: page/locator, change source, remove — like Word's "Edit Citation".
  const cpop = document.createElement("div"); cpop.className = "cite-edit"; cpop.hidden = true
  cpop.innerHTML = `<p class="ce-title"></p><label>Page / locator <input name="loc" placeholder="p. 4, ch. 2, fig. 1…"></label>
    <div class="ce-actions"><button type="button" data-a="save" class="btn">Save</button><button type="button" data-a="remove">Remove citation</button><button type="button" data-a="close">Cancel</button></div>`
  wrap.append(cpop)
  let editing = null
  editor.storage.citation.open = (dom, pos, node) => {
    editing = { pos, node }
    const ref = refCache.get(node.attrs.key)
    cpop.querySelector(".ce-title").textContent = ref ? `${ref.label} — ${ref.title}` : `@${node.attrs.key} (not in Zotero)`
    cpop.querySelector("input").value = node.attrs.locator || ""
    const r = dom.getBoundingClientRect(), w = wrap.getBoundingClientRect()
    cpop.style.top = `${r.bottom - w.top + 6}px`; cpop.style.left = `${Math.max(0, Math.min(r.left - w.left, w.width - 340))}px`
    cpop.hidden = false; cpop.querySelector("input").focus()
  }
  cpop.addEventListener("click", e => {
    const a = e.target.dataset.a; if (!a || !editing) return
    if (a === "save") editor.chain().focus().command(({ tr }) => { tr.setNodeMarkup(editing.pos, undefined, { ...editing.node.attrs, locator: cpop.querySelector("input").value.trim() }); return true }).run()
    if (a === "remove") editor.chain().focus().deleteRange({ from: editing.pos, to: editing.pos + editing.node.nodeSize }).run()
    cpop.hidden = true; editing = null
  })
  cpop.querySelector("input").addEventListener("keydown", e => { if (e.key === "Enter") { e.preventDefault(); cpop.querySelector("[data-a=save]").click() } if (e.key === "Escape") cpop.querySelector("[data-a=close]").click() })

  function refresh() {
    bar.querySelectorAll("button").forEach(b => b.classList.toggle("on", !!(b._isActive && b._isActive())))
    const words = editor.storage.characterCount.words()
    foot.textContent = `${words} words · ~${Math.max(1, Math.ceil(words / 220))} min read`
    relabel()
  }
  refresh()
  textarea.form?.addEventListener("submit", () => { textarea.value = editor.getHTML() })
  return editor
}

// ---- Rich-text title: one line, inline formatting only ---------------------
export function mountTitle(textarea) {
  const plain = textarea.form?.querySelector("input[name='post[title]']")
  const wrap = document.createElement("div"); wrap.className = "tt tt-title"
  const bar = document.createElement("div"); bar.className = "tt-bar"
  const area = document.createElement("div"); area.className = "tt-area"
  textarea.style.display = "none"; textarea.after(wrap); wrap.append(bar, area)
  const OneLine = Document.extend({ content: "paragraph" })
  const editor = new Editor({
    element: area,
    extensions: [OneLine, Paragraph, Text, Bold, Italic, Underline, Strike, Code, UndoRedo,
      Link.configure({ openOnClick: false }), Placeholder.configure({ placeholder: "Post title" })],
    content: textarea.value,
    editorProps: { handleKeyDown: (_v, e) => e.key === "Enter" },   // single line
    onUpdate: ({ editor }) => sync(editor),
    onSelectionUpdate: () => refresh(),
  })
  const sync = ed => {
    textarea.value = ed.isEmpty ? "" : ed.getHTML().replace(/^<p>|<\/p>$/g, "")
    if (plain) plain.value = ed.getText().trim()
    refresh()
  }
  const c = () => editor.chain().focus()
  for (const [l, t, r, a] of [
    ["B", "Bold", () => c().toggleBold().run(), () => editor.isActive("bold")],
    ["I", "Italic", () => c().toggleItalic().run(), () => editor.isActive("italic")],
    ["U", "Underline", () => c().toggleUnderline().run(), () => editor.isActive("underline")],
    ["S", "Strike", () => c().toggleStrike().run(), () => editor.isActive("strike")],
    ["`", "Code", () => c().toggleCode().run(), () => editor.isActive("code")],
    ["link", "Link", () => { const url = prompt("URL (blank to remove)", editor.getAttributes("link").href || "https://"); if (url === null) return; url ? c().extendMarkRange("link").setLink({ href: url }).run() : c().unsetLink().run() }, () => editor.isActive("link")],
  ]) bar.append(button(l, t, r, a))
  const refresh = () => bar.querySelectorAll("button").forEach(b => b.classList.toggle("on", !!(b._isActive && b._isActive())))
  sync(editor)
  textarea.form?.addEventListener("submit", () => sync(editor))
  return editor
}

document.querySelectorAll("textarea[data-tiptap-title]").forEach(mountTitle)
document.querySelectorAll("textarea[data-tiptap]").forEach(mount)
