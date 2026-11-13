// Coverage map for tools/affected.sh: which test file runs which method of src/**/*.gd (docs/TESTING.md
// "Chọn test theo thay đổi").
//
//   tools/affected.sh --coverage [--keep] [test filter...]
//
// With filters only those test files run, and their rows replace theirs in the existing map (tools/affected.sh --run
// does this for the tests it selects).
//
// Copies the working tree to output/coverage/snap-<pid>, puts at the top of every method of src/**/*.gd a line that marks
// the method in tests/coverage_hits.gd (and one member per script that marks "<new>" when an object is created), runs
// tools/test.sh there with CANDY_COV_OUT set (tests/run_all.gd writes one JSON line per test file), then writes
// output/coverage/map.json. The source tree is never changed.
import { spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { gdMembers } from './gd_members.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const COV_MAP = 'output/coverage/map.json';
export const NEW_ID = '<new>';
// One copy per process: several sessions share this tree.
const SNAP = `output/coverage/snap-${process.pid}`;
const HITS = 'res://tests/coverage_hits.gd';
const INSTRUMENT = /^src\/.+\.gd$/;
const SKIP_PREFIXES = ['.godot/', 'output/', 'build/'];

const sha1 = (s) => crypto.createHash('sha1').update(s).digest('hex');

function git(args, cwd = ROOT, allowFail = false) {
  const r = spawnSync('git', ['-c', 'core.quotepath=off', ...args], { cwd, encoding: 'utf8', maxBuffer: 256 << 20 });
  if (r.status !== 0) {
    if (allowFail) return '';
    throw new Error(`git ${args.join(' ')}: ${(r.stderr || '').trim()}`);
  }
  return r.stdout;
}

// Instrumented copy of one script. `key` makes the inserted names unique, so a script that extends another one
// does not redeclare its parent's members. Inner classes cannot read the outer static var, so they use the const.
export function instrument(text, file, key) {
  const members = gdMembers(text);
  const lines = text.split('\n');
  const C = `__COV_${key}`;
  const V = `__cov_${key}`;
  const head = [`const ${C} = preload("${HITS}")`, `static var ${V}: Dictionary = ${C}.hits`,
    `var __covi_${key}: bool = ${V}.set(&"${file}:${NEW_ID}", true)`];
  let header = -1;
  for (const m of members) {
    if (m.cls) continue;
    if (m.kind !== 'header') break;
    header = m.end - 1;
  }
  const after = new Map();
  const replace = new Map();
  const ids = [NEW_ID];
  for (const m of members) {
    if (m.kind !== 'func' || m.abstract) continue;
    ids.push(m.id);
    const hit = `${m.bodyIndent}${m.cls ? `${C}.hits` : V}[&"${file}:${m.id}"] = true`;
    const j = m.sigEnd - 1;
    if (m.oneLiner) {
      const l = lines[j];
      replace.set(j, [l.slice(0, m.colon + 1), hit, `${m.bodyIndent}${l.slice(m.colon + 1).trimStart()}`]);
    } else {
      if (!after.has(j)) after.set(j, []);
      after.get(j).push(hit);
    }
  }
  const out = header < 0 ? [...head] : [];
  lines.forEach((l, i) => {
    out.push(...(replace.get(i) ?? [l]));
    if (i === header) out.push(...head);
    out.push(...(after.get(i) ?? []));
  });
  return { text: out.join('\n'), ids };
}

function listFiles() {
  return [...new Set(git(['ls-files', '-z', '-co', '--exclude-standard']).split('\0'))]
    .filter((f) => f && !SKIP_PREFIXES.some((s) => f.startsWith(s)) && fs.existsSync(path.join(ROOT, f)));
}

function readJsonl(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').split('\n').filter(Boolean).map((l) => {
    try {
      return JSON.parse(l);
    } catch {
      return null;
    }
  }).filter(Boolean);
}

