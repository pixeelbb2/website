#!/usr/bin/env python3
"""
/// This script was AI-generated ///


Weekly "Song of the Week" updater.

Runs every Monday from GitHub Actions (see .github/workflows/weekly-song.yml):

1. Pulls your last-7-days top 5 from Last.fm
   (Deezer scrobbles there automatically once linked).
2. Picks the highest-ranked track that ISN'T the current song
   (rotate, skip repeats). Silent week / same song on top -> no changes.
3. Writes song.txt (TITLE / ARTIST / YouTube-search-URL, uppercased to
   match the site skin) and refreshes cover.png (Deezer cover_xl,
   normalized to PNG; falls back to Last.fm art, then to the old file).

Hardening: https-only fetches with a 10MB cap, control characters stripped
from metadata (keeps the 3-line file format intact + no HTML injection;
the site renders with textContent anyway), atomic writes (no corrupt
files on failure), and Pillow restricted to JPEG/PNG/WEBP.

Needs LASTFM_USER + LASTFM_API_KEY in the environment. Exits 0 with no
changes when there is nothing new; exits 1 on real errors (bad key,
unknown user, network down) so the Action goes red.

WEEKLY_SONG_ROOT overrides the repo root (used for local testing).
"""

import io
import json
import os
import sys
import tempfile
import urllib.parse
import urllib.request

ROOT = os.environ.get(
    "WEEKLY_SONG_ROOT",
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
)
SONG_TXT = os.path.join(ROOT, "song.txt")
COVER_PNG = os.path.join(ROOT, "cover.png")

MAX_BYTES = 10 * 1024 * 1024  # covers are ~1-2MB; this is only a tripwire


def norm(s):
    """Compare-proof a title/artist (casefold handles ß/SS round-trips)."""
    return " ".join((s or "").casefold().split())


def clean(s):
    """Drop control chars (including \\n) so metadata can't break the
    3-line song.txt layout or smuggle markup into the page."""
    return "".join(c for c in (s or "") if c.isprintable()).strip()


def get(url, timeout=30, max_bytes=MAX_BYTES):
    """https-only GET with a hard size cap (no file://, no unbounded read)."""
    if urllib.parse.urlparse(url).scheme != "https":
        raise ValueError("https only")
    req = urllib.request.Request(url, headers={"User-Agent": "pixeelbb2-weekly-song/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        data = r.read(max_bytes + 1)
    if len(data) > max_bytes:
        raise ValueError("response too large")
    return data


def lastfm_top5(user, key):
    """[(title, artist, image_url, page_url)] in rank order, max 5."""
    qs = urllib.parse.urlencode({
        "method": "user.getTopTracks",
        "user": user,
        "period": "7day",
        "limit": 5,
        "api_key": key,
        "format": "json",
    })
    data = json.loads(get("https://ws.audioscrobbler.com/2.0/?" + qs))
    if "error" in data:
        raise RuntimeError("Last.fm error %s: %s" % (data["error"], data.get("message")))
    tracks = data.get("toptracks", {}).get("track", [])
    # A single-track chart comes back as a dict, not a list.
    if isinstance(tracks, dict):
        tracks = [tracks]
    out = []
    for t in tracks:
        name = clean(t.get("name"))
        artist = clean((t.get("artist", {}) or {}).get("name"))
        if not name or not artist:
            continue
        imgs = [i.get("#text", "") for i in t.get("image", []) if i.get("#text")]
        out.append((name, artist, imgs[-1] if imgs else "", t.get("url", "")))
    return out[:5]


def read_current():
    """(title, artist) from the existing song.txt, or (None, None)."""
    try:
        with open(SONG_TXT, encoding="utf-8") as f:
            lines = [l.strip() for l in f.read().split("\n") if l.strip()]
    except OSError:
        return None, None
    if len(lines) < 2:
        return None, None
    return lines[0], lines[1]


def pick(tracks, cur_title, cur_artist):
    """Highest-ranked track that isn't the current song. None = keep old."""
    for title, artist, _img, _url in tracks:
        if norm(title) == norm(cur_title) and norm(artist) == norm(cur_artist):
            continue
        return title, artist
    return None


def deezer_cover(title, artist):
    """Biggest Deezer cover URL for the track, or ''."""
    # Loose query only: Deezer's strict artist:".."/track:".." qualifiers
    # misfire (combined they return zero), the client-side match below
    # does the real filtering.
    qs = urllib.parse.urlencode({"q": "%s %s" % (artist, title), "limit": 5})
    data = json.loads(get("https://api.deezer.com/search?" + qs))
    want_a, want_t = norm(artist), norm(title)
    if not want_a or not want_t:
        return ""
    for hit in data.get("data", []):
        ha, ht = norm(hit.get("artist", {}).get("name")), norm(hit.get("title"))
        if not ha or not ht:
            continue
        exact = ha == want_a and ht == want_t
        fuzzy = (want_a in ha or ha in want_a) and (want_t in ht or ht in want_t)
        if exact or fuzzy:
            alb = hit.get("album") or {}
            if alb.get("cover_xl"):
                return alb["cover_xl"]
    return ""


def save_cover_png(url, dest):
    """Download art, normalize to PNG, atomically replace dest."""
    try:
        raw = get(url)
    except Exception as e:
        print("cover download failed: %s" % e)
        return False
    try:
        from PIL import Image
        img = Image.open(io.BytesIO(raw), formats=["JPEG", "PNG", "WEBP"]).convert("RGB")
        # Write temp file in the same dir, then swap: a crash mid-write can
        # never leave a corrupt half-written cover.png.
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(dest), suffix=".png")
        os.close(fd)
        img.save(tmp, "PNG")
        os.replace(tmp, dest)
        return True
    except ImportError:
        print("PIL missing, keeping old cover")
        return False
    except Exception as e:
        print("cover convert failed: %s" % e)
        try:
            os.unlink(tmp)  # noqa: F821 - only set when mkstemp succeeded
        except Exception:
            pass
        return False


def youtube_search_url(title, artist):
    return ("https://www.youtube.com/results?search_query="
            + urllib.parse.quote("%s - %s" % (artist, title)))


def main():
    user = os.environ.get("LASTFM_USER", "").strip()
    key = os.environ.get("LASTFM_API_KEY", "").strip()
    if not user or not key:
        print("LASTFM_USER / LASTFM_API_KEY missing")
        return 1

    try:
        tracks = lastfm_top5(user, key)
    except Exception as e:
        print("chart fetch failed: %s" % e)
        return 1
    if not tracks:
        print("empty chart (silent week?) — keeping current song")
        return 0

    cur_title, cur_artist = read_current()
    nxt = pick(tracks, cur_title, cur_artist)
    if nxt is None:
        print("top of chart is still the current song — no changes")
        return 0
    title, artist = nxt
    print("new song: %s — %s" % (title, artist))

    # Cover: Deezer XL -> Last.fm art -> keep old file. Never fatal.
    cover_url = ""
    try:
        cover_url = deezer_cover(title, artist)
    except Exception as e:
        print("deezer lookup failed: %s" % e)
    if not cover_url:
        for t, a, img, _u in tracks:
            if norm(t) == norm(title) and norm(a) == norm(artist) and img:
                cover_url = img
                break
    if cover_url and save_cover_png(cover_url, COVER_PNG):
        print("cover updated")
    else:
        print("cover unchanged (fallback kept)")

    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(SONG_TXT), suffix=".txt")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write("%s\n%s\n%s\n" % (
            title.upper(), artist.upper(), youtube_search_url(title, artist)))
    os.replace(tmp, SONG_TXT)
    print("song.txt updated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
