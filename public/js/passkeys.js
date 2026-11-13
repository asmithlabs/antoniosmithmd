// Minimal WebAuthn helpers (base64url <-> ArrayBuffer), no dependencies.
const b64u = {
  dec: s => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4)), c => c.charCodeAt(0)).buffer,
  enc: b => btoa(String.fromCharCode(...new Uint8Array(b))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, ""),
}
const csrf = () => document.querySelector("meta[name=csrf-token]").content
const post = (url, body) => fetch(url, { method: "POST", headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf(), Accept: "application/json" }, body: JSON.stringify(body || {}), credentials: "same-origin" })
  .then(async r => { const j = await r.json().catch(() => ({})); if (!r.ok) throw new Error(j.error || `Request failed (${r.status})`); return j })
const say = (el, msg, bad) => { if (el) { el.textContent = msg; el.className = bad ? "pk-msg bad" : "pk-msg" } }

async function login(btn) {
  const msg = document.getElementById("pk-msg")
  try {
    const o = await post(btn.dataset.optionsUrl)
    o.challenge = b64u.dec(o.challenge)
    o.allowCredentials = (o.allowCredentials || []).map(c => ({ ...c, id: b64u.dec(c.id) }))
    const c = await navigator.credentials.get({ publicKey: o })
    const r = await post(btn.dataset.url, { credential: { type: c.type, id: c.id, rawId: b64u.enc(c.rawId), authenticatorAttachment: c.authenticatorAttachment,
      clientExtensionResults: c.getClientExtensionResults(), response: { clientDataJSON: b64u.enc(c.response.clientDataJSON),
      authenticatorData: b64u.enc(c.response.authenticatorData), signature: b64u.enc(c.response.signature),
      userHandle: c.response.userHandle ? b64u.enc(c.response.userHandle) : null } } })
    location.href = r.redirect
  } catch (e) { say(msg, e.name === "NotAllowedError" ? "Cancelled or no matching passkey." : e.message, true) }
}

async function register(btn) {
  const msg = document.getElementById("pk-msg")
  try {
    const o = await post(btn.dataset.optionsUrl)
    o.challenge = b64u.dec(o.challenge)
    o.user.id = b64u.dec(o.user.id)
    o.excludeCredentials = (o.excludeCredentials || []).map(c => ({ ...c, id: b64u.dec(c.id) }))
    const c = await navigator.credentials.create({ publicKey: o })
    await post(btn.dataset.url, { nickname: document.getElementById("pk-name")?.value, credential: { type: c.type, id: c.id, rawId: b64u.enc(c.rawId),
      clientExtensionResults: c.getClientExtensionResults(), response: { clientDataJSON: b64u.enc(c.response.clientDataJSON),
      attestationObject: b64u.enc(c.response.attestationObject), transports: c.response.getTransports?.() || [] } } })
    location.reload()
  } catch (e) { say(msg, e.name === "InvalidStateError" ? "This device already has a passkey here." : e.name === "NotAllowedError" ? "Cancelled." : e.message, true) }
}

document.addEventListener("click", e => {
  const b = e.target.closest("[data-passkey]"); if (!b) return
  e.preventDefault()
  if (!window.PublicKeyCredential) return say(document.getElementById("pk-msg"), "This browser doesn't support passkeys.", true)
  b.dataset.passkey === "login" ? login(b) : register(b)
})