function summary(map, runRc, seconds, failLines) {
  const dirs = new Map();
  let total = 0;
  let hit = 0;
  const cold = [];
  for (const [f, info] of Object.entries(map.files)) {
    const d = f.split('/').slice(0, 2).join('/');
    if (!dirs.has(d)) dirs.set(d, [0, 0]);
    const ids = Object.entries(info.funcs).filter(([id]) => id !== NEW_ID);
    const h = ids.filter(([, t]) => t.length).length;
    dirs.get(d)[0] += h;
    dirs.get(d)[1] += ids.length;
    hit += h;
    total += ids.length;
    if (ids.length && !h && !info.funcs[NEW_ID]?.length) cold.push(f);
  }
  const pct = (a, b) => (b ? `${Math.round((100 * a) / b)}%` : '-');
  console.log(`\nĐộ phủ theo hàm: ${hit}/${total} (${pct(hit, total)}), ${map.tests.length} file test, ${seconds} giây`);
  for (const [d, [h, n]] of [...dirs].sort()) console.log(`  ${d.padEnd(16)} ${String(h).padStart(5)}/${String(n).padEnd(5)} ${pct(h, n)}`);
  if (cold.length) console.log(`File src/ không test nào chạy tới (${cold.length}): ${cold.slice(0, 12).join(', ')}${cold.length > 12 ? ', ...' : ''}`);
  const bad = map.tests.filter((t) => t.failed);
  if (bad.length) {
    console.log(`Test lỗi trong lần đo (${bad.length}), tools/affected.sh chọn chúng theo đồ thị tĩnh: ${bad.map((t) => t.name).join(' ')}`);
    for (const l of failLines.slice(0, 8)) console.log(`  ${l}`);
  }
  if (runRc === 2) console.log('Lần đo không chạy hết (tools/test.sh mã 2): bản đo thiếu các file test sau chỗ dừng.');
  console.log(`Ghi ${COV_MAP}`);
}

// The map after a run. base null: a new map. Otherwise each row replaces what the map knew about that test file,
// and every script gets the method ids of its current source (hits of tests not run stay as they were).
export function buildMap(base, rows, funcs, meta) {
  const map = base ? structuredClone(base) : { version: 1, tests: [], files: {} };
  const idx = new Map(map.tests.map((t, i) => [t.name, i]));
  const files = {};
  for (const [f, info] of Object.entries(funcs)) {
    const old = map.files[f]?.funcs || {};
    files[f] = { sha1: info.sha1, funcs: Object.fromEntries(info.ids.map((id) => [id, [...(old[id] || [])]])) };
  }
  map.files = files;
  for (const r of rows) {
    const name = String(r.test);
    let ti = idx.get(name);
    if (ti == null) {
      ti = map.tests.length;
      idx.set(name, ti);
    } else {
      for (const info of Object.values(map.files)) {
        for (const list of Object.values(info.funcs)) {
          const k = list.indexOf(ti);
          if (k >= 0) list.splice(k, 1);
        }
      }
    }
    map.tests[ti] = { name, ms: Number(r.ms) || 0, failed: Number(r.failed) || 0 };
    for (const h of r.hits || []) {
      const k = h.lastIndexOf(':');
      const info = map.files[h.slice(0, k)];
      if (!info) continue;
      const id = h.slice(k + 1);
      if (!info.funcs[id]) info.funcs[id] = [];
      if (!info.funcs[id].includes(ti)) info.funcs[id].push(ti);
    }
  }
  return Object.assign(map, meta);
}

export function main(argv) {
  const opts = { keep: false, filters: [] };
  for (const a of argv) {
    if (a === '--keep') opts.keep = true;
    else if (a.startsWith('-')) {
      console.error(`tham số lạ cho --coverage: ${a}`);
      return 2;
    } else opts.filters.push(a);
  }
  return runCoverage(opts).rc;
}

