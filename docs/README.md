# ESCAPE_02 Project Site

The GitHub Pages site for `escape-02`. Plain static HTML/CSS/JS, no build step and no external CDN dependencies.

Live URL: <https://chenyue321.github.io/escape-02/>

The previous empty-shell version is preserved in commit `aaff524`; the full multi-section version before that is in `f6e4927`.

## Files

```
docs/
├── index.html                  # Header, notice, intro, footer
├── download.html               # Windows / Mac / Linux download buttons
├── .nojekyll                   # Skip Jekyll on GitHub Pages
├── README.md                   # This file
└── assets/
    ├── css/style.css           # Styles for both pages
    ├── js/main.js              # Notice, [DISABLE]/[ENABLE] loop, data rain
    ├── fonts/                  # VT323 / Share Tech Mono / Caveat OFL license files
    ├── favicon.svg
    └── img/
        ├── room-desk.webp      # In-game room screenshot, desk angle
        ├── room-door.webp      # In-game room screenshot, door angle
        └── ...                 # Older screenshots and OG cover, kept for reuse
```

## Page structure

- **Header**: the `ESCAPE_02` wordmark and two rectangular links, **GitHub Page** and **Download**.
- **Notice**: the AI disclosure. It uses a paper background and system sans-serif so it reads as website copy, not game content. The `×` button removes it with a small script.
- **Intro**: four short paragraphs set in VT323, with the two room screenshots stacked on the right. On narrow screens the text and images stack vertically.
- **Footer**: compact three-column footer with project links, license note and copyright.

The header and footer are duplicated in `index.html` and `download.html`; keep them in sync. The **Download** button in both headers points to `download.html`, not to GitHub Releases.

## The `[DISABLE]` / `[ENABLE]` loop

`docs/assets/js/main.js` cycles the inline state word:

1. `[DISABLE]` for 1 second
2. random garbled token for 0.5 seconds
3. `[ENABLE]` for 1 second
4. random garbled token for 0.5 seconds
5. repeat

To change the timings, edit the `phases` array in `main.js`.

## Background data rain

The `<main>` area is decorated with falling columns of random green glyphs. `main.js` generates 20 columns on desktop and 8 on mobile; each column gets a random position, speed, size, opacity and character string. Characters mutate every 0.8 seconds so the columns feel unstable. The effect is pure CSS animation plus a small interval, sits behind the content with `pointer-events: none`, and is disabled under `prefers-reduced-motion: reduce`.

## Download page

`download.html` shows three large platform buttons — Windows, Mac and Linux — in a centered row. They are ordinary links styled as buttons:

- Windows: `ESCAPE_02-Windows-x86_64.zip`
- Mac: `ESCAPE_02-macOS-universal.zip`
- Linux: `ESCAPE_02-Linux-x86_64.zip`
- Linux arm64: `ESCAPE_02-Linux-arm64.zip` (small link below the row)

Each link points to `https://github.com/ChenYue321/escape-02/releases/latest/download/<filename>`. **This only works after a release has been published with those exact asset filenames.** If there is no release yet, GitHub returns 404.

On hover (and keyboard focus) each platform tile inverts to the game's FACILITY CONTROL palette: green background, black icon and label. There is no transition, so the swap is immediate.

## Screenshots

`room-desk.webp` and `room-door.webp` were captured from the actual game, from two different camera angles in `Scenes/main.tscn`. They were resized to 1280×720 and saved as WebP. Replace the files directly to update the images; the HTML references the same names.

## Local preview

From the repository root:

```bash
python3 -m http.server 4173 --directory docs
```

Then open <http://127.0.0.1:4173/>.

## Deploy

1. Commit and push `docs/` to `main`.
2. In the repository, open **Settings → Pages**.
3. Set **Source** to **Deploy from a branch**, branch `main`, folder `/docs`, then **Save**.
4. Wait 1–2 minutes and open <https://chenyue321.github.io/escape-02/>.

Every push to `main` republishes the site automatically.

## Editing

- **Copy**: edit `index.html`; the header labels, notice text and intro paragraph are all there.
- **Download page**: edit `download.html`; platform links are in the three `.platform` anchors.
- **Style**: `assets/css/style.css`; colors and fonts are in the `:root` variables.
- **Notice close / state loop / data rain**: `assets/js/main.js`.
- **Screenshots**: replace `assets/img/room-desk.webp` or `room-door.webp`.
- **Footer / header**: edit both `index.html` and `download.html`.

## Troubleshooting

- **404**: Confirm Pages uses branch `main` and folder `/docs`, wait 1–2 minutes, and make sure `docs/index.html` has been pushed.
- **Styles look stale**: Pages caches aggressively. Wait a moment or force refresh (`Cmd/Ctrl + Shift + R`).
- **Custom domain**: Enter it in Pages settings and GitHub will create a `CNAME` file, or add one under `docs/` and configure DNS.

## Credits

Platform glyphs are based on [Simple Icons](https://simpleicons.org/) (CC0 1.0). Apple and Windows logos are trademarks of their respective owners and are used only to identify the download platforms.
