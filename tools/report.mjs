// Báo cáo test gộp: node tools/report.mjs [output/test/<lần chạy>] -> output/report/index.html (docs/TESTING.md
// "Báo cáo"). Đọc run.log, meta.json của một lần chạy tools/test.sh (mặc định lần mới nhất), so với lần chạy trước
// có cùng chuỗi lọc, và output/smoke/<mode>/<kịch bản>/smoke.log của tools/smoke.sh. Chỉ đọc log, không dựa vào mã
// thoát của Godot. Ảnh dẫn bằng đường dẫn tương đối.

import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'output');
const REPORT_DIR = join(OUT, 'report');

const read = (p) => (existsSync(p) ? readFileSync(p, 'utf8') : null);
const readJson = (p) => {
  const s = read(p);
  try { return s ? JSON.parse(s) : null; } catch { return null; }
};
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const git = (args) => {
  try { return execFileSync('git', ['-C', ROOT, '-c', 'core.quotepath=off', ...args], { encoding: 'utf8' }).trim(); } catch { return ''; }
};

// ---- Tầng 1: run_all.gd ----
function parseTestLog(text) {
  const r = { ok: [], fails: new Map(), allowed: [], summary: '', end: '', engine: new Map() };
  if (!text) return null;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trimEnd();
    let m;
    if ((m = line.match(/^ok {3}(\S+)/))) r.ok.push(m[1]);
    else if ((m = line.match(/^FAIL (\(.*?\)|\S+?): (.*)$/))) {
      const id = m[1], msg = m[2];
      if (!r.fails.has(id)) r.fails.set(id, []);
      r.fails.get(id).push(msg);
      const e = msg.match(/^lỗi engine: (.*?)(?: \(([^()]*:\d+[^()]*)\))?$/);
      if (e) {
        if (!r.engine.has(e[1])) r.engine.set(e[1], { count: 0, ids: new Set(), where: e[2] || '' });
        const g = r.engine.get(e[1]);
        g.count++; g.ids.add(id);
      }
    } else if ((m = line.match(/^ALLOWED (\S+?): (.*)$/))) r.allowed.push({ id: m[1], msg: m[2] });
    else if (line.startsWith('---- ')) r.summary = line.replace(/^-+ | -+$/g, '');
    else if (/^(ALL TESTS PASSED|TESTS FAILED)/.test(line)) r.end = line;
  }
  return r;
}

// ---- Tầng 2: smoke ----
function parseSmoke() {
  const base = join(OUT, 'smoke');
  if (!existsSync(base)) return [];
  const out = [];
  for (const mode of readdirSync(base)) {
    const mdir = join(base, mode);
    if (!statSync(mdir).isDirectory()) continue;
    for (const scen of readdirSync(mdir).sort()) {
      const dir = join(mdir, scen);
      const log = read(join(dir, 'smoke.log'));
      if (log === null) continue;
      const s = { mode, scen, dir, steps: [], shots: [], frames: [], invariants: [], warns: [], states: [], errors: '', end: '', real: false, meta: readJson(join(dir, 'meta.json')) };
      for (const raw of log.split(/\r?\n/)) {
        const line = raw.trimEnd();
        let m;
        if ((m = line.match(/^SMOKE STEP (.*)$/))) s.steps.push(m[1]);
        else if ((m = line.match(/^SMOKE SHOT (\S+)(.*)$/))) s.shots.push({ file: m[1], note: m[2].trim() });
        else if ((m = line.match(/^SMOKE FRAMES (.*)$/))) s.frames.push(m[1]);
        else if ((m = line.match(/^SMOKE INVARIANT (.*)$/))) s.invariants.push(m[1]);
        else if ((m = line.match(/^SMOKE WARN (.*)$/))) s.warns.push(m[1]);
        else if ((m = line.match(/^SMOKE STATE (.*)$/))) s.states.push(m[1]);
        else if ((m = line.match(/^SMOKE ERRORS (.*)$/))) s.errors = m[1];
        else if (line.startsWith('SMOKE REAL INPUT')) s.real = true;
        else if (/^SMOKE (OK|FAILED)/.test(line)) s.end = line;
      }
      s.mtime = statSync(join(dir, 'smoke.log')).mtime;
      out.push(s);
    }
  }
  return out;
}

