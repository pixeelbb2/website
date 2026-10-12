# PIXEELBB2

A retro CRT/terminal personal website — a phosphor-purple, ULTRAKILL-flavored
old-web corner hosted on [Neocities](https://pixeelbb2-node.neocities.org).

**Live site:** <https://pixeelbb2-node.neocities.org>
**Code:** <https://github.com/pixeelbb2/website>

---

## What it is

The homepage boots up like a CRT monitor: synthesized keyboard clacks chime in
while the machine types out its specs, a loading track fills, a neon purple beam
rips past the screen's right edge, and the overlay dissolves into the real site.
Underneath it greets you with a long welcome story about this "corner of the
World Wide Web" and how the whole mess started with one late-night YouTube video.
Every other page shares the same terminal skin — a black window with a gradient
title bar and a fake `[X]` button that yanks the plug when you click it.

No frameworks, no build step. Plain HTML/CSS/JS + Google Fonts + a CDN-hosted
terminal font (`VCR OSD Mono`). Sounds are synthesized live with the Web Audio
API — there are zero audio files to host.

## Pages

| Page | File | Notes |
|---|---|---|
| Home | `index.html` | Only page with the boot sequence + visitor card |
| About me | `about.html` | Bio + SYSTEM SPECS table + SONG OF THE WEEK spinning vinyl |
| Chat | `chat.html` | SOON_ placeholder |
| Projects | `projects.html` | SOON_ placeholder — will fold in the old games + homelab content |
| Links | `links.html` | SOON_ placeholder (`link-row` styles ready) |
| Guestbook | `guestbook.html` | SOON_ placeholder (guestbook script kept intact) |

## Files

| File | Purpose |
|---|---|
| `style.css` | The one and only stylesheet — theme + layout for every page. Fully documented at the top, including how to restyle via CSS variables. |
| `shutdown.js` | The fake `[X]` power-cut gag (wobble → bright line → dying dot → black screen). Loaded by every page. Documented at the top. |
| `pixeelbb2-button.png` | 88×31 web-button, also embedded in the homepage LINKS box. |
| `cover.png` | Current "Song of the Week" cover art — the round label in the middle of the about-page vinyl. |

## Song of the Week (about page)

The about page spins a vinyl whose center label is `cover.png`. To change the
song:

1. Rename the new cover to `cover.png` and delete the old one (or just upload
   `cover.png` over it — same filename keeps the code untouched).
2. Update the song/artist title in the `> SONG OF THE WEEK <` block and/or the
   YouTube link on the `GO CHECK THAT OUT` button (spot on line `about.html`).
3. Re-upload `about.html` + `cover.png` (see Deploying) and hard-refresh —
   image caching means the new cover may need `Cmd/Ctrl+Shift+R`.

## Theming

Everything that makes the site purple/green/black is a CSS custom property in
`:root` inside `style.css`. Change one value and every page updates:

```css
:root {
  --neon-purple: #9d00ff;   /* primary accent: borders, active nav, buttons */
  --card-purple-text: #b22cff;
  --body-purple: #d9a7ff;
  --term-green: #33ff66;    /* terminal green text */
  --led-green: #2bf872;     /* LED green, visitor counter */
  --bg-dark: #020005;       /* html/body background */
  /* ... plus --panel-*, --grad-*, --glow-*, --font-stack ... */
}
```

Page-specific rules intentionally stay inline in each `.html` file so the shared
skin stays clean.

## How it works under the hood

### Boot sequence (`index.html`)
- Plays once per **tab**: `pixeel_booted` in `sessionStorage` skips it on
  in-tab navigation back to the homepage; a fresh tab still gets the full show.
- Typing a nickname in the guestbook (`pixeel_nick` in `localStorage`) turns
  your name into the boot screen's `MACHINE ID`. Otherwise it stays `2137`.

### Visitor counter (`index.html`, right column)
- `#myBox` = your **personal number**, assigned once and frozen forever.
- `#totalBox` = the global visit count. **Only first-ever visits bump it** —
  coming back never changes your number or inflates the total.
- **Out of the box** it runs in *local* mode: each browser counts its own visits
  (`pixeel_counter`, `pixeel_my_number` in `localStorage`) and shows
  "it dont work properly yet" until cloud counting is enabled.
- **Shared counting** is one optional step — paste Supabase keys into `CONFIG`
  in `index.html` after running the SQL snippet in the comment above that
  script (`site_stats` table + `bump_visits()` function). The assigned number
  then comes from an atomic `bump_visits()` call, so it can't double-assign.

### Guestbook (`guestbook.html`)
- Shelved behind a `SOON_` placeholder right now — the full script is still
  there and just early-returns until you wire up the form again.
- Works the same dual way as the counter: **local mode** (`pixeel_guestbook` in
  `localStorage`, per-browser) or **shared mode** once Supabase URL + anon key
  are in `CONFIG` (one book for everyone, realtime via Supabase, moderation in
  the dashboard). Full SQL setup is in the comment above that script.

### Shutdown gag (`shutdown.js`)
- Timeline: `0` wobble + noise snap → `140ms` window becomes a bright line →
  `320ms` window becomes a dying dot → `560ms` "AND NOW WHAT?" overlay.
- Self-guards: if the window/button markup is missing it silently does nothing.
- Required markup per page: `.vintage-page`, `.title-bar .x-btn`,
  `#killLine`, `#killDot`, `#shutOverlay` (details in the file header).

## Deploying

Everything that runs is uploaded to the Neocities site root. From this folder:

```bash
# Neocities (API key from your dashboard)
curl -H "Authorization: Bearer YOUR_API_KEY" -X POST https://neocities.org/api/upload \
  -F "index.html=@index.html" -F "style.css=@style.css" -F "shutdown.js=@shutdown.js" \
  -F "about.html=@about.html" -F "chat.html=@chat.html" -F "projects.html=@projects.html" \
  -F "links.html=@links.html" -F "guestbook.html=@guestbook.html" \
  -F "cover.png=@cover.png" -F "pixeelbb2-button.png=@pixeelbb2-button.png"

# GitHub
git add -A && git commit -m "update" && git push origin main
```

After uploading, hard-refresh (`Cmd/Ctrl+Shift+R` / `Ctrl+F5`) — Neocities and
browsers cache aggressively.