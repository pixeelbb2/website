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
| Guestbook | `guestbook.html` | Atabook iframe, interim (BlackPirateX blocked on an upstream focus bug) |

## Files

| File | Purpose |
|---|---|
| `style.css` | The one and only stylesheet — theme + layout for every page. Fully documented at the top, including how to restyle via CSS variables. |
| `shutdown.js` | The fake `[X]` power-cut gag (wobble → bright line → dying dot → black screen). Loaded by every page. Documented at the top. |
| `pixeelbb2-button.png` | 88×31 web-button, also embedded in the homepage LINKS box. |
| `pixeelbb2-logo.png` | Same button at 3x (264×93, nearest-neighbor) — Atabook header logo. |
| `cover.png` | Current "Song of the Week" cover art — the round label in the middle of the about-page vinyl. |
| `song.txt` | Current "Song of the Week" text — 3 lines: `SONG` / `ARTIST` / `YOUTUBE-URL`. The about page loads it live. |
| `guestbook-embed.css` | Skin for the book *inside* its iframe — loaded by the BlackPirateX app via the dashboard's Embed CSS URL, since parent CSS can't cross the frame. |
| `scripts/weekly_song.py` | The Monday picker — pulls your Last.fm top 5, rotates, writes `song.txt` + `cover.png`. |
| `.github/workflows/weekly-song.yml` | The schedule: runs the script Mondays 06:00 UTC, commits, uploads to Neocities. |

## Song of the Week (about page)

The about page spins a vinyl whose center label is `cover.png` and whose
title/artist/button link are loaded from `song.txt` at view time (the values
baked into `about.html` are only a fallback). The loader then asks the
**iTunes Search API** (free, no key, CORS-open) for the track: on an artist
match it swaps the vinyl label to Apple's 600px artwork and makes the vinyl
clickable for a 30s preview. A miss keeps `cover.png` and no preview —
never the wrong song.

Manual changes (no code edits needed):

1. Upload a new `cover.png` over the old one.
2. Upload a new `song.txt` (exactly 3 lines):
   ```
   SEASONAL DEPRESSION
   THE HAUNT
   https://www.youtube.com/watch?v=4H3ImwtTvpw
   ```
3. Hard-refresh — `Cmd/Ctrl+Shift+R`. (Neocities and browsers cache the
   text and image files, so the new song may need the hard refresh to show.)

## Automation: new song every Monday

A GitHub Action (`.github/workflows/weekly-song.yml`, Mondays 06:00 UTC =
08:00 CEST, plus a manual Run button) picks the song for you:

- Reads your last-7-days top 5 from **Last.fm** (`user.getTopTracks`,
  `period=7day`) — Deezer scrobbles there automatically once linked at
  `deezer.com/account/share`. Read-only API key, no account access.
- **Rotate, skip repeats:** takes the highest-ranked track that isn't the
  current `song.txt`. Silent week or same song on top → no commit, old song
  stays.
- Writes `song.txt` (UPPERCASED title/artist + a YouTube **search** URL —
  no keyless API can resolve the real video ID) and refreshes `cover.png`
  from Deezer's `cover_xl`, normalized to PNG. Art fallbacks: Last.fm image
  → keep the old file. Never a broken label.
- Commits + pushes, then uploads `song.txt` + `cover.png` to Neocities.

Repo secrets needed (Settings → Secrets → Actions): `LASTFM_USER`,
`LASTFM_API_KEY` (free at `last.fm/api/account/create`), `NEOCITIES_API_KEY`.
Logic lives in `scripts/weekly_song.py` (stdlib + `pillow`, installed by the
workflow).

### First-time setup (one time, ~10 min)

1. **Link Deezer → Last.fm:** at `deezer.com/account/share`. Your plays
   on mobile + web player scrobble automatically afterwards. (The desktop
   app scrobbler is unreliable — don't count on it for charts.)
2. **Get a Last.fm API key:** log in → `last.fm/api/account/create` → name it
   anything (no callback URL needed, we only read charts) → copy the
   **API key** shown on your new app's page. The "shared secret" next to it
   is unused — ignore it.
3. **Add the 3 repo secrets** (Settings → Secrets → Actions):
   - `LASTFM_USER` — your Last.fm username
   - `LASTFM_API_KEY` — the 32-char key from step 2
   - `NEOCITIES_API_KEY` — your Neocities dashboard key
4. **Make sure the workflow file is in the repo.** GitHub refuses commit
   pushes created by tools without `workflow` scope, so commit
   `.github/workflows/weekly-song.yml` from the GitHub web UI
   (Add file → Create new file → paste contents → Commit directly to main)
   once. It won't change after that.
5. **Test it:** Actions tab → *Weekly song* → **Run workflow**. First run:
   the chart needs at least a couple of scrobbles, otherwise it logs
   *"empty chart — keeping current song"* and changes nothing (green ✔ —
   that's correct behavior, not an error). With data it picks, commits, and
   uploads to Neocities within ~1 minute.
6. **Consider a hard refresh** on the about page after a change — Neocities
   and browsers cache `song.txt`/`cover.png` aggressively.

After setup, nothing to do. Every Monday 08:00 CEST a fresh Song of the
Week appears and the button links to a YouTube search for it. If the upper
charts are unchanged from last week, the old song stays until there's a
new pick.

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
- A stored nickname (`pixeel_nick` in `localStorage`, legacy from the old
  local guestbook) becomes the boot screen's `MACHINE ID`. Nothing writes
  it anymore, so new visitors always get `2137`.

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
- **Interim: Atabook** (`pixeelbb2.atabook.org`) in an `<iframe>`, themed
  dark in Atabook's own Change-layout page (Page `#020005` / Message
  `#0a0612` / Reply `#050308`; fonts `#d9a7ff` / `#e0aaff` / `#d9a7ff`;
  dark inputs ON, radius 0px, monospace if offered).
- **Blocked move: BlackPirateX Website Tools** (`tools.blackpiratex.com/u/pixeelbb2`)
  with a native skin (`guestbook-embed.css`, loaded inside the frame via
  their dashboard's Embed CSS URL). Parked because their sign form loses
  focus after every keystroke — `EntryForm` is declared inside the page
  component so React remounts it per character. Issue filed upstream; the
  frame src flips back once fixed. `guestbook-embed.css` stays in the repo
  (dormant) for that day.
- Moderation happens in the host's dashboard. (History: localStorage/Supabase
  implementation retired.)

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
  -F "cover.png=@cover.png" -F "song.txt=@song.txt" -F "pixeelbb2-button.png=@pixeelbb2-button.png" \
  -F "guestbook-embed.css=@guestbook-embed.css" -F "pixeelbb2-logo.png=@pixeelbb2-logo.png"

# GitHub
git add -A && git commit -m "update" && git push origin main
```

After uploading, hard-refresh (`Cmd/Ctrl+Shift+R` / `Ctrl+F5`) — Neocities and
browsers cache aggressively.