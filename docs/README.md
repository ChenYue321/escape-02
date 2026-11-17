# ESCAPE_02 Project Site

The GitHub Pages site for `escape-02`. Plain static HTML/CSS/JS, no build step and no external CDN dependencies.

Live URL: <https://chenyue321.github.io/escape-02/>

The previous empty-shell version is preserved in commit `aaff524`; the full multi-section version before that is in `f6e4927`.

## Files

```
docs/
├── index.html                  # Header, notice, intro, footer
├── .nojekyll                   # Skip Jekyll on GitHub Pages
├── README.md                   # This file
└── assets/
    ├── css/style.css           # Styles
    ├── js/main.js              # Notice dismissal + [DISABLE]/[ENABLE] loop
    ├── fonts/                  # VT323 (the in-game pixel font) + OFL license
    ├── favicon.svg
    └── img/
        ├── room-desk.webp      # In-game room screenshot, desk angle
        ├── room-door.webp      # In-game room screenshot, door angle
        └── ...                 # Older screenshots and OG cover, kept for reuse
```

## Page structure

- **Header**: the `ESCAPE_02` wordmark and two rectangular links, **GitHub Page** and **Download**.
- **Notice**: the AI disclosure. It uses a paper background and system sans-serif so it reads as website copy, not game content. The `×` button removes it with a small script.
- **Intro**: one paragraph set in VT323, with the two room screenshots stacked on the right. On narrow screens the text and images stack vertically.
- **Footer**: compact three-column footer with project links, license note and copyright.

## The `[DISABLE]` / `[ENABLE]` loop

`docs/assets/js/main.js` cycles the inline state word:

1. `[DISABLE]` for 1 second
2. random garbled token for 0.5 seconds
3. `[ENABLE]` for 1 second
4. random garbled token for 0.5 seconds
5. repeat

To change the timings, edit the `phases` array in `main.js`. There are no other animations on the page.

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
- **Style**: `assets/css/style.css`; colors and fonts are in the `:root` variables.
- **Notice close / state loop**: `assets/js/main.js`.
- **Screenshots**: replace `assets/img/room-desk.webp` or `room-door.webp`.
- **Footer**: edit the `<footer>` in `index.html`.

## Troubleshooting

- **404**: Confirm Pages uses branch `main` and folder `/docs`, wait 1–2 minutes, and make sure `docs/index.html` has been pushed.
- **Styles look stale**: Pages caches aggressively. Wait a moment or force refresh (`Cmd/Ctrl + Shift + R`).
- **Custom domain**: Enter it in Pages settings and GitHub will create a `CNAME` file, or add one under `docs/` and configure DNS.