// Các lần chạy tools/test.sh: output/test/<YYYYmmdd-HHMMSS>-<pid>/, xếp theo thời gian.
const TEST_DIR = join(OUT, 'test');
const runs = existsSync(TEST_DIR)
  ? readdirSync(TEST_DIR).filter((d) => /^\d{8}-\d{6}-\d+$/.test(d) && existsSync(join(TEST_DIR, d, 'run.log'))).sort()
  : [];
const arg = process.argv[2];
const curRun = arg ? arg.split(/[\\/]/).filter(Boolean).pop() : runs[runs.length - 1];
const meta = curRun ? readJson(join(TEST_DIR, curRun, 'meta.json')) : null;
const cur = curRun ? parseTestLog(read(join(TEST_DIR, curRun, 'run.log'))) : null;
// Lần trước: lần đã xong gần nhất trước curRun có cùng chuỗi lọc (phiên khác có thể chạy bộ lọc khác xen giữa).
const prevRun = runs.filter((d) => d < curRun).reverse()
  .find((d) => readJson(join(TEST_DIR, d, 'meta.json'))?.filter === (meta?.filter ?? ''));
const prev = prevRun ? parseTestLog(read(join(TEST_DIR, prevRun, 'run.log'))) : null;
const smoke = parseSmoke();
const commit = git(['log', '-1', '--format=%h %s']);
const branch = git(['rev-parse', '--abbrev-ref', 'HEAD']);
const dirty = git(['status', '--short']).split('\n').filter(Boolean);

const rcLabel = { 0: ['ok', 'Đạt'], 1: ['bad', 'Game có lỗi'], 2: ['warn', 'Hạ tầng test hỏng'] };
function badge(rc, fallback) {
  const [cls, label] = rcLabel[rc] || ['warn', fallback || 'Chưa rõ'];
  return `<span class="badge ${cls}">${esc(label)}</span>`;
}

let body = '';

// Đầu trang
body += `<header><h1>Báo cáo test Candy Away</h1><p class="sub">Sinh lúc ${esc(new Date().toLocaleString('vi-VN'))}` +
  ` · nhánh <code>${esc(branch)}</code> · commit <code>${esc(commit)}</code>` +
  ` · <details class="inline"><summary>${dirty.length} file đang sửa dở</summary><pre>${esc(dirty.join('\n'))}</pre></details></p></header>`;

