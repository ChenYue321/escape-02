# ESCAPE_02 Project Site

This is the GitHub Pages site for `escape-02`. It is plain static HTML/CSS with no build step and no external CDN dependencies.

The site is currently being redesigned: only the `<header>` and `<footer>` remain, and `<main>` is empty. The previous full page is preserved in commit `f6e4927`.

Live URL: <https://chenyue321.github.io/escape-02/>

## Files

```
docs/
├── index.html                  # Shell: header + empty main + footer
├── .nojekyll                   # Skip Jekyll on GitHub Pages
├── README.md                   # This file
└── assets/
    ├── css/style.css           # Site styles (header / footer only for now)
    ├── fonts/                  # VT323 font + OFL license
    ├── favicon.svg
    └── img/                    # Previous screenshots and OG cover, kept for reuse
```

## Local preview

From the repository root:

```bash
python3 -m http.server 4173 --directory docs
```

Then open <http://127.0.0.1:4173/>.

## Current state

- The `<header>` contains only the `ESCAPE_02` wordmark. Navigation links, the GitHub button and the mobile menu have been removed.
- `<main id="main">` is empty. New content goes here.
- The `<footer>` keeps the project links, license note and copyright.
- The old clock, scroll-reveal, gallery and lightbox scripts have been removed. Images in `assets/img/` remain available for reuse.
- All site copy is in English.

## Deploy

1. Commit and push `docs/` to `main`.
2. In the repository, open **Settings → Pages**.
3. Set **Source** to **Deploy from a branch**, branch `main`, folder `/docs`, then **Save**.
4. Wait 1–2 minutes and open <https://chenyue321.github.io/escape-02/>.

Every push to `main` republishes the site automatically.

## Next

- **Add content**: edit the `<main>` in `docs/index.html`.
- **Colors / type**: adjust the `:root` variables at the top of `docs/assets/css/style.css`.
- **Reuse screenshots**: WebP images for the room, corridor, FACILITY CONTROL and RECORDS are in `docs/assets/img/`.
- **Demo builds**: upload the four zips from `build/release/` as GitHub Release assets. Do not commit `build/` to the repository.
- **Footer**: edit the `<footer>` in `index.html`; all footer links live there.

## Troubleshooting

- **404**: Confirm Pages uses branch `main` and folder `/docs`, wait 1–2 minutes, and make sure `docs/index.html` has been pushed.
- **Styles look stale**: Pages caches aggressively. Wait a moment or force refresh (`Cmd/Ctrl + Shift + R`).
- **Custom domain**: Enter it in Pages settings and GitHub will create a `CNAME` file, or add one under `docs/` and configure DNS.