// Runs tools/test.sh (all tests, or `filters`) on an instrumented copy and writes the map: a new one for a full run,
// merged into the existing map for a filtered run. The test log is copied back to output/test/. Returns {rc, map}.
export function runCoverage(opts) {
  const started = Date.now();
  const snap = path.join(ROOT, SNAP);
  fs.rmSync(snap, { recursive: true, force: true });
  fs.mkdirSync(snap, { recursive: true });
  const files = listFiles();
  for (const f of files) {
    fs.mkdirSync(path.dirname(path.join(snap, f)), { recursive: true });
    fs.copyFileSync(path.join(ROOT, f), path.join(snap, f));
  }
  if (fs.existsSync(path.join(ROOT, '.godot'))) {
    fs.cpSync(path.join(ROOT, '.godot'), path.join(snap, '.godot'), { recursive: true });
  }
  const funcs = {};
  for (const f of files.filter((x) => INSTRUMENT.test(x))) {
    const src = fs.readFileSync(path.join(ROOT, f), 'utf8');
    const r = instrument(src, f, sha1(f).slice(0, 8));
    fs.writeFileSync(path.join(snap, f), r.text);
    funcs[f] = { sha1: sha1(src), ids: r.ids };
  }
  // test_static_check and test_affected list files with git; a repo of its own also stops git from finding ours.
  git(['-c', 'init.defaultBranch=main', 'init', '-q'], snap);
  git(['add', '-A', '--intent-to-add'], snap);
  git(['-c', 'user.name=coverage', '-c', 'user.email=coverage@localhost', 'commit', '-q', '--allow-empty', '-m', 'snapshot'], snap);
  const jsonl = path.join(snap, 'coverage.jsonl');
  console.log(`Chèn lệnh đo vào ${Object.keys(funcs).length} script src/, chạy tools/test.sh ${opts.filters.join(' ')} trong ${SNAP}`);
  const env = { ...process.env, CANDY_COV_OUT: jsonl, XDG_DATA_HOME: path.join(snap, '.xdg'),
    TEST_TIMEOUT: process.env.TEST_TIMEOUT || '5400', TEST_FILE_TIMEOUT: process.env.TEST_FILE_TIMEOUT || '600' };
  const run = spawnSync('bash', ['tools/test.sh', ...opts.filters], { cwd: snap, stdio: 'inherit', env });
  const runRc = run.status ?? 2;
  const rows = readJsonl(jsonl);
  let failLines = [];
  const runDir = fs.existsSync(path.join(snap, 'output/test')) ? fs.readdirSync(path.join(snap, 'output/test')).sort().pop() : null;
  if (runDir) {
    const from = path.join(snap, 'output/test', runDir);
    failLines = fs.readFileSync(path.join(from, 'run.log'), 'utf8').split('\n').filter((l) => l.startsWith('FAIL '));
    // The run belongs in this tree's history and report, not in the copy that is about to go.
    fs.cpSync(from, path.join(ROOT, 'output/test', runDir), { recursive: true });
    spawnSync('node', ['tools/report.mjs', path.join('output/test', runDir)], { cwd: ROOT, stdio: 'ignore' });
  }
  if (!rows.length) {
    console.log(`Không có dữ liệu độ phủ (${jsonl} rỗng); giữ ${SNAP} để xem log.`);
    return { rc: 2, map: null };
  }
  const full = opts.filters.length === 0;
  const base = full ? null : readMap();
  const now = new Date().toISOString();
  const dirty = git(['status', '--porcelain', '-z'], ROOT, true).split('\0').filter(Boolean).map((l) => l.slice(3));
  const meta = base
    ? { updated: now, updates: (base.updates || 0) + 1 }
    : { created: now, commit: git(['rev-parse', 'HEAD']).trim(), dirty, filters: opts.filters,
      complete: runRc !== 2 && full };
  const map = buildMap(base, rows, funcs, meta);
  fs.mkdirSync(path.dirname(path.join(ROOT, COV_MAP)), { recursive: true });
  const tmp = `${path.join(ROOT, COV_MAP)}.${process.pid}`;
  fs.writeFileSync(tmp, JSON.stringify(map));
  fs.renameSync(tmp, path.join(ROOT, COV_MAP));
  const seconds = Math.round((Date.now() - started) / 1000);
  if (full) summary(map, runRc, seconds, failLines);
  else console.log(`Đo ${rows.length} file test (${seconds} giây), ${base ? 'gộp vào' : 'ghi'} ${COV_MAP}`);
  if (!opts.keep) fs.rmSync(snap, { recursive: true, force: true });
  return { rc: runRc, map };
}

function readMap() {
  try {
    const m = JSON.parse(fs.readFileSync(path.join(ROOT, COV_MAP), 'utf8'));
    return m.version === 1 && Array.isArray(m.tests) && m.files ? m : null;
  } catch {
    return null;
  }
}
