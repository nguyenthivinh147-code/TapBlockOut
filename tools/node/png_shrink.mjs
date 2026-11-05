// Shrinks PNG files the export stores raw instead of importing, i.e. the boot splash (application/boot_splash/image).
// Godot loads the boot splash before the WebP/JPG loaders are registered, so it must stay a PNG.
// Re-encodes as 24/32-bit PNG (zlib level 9, adaptive filtering, no palette: a 256-colour palette shifts the candy
// colours and dithers the pastel sky). --drop-bits=N first rounds each colour channel to a multiple of 2^N (alpha
// untouched), which removes the noise PNG cannot compress; N=2 keeps the error within +-2 levels without visible
// banding on the splash, N=3 bands the sky. Rounding is idempotent, so running again on the output changes nothing.
// Without --drop-bits the file is only replaced when the decoded pixels stay identical.
// Run: npm ci --prefix tools/node && node tools/node/png_shrink.mjs [--drop-bits=2] assets/ui/boot_splash.png

import fs from "fs";
import sharp from "sharp";

let dropBits = 0;
const files = [];
for (const a of process.argv.slice(2)) {
  if (a.startsWith("--drop-bits=")) dropBits = Number(a.slice(12));
  else files.push(a);
}
if (files.length === 0 || !(dropBits >= 0 && dropBits <= 4)) {
  console.error("usage: node tools/node/png_shrink.mjs [--drop-bits=0..4] <file.png> [...]");
  process.exit(2);
}

const kb = (n) => `${(n / 1024).toFixed(0)} KB`;
const encode = (raw, info) =>
  sharp(raw, { raw: { width: info.width, height: info.height, channels: info.channels } })
    .png({ compressionLevel: 9, adaptiveFiltering: true, palette: false })
    .toBuffer();

let failed = false;
for (const file of files) {
  const src = fs.readFileSync(file);
  const meta = await sharp(src).metadata();
  if (meta.format !== "png" || meta.depth !== "uchar") {
    console.error(`${file}: skipped (${meta.format}, ${meta.depth}); only 8-bit PNG is supported`);
    failed = true;
    continue;
  }
  const { data, info } = await sharp(src).raw().toBuffer({ resolveWithObject: true });
  const target = Buffer.from(data);
  if (dropBits > 0) {
    const half = 1 << (dropBits - 1);
    const alpha = info.channels === 4 || info.channels === 2 ? info.channels - 1 : -1;
    for (let i = 0; i < target.length; i++) {
      if (i % info.channels !== alpha) target[i] = Math.min(255, ((target[i] + half) >> dropBits) << dropBits);
    }
  }
  const out = await encode(target, info);
  const check = await sharp(out).raw().toBuffer();
  if (!check.equals(target)) {
    console.error(`${file}: encoded pixels differ from the target, file left unchanged`);
    failed = true;
    continue;
  }
  let se = 0;
  for (let i = 0; i < data.length; i++) se += (data[i] - target[i]) ** 2;
  const psnr = se === 0 ? "lossless" : `PSNR ${(10 * Math.log10((255 * 255 * data.length) / se)).toFixed(1)} dB`;
  if (out.length >= src.length) {
    console.log(`${file}: ${kb(src.length)}, re-encoding is not smaller (${kb(out.length)}), unchanged`);
    continue;
  }
  fs.writeFileSync(file, out);
  console.log(`${file}: ${kb(src.length)} -> ${kb(out.length)} (${psnr})`);
}
process.exit(failed ? 1 : 0);
