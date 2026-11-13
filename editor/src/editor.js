import { Editor, Node, mergeAttributes } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Image from "@tiptap/extension-image"
import { TableKit } from "@tiptap/extension-table"
import Highlight from "@tiptap/extension-highlight"
import { Placeholder, CharacterCount } from "@tiptap/extensions"

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
      CharacterCount, Callout, Summary, DetailsBody, Details,
    ],
    content: textarea.value,
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
  span.append(button("cite", "Insert a Zotero citation [@key]", () => openCite()))
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
  const choose = r => { if (!r) return; pop.hidden = true; c().insertContent(`[@${r.key}]`).run() }
  function openCite() { pop.hidden = false; q.value = ""; items = []; render(); search(); q.focus() }
  q.addEventListener("input", () => { clearTimeout(timer); timer = setTimeout(search, 150) })
  q.addEventListener("keydown", e => {
    if (e.key === "ArrowDown") { pick = Math.min(pick + 1, items.length - 1); render(); e.preventDefault() }
    else if (e.key === "ArrowUp") { pick = Math.max(pick - 1, 0); render(); e.preventDefault() }
    else if (e.key === "Enter") { choose(items[pick]); e.preventDefault() }
    else if (e.key === "Escape") { pop.hidden = true; editor.commands.focus() }
  })
  ul.addEventListener("mousedown", e => { const li = e.target.closest("li"); if (li) { e.preventDefault(); choose(items[+li.dataset.i]) } })

  function refresh() {
    bar.querySelectorAll("button").forEach(b => b.classList.toggle("on", !!(b._isActive && b._isActive())))
    const words = editor.storage.characterCount.words()
    foot.textContent = `${words} words · ~${Math.max(1, Math.ceil(words / 220))} min read`
  }
  refresh()
  textarea.form?.addEventListener("submit", () => { textarea.value = editor.getHTML() })
  return editor
}

document.querySelectorAll("textarea[data-tiptap]").forEach(mount)
