# ESCAPE_02 项目介绍网站

这是 `escape-02` 的 GitHub Pages 站点，纯静态 HTML / CSS / JS，没有构建步骤，也没有外部 CDN 依赖。

线上地址：<https://chenyue321.github.io/escape-02/>

## 文件

```
docs/
├── index.html                  # 整站内容（单页）
├── .nojekyll                   # 让 GitHub Pages 跳过 Jekyll
├── README.md                   # 本文件
└── assets/
    ├── css/style.css           # 样式
    ├── js/main.js              # 时钟、导航、滚动淡入、截图灯箱
    ├── fonts/                  # VT323 字体 + OFL 许可
    ├── favicon.svg
    └── img/                    # 压缩后的 WebP 截图 + OG 封面
```

## 本地预览

在仓库根目录执行：

```bash
python3 -m http.server 4173 --directory docs
```

然后打开 <http://127.0.0.1:4173/>。

直接用浏览器打开 `docs/index.html` 也能看，但本地服务器更接近线上行为。

## 第一次上线

1. 把 `docs/` 提交并推送到 `main`。
2. 打开仓库 **Settings → Pages**。
3. **Build and deployment → Source** 选 **Deploy from a branch**。
4. **Branch** 选 `main`，目录选 `/docs`，点 **Save**。
5. 等 1–2 分钟，访问 <https://chenyue321.github.io/escape-02/>。

仓库是公开仓库，不需要 GitHub Pro。之后每次推送到 `main`，Pages 都会自动重新发布。

## 发布可下载的 demo

站点的“下载 demo”按钮指向仓库的 Releases 页面。当前还没有 Release 时，用户会看到空页面，所以建议先发一版：

1. 打开仓库 **Releases → Draft a new release**。
2. Tag 填 `v0.1.0`（或当前版本号），标题写 `ESCAPE_02 v0.1.0`。
3. 把 `build/release/` 下的四个 zip 拖进去：
   - `ESCAPE_02-macOS-universal.zip`
   - `ESCAPE_02-Windows-x86_64.zip`
   - `ESCAPE_02-Linux-x86_64.zip`
   - `ESCAPE_02-Linux-arm64.zip`
4. 写两句更新说明，点 **Publish release**。

注意：`build/` 在 `.gitignore` 里，构建包不要提交进仓库，直接作为 Release 附件上传即可。单个附件默认上限 2 GB，这几个包都远小于上限。

## 更新内容

- **改文案**：直接编辑 `docs/index.html`，中文正文都在对应 `<section>` 里。
- **换截图**：把新图压到 1280 px 宽左右，覆盖 `docs/assets/img/` 里的同名 WebP；或者在 HTML 里改 `src`。
- **换主视觉 / OG 封面**：`docs/assets/img/hero-room.webp` 是首屏背景，`og-cover.jpg` 是分享卡片（1200×630）。
- **颜色 / 字体**：`docs/assets/css/style.css` 顶部的 `:root` 变量。
- **最近更新时间**：目前没有动态数据，避免 API 限流和额外依赖；需要的话可以加 `fetch` 拉 GitHub API。

## 截图从哪来

`build/preview/` 是开发时的原始截图，已被 `.gitignore` 排除。`docs/assets/img/` 是从中挑出来、转成 WebP 并压缩后的网页版本。原图更新后可以重新导出：

```bash
# 需要 Pillow
python3 - <<'PY'
from PIL import Image
im = Image.open('build/preview/facility-ui.png').convert('RGB')
im.save('docs/assets/img/facility-ui.webp', 'WEBP', quality=82, method=6)
PY
```

## 常见问题

- **访问 404**：确认 Pages 的目录是 `/docs`、分支是 `main`，再等 1–2 分钟；确认 `docs/index.html` 已推送。
- **样式没更新**：Pages 有 CDN 缓存，等一会儿或强制刷新（`Cmd/Ctrl + Shift + R`）。
- **macOS 打不开 demo**：构建没有签名，首次打开请右键 → 打开；或在“系统设置 → 隐私与安全性”里允许。
- **自定义域名**：在 Pages 设置里填域名，GitHub 会生成 `CNAME`；也可以在 `docs/` 里手动放 `CNAME` 文件并配置 DNS。

## 说明

站点里的截图和文案来自项目 README；页面本身与游戏一样，会随着项目继续改。
