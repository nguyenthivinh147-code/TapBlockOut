// Subsets the Hangul (Jua) and Japanese (M PLUS Rounded 1c) fallback fonts to the characters the game shows, so the
// MSDF FontFiles that tools/gen_baloo_font.gd builds from them stay small (2.3 MB of TTF data -> about 0.6 MB).
// Kept: every character found in SOURCES, plus FIXED_RANGES (ASCII, Latin-1, punctuation, CJK punctuation, all kana,
// Hangul compatibility jamo, fullwidth forms). Hangul syllables and kanji outside the game's texts are dropped; a
// player typing one (change-name popup, help message) gets it from the system font through TextServer fallback.
// tests/test_font_subset.gd scans SOURCES the same way and fails when a text uses a character the full font has but
// the subset lacks: run this tool, then gen_baloo_font.gd, again.
// Run: npm ci --prefix tools/node && node tools/node/subset_fonts.mjs
//      tools/godot.sh --headless --path . -s res://tools/gen_baloo_font.gd

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import subsetFont from "subset-font";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
// Keep in sync with tests/test_font_subset.gd.
const SOURCES = ["i18n", "scenes", "data", "src"];
const EXTENSIONS = /\.(csv|tscn|tres|json|gd)$/;
const FIXED_RANGES = [
  [0x0020, 0x007e], [0x00a0, 0x00ff], [0x2000, 0x206f], // ASCII, Latin-1, general punctuation
  [0x3000, 0x30ff], [0x3130, 0x318f], [0xff00, 0xffef], // CJK punctuation, kana, Hangul compatibility jamo, fullwidth
];
// FreeType's auto-hinter (Godot loads MSDF outlines with light hinting) measures CJK blue zones on these reference
// characters (afblue.dat, CJK top/bottom/left/right, standard chars 田囗); without them it snaps kana and kanji edges
// differently from the full font.
const HINTER_REFERENCE =
  "他们你來們到和地對就席我時會為能舰說说這这齊军同已愿既星是景民照现現理用置要軍那配里開雷露面顾" +
  "个为人以個大小有主些因它想意生當看着者自著裡过还进進過道還" +
  "她将將年得情最样樣通即吗吧听呢品响嗎师師收断斷明眼間间际陈限除陳随際隨" +
  "事前學或政斯新民沒没然特球第經谁起例別别制动動增指朝期构物确种調调費费都田囗";
const FONTS = [
  { src: "art/fonts/Jua-Regular.ttf", out: "art/fonts/subset/Jua-Regular.ttf" },
  { src: "art/fonts/MPLUSRounded1c-Bold.ttf", out: "art/fonts/subset/MPLUSRounded1c-Bold.ttf" },
];

const chars = new Set();
function scan(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) scan(p);
    else if (EXTENSIONS.test(e.name)) for (const c of fs.readFileSync(p, "utf8")) chars.add(c.codePointAt(0));
  }
}
for (const d of SOURCES) scan(path.join(ROOT, d));
for (const [a, b] of FIXED_RANGES) for (let c = a; c <= b; c++) chars.add(c);
for (const c of HINTER_REFERENCE) chars.add(c.codePointAt(0));
const text = String.fromCodePoint(...[...chars].filter((c) => c >= 0x20).sort((a, b) => a - b));

const kb = (n) => `${(n / 1024).toFixed(0)} KB`;
for (const f of FONTS) {
  const src = fs.readFileSync(path.join(ROOT, f.src));
  const out = await subsetFont(src, text, { targetFormat: "truetype" });
  fs.mkdirSync(path.dirname(path.join(ROOT, f.out)), { recursive: true });
  fs.writeFileSync(path.join(ROOT, f.out), out);
  console.log(`${f.src}: ${kb(src.length)} -> ${f.out}: ${kb(out.length)}`);
}
console.log(`${chars.size} code points requested`);