// Tầng 1
if (cur) {
  const nFail = [...cur.fails.keys()].length;
  body += `<section><h2>Test (tools/test.sh) ${meta ? badge(meta.rc) : ''}</h2>`;
  if (meta) {
    body += `<p class="sub">Lần chạy <code>${esc(curRun)}</code> · ${esc(meta.started)} · ${meta.seconds} giây · lọc: <code>${esc(meta.filter || '(tất cả)')}</code> · ${esc(meta.why)} · Godot thoát ${meta.exit}</p>`;
  }
  body += `<div class="tiles"><div class="tile"><b>${cur.ok.length}</b><span>đạt</span></div>` +
    `<div class="tile ${nFail ? 'bad' : ''}"><b>${nFail}</b><span>lỗi</span></div>` +
    `<div class="tile ${cur.allowed.length ? 'warn' : ''}"><b>${cur.allowed.length}</b><span>bỏ qua (Skipped)</span></div>` +
    `<div class="tile"><b>${cur.engine.size}</b><span>loại lỗi engine</span></div></div>`;
  body += `<p><code>${esc(cur.end || 'không có dòng kết thúc')}</code> · ${esc(cur.summary)}</p>`;

  if (prev) {
    const prevFail = new Set(prev.fails.keys()), curFail = new Set(cur.fails.keys()), curOk = new Set(cur.ok);
    const fresh = [...curFail].filter((k) => !prevFail.has(k));
    const fixed = [...prevFail].filter((k) => !curFail.has(k) && curOk.has(k));
    body += `<h3>So với lần chạy trước <span class="sub">(<code>${esc(prevRun)}</code>, cùng bộ lọc)</span></h3><ul class="plain">` +
      `<li><span class="badge bad">Mới lỗi</span> ${fresh.length ? fresh.map((k) => `<code>${esc(k)}</code>`).join(', ') : 'không có'}</li>` +
      `<li><span class="badge ok">Hết lỗi</span> ${fixed.length ? fixed.map((k) => `<code>${esc(k)}</code>`).join(', ') : 'không có'}</li></ul>`;
  }

  if (nFail) {
    body += '<h3>Test lỗi</h3><table><thead><tr><th>Test</th><th>Lý do</th></tr></thead><tbody>';
    for (const [id, msgs] of cur.fails) {
      const shown = msgs.slice(0, 8).map((m) => `<div>${esc(m)}</div>`).join('');
      const more = msgs.length > 8 ? `<div class="sub">… thêm ${msgs.length - 8} dòng</div>` : '';
      body += `<tr><td><code>${esc(id)}</code></td><td>${shown}${more}</td></tr>`;
    }
    body += '</tbody></table>';
  }
  if (cur.engine.size) {
    body += '<h3>Lỗi engine gom theo nội dung</h3><table><thead><tr><th>Lỗi</th><th>Lần</th><th>Ở test</th></tr></thead><tbody>';
    for (const [msg, g] of [...cur.engine].sort((a, b) => b[1].count - a[1].count)) {
      body += `<tr><td>${esc(msg)}${g.where ? `<div class="sub">${esc(g.where)}</div>` : ''}</td><td>${g.count}</td><td>${[...g.ids].map((i) => `<code>${esc(i)}</code>`).join(' ')}</td></tr>`;
    }
    body += '</tbody></table>';
  }
  if (cur.allowed.length) {
    body += '<h3>Bỏ qua theo allowlist (Skipped, không phải Passed)</h3><table><thead><tr><th>Test</th><th>Mục</th></tr></thead><tbody>';
    for (const a of cur.allowed) body += `<tr><td><code>${esc(a.id)}</code></td><td>${esc(a.msg)}</td></tr>`;
    body += '</tbody></table>';
  }
  body += '</section>';
} else {
  body += '<section><h2>Test</h2><p>Chưa có lần chạy nào trong <code>output/test/</code>: chạy <code>tools/test.sh</code>.</p></section>';
}

// Tầng 2
body += '<section><h2>Smoke (tools/smoke.sh)</h2>';
if (!smoke.length) body += '<p>Chưa có kết quả smoke trong <code>output/smoke/</code>.</p>';
for (const s of smoke) {
  const ok = s.end.startsWith('SMOKE OK') && !s.real;
  const rc = s.meta?.rc ?? (ok ? 0 : s.end ? 1 : 2);
  body += `<article class="card"><h3>${esc(s.scen)} <span class="sub">${esc(s.mode)}</span> ${badge(rc)}</h3>`;
  body += `<p class="sub">${esc(s.mtime.toLocaleString('vi-VN'))} · ${s.steps.length} bước · <code>${esc(s.end || 'không có dòng kết thúc')}</code>${s.errors ? ` · lỗi ${esc(s.errors)}` : ''}${s.real ? ' · <b>có input thật, lần chạy không hợp lệ</b>' : ''}</p>`;
  if (s.states.length) body += `<h4>Trạng thái lúc dừng</h4><pre>${esc(s.states.join(String.fromCharCode(10)))}</pre>`;
  if (s.invariants.length) body += `<h4>Vi phạm bất biến</h4><ul>${s.invariants.map((x) => `<li>${esc(x)}</li>`).join('')}</ul>`;
  if (s.warns.length) body += `<h4>Cảnh báo</h4><ul>${s.warns.map((x) => `<li>${esc(x)}</li>`).join('')}</ul>`;
  if (s.frames.length) body += `<h4>Khung hình</h4><pre>${esc(s.frames.join('\n'))}</pre>`;
  if (s.steps.length) body += `<details><summary>Các bước</summary><ol>${s.steps.map((x) => `<li>${esc(x)}</li>`).join('')}</ol></details>`;
  if (s.shots.length) {
    body += '<div class="shots">';
    for (const shot of s.shots) {
      const rel = relative(REPORT_DIR, join(s.dir, shot.file)).split('\\').join('/');
      body += `<a href="${esc(rel)}" target="_blank"><img loading="lazy" src="${esc(rel)}" alt="${esc(shot.file)}"><span>${esc(shot.file)}</span></a>`;
    }
    body += '</div>';
  }
  body += '</article>';
}
body += '</section>';

const html = `<!doctype html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Báo cáo test</title>
<style>
:root { --bg:#f7f6f3; --fg:#1d1d1f; --muted:#6b6b70; --card:#ffffff; --line:#e3e1dc; --ok:#1f7a3f; --bad:#b3261e; --warn:#9a5b00; --code:#efede8; }
@media (prefers-color-scheme: dark) { :root { --bg:#161618; --fg:#ececee; --muted:#9a9aa1; --card:#1f1f22; --line:#33333a; --ok:#5cc785; --bad:#ff8a80; --warn:#f0b35a; --code:#2a2a2f; } }
* { box-sizing: border-box; }
body { margin:0; padding:24px 16px 64px; background:var(--bg); color:var(--fg); font:15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
main { max-width:1100px; margin:0 auto; }
h1 { font-size:24px; margin:0 0 4px; } h2 { font-size:19px; margin:32px 0 8px; } h3 { font-size:16px; margin:20px 0 8px; } h4 { font-size:14px; margin:12px 0 4px; }
.sub { color:var(--muted); font-size:13px; }
code, pre { background:var(--code); border-radius:4px; font:12.5px/1.45 ui-monospace, Consolas, monospace; }
code { padding:1px 5px; } pre { padding:10px; overflow:auto; }
.badge { display:inline-block; padding:1px 8px; border-radius:999px; font-size:12px; font-weight:600; border:1px solid currentColor; vertical-align:middle; }
.ok { color:var(--ok); } .bad { color:var(--bad); } .warn { color:var(--warn); }
.tiles { display:flex; flex-wrap:wrap; gap:12px; margin:12px 0; }
.tile { background:var(--card); border:1px solid var(--line); border-radius:8px; padding:10px 16px; min-width:120px; }
.tile b { display:block; font-size:24px; } .tile span { color:var(--muted); font-size:13px; }
table { width:100%; border-collapse:collapse; background:var(--card); border:1px solid var(--line); border-radius:8px; overflow:hidden; display:block; overflow-x:auto; }
th, td { text-align:left; vertical-align:top; padding:8px 10px; border-bottom:1px solid var(--line); }
th { font-size:13px; color:var(--muted); font-weight:600; }
.card { background:var(--card); border:1px solid var(--line); border-radius:8px; padding:4px 16px 12px; margin:12px 0; }
.shots { display:flex; flex-wrap:wrap; gap:10px; margin-top:8px; }
.shots a { display:flex; flex-direction:column; gap:4px; width:130px; color:var(--muted); font-size:11px; text-decoration:none; word-break:break-all; }
.shots img { width:130px; border:1px solid var(--line); border-radius:6px; background:var(--code); }
ul.plain { list-style:none; padding:0; } ul.plain li { margin:6px 0; }
details.inline { display:inline; } details.inline pre { margin-top:6px; }
</style></head>
<body><main>${body}</main></body></html>
`;

mkdirSync(REPORT_DIR, { recursive: true });
writeFileSync(join(REPORT_DIR, 'index.html'), html);
console.log(join(REPORT_DIR, 'index.html'));
