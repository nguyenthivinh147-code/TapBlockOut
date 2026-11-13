#!/usr/bin/env node
// Picks the tests and smoke scenarios a change needs (docs/TESTING.md, "Chọn test theo thay đổi").
//
//   node tools/affected.mjs [ref] [--run] [--json] [-v] [--files <file[:lines]>...]
//   node tools/affected.mjs --check
//
// ref: compare with the merge base of ref and HEAD (default HEAD), plus staged, unstaged and untracked files.
// --files a.gd b.gd:12-30,41: these files (and lines) instead of git diff.
//
// Reference graph: file A depends on B when A names B by a res:// path (a prefix when the path is built at run time),
// a uid://, an autoload name, a quoted file name (popup_reward.gd, "ShopCashLayer"), or a shader #include.
// Tests: every tests/test_*.gd that reaches a changed file in the graph, plus test: targets of map rules that match
// the changed file itself. Smoke: from each changed file, walk up the graph and stop at files a map rule names
// (tests/affected_map.txt); scen_* functions that quote the file name add their scenario. An edit inside
// tests/smoke/*.gd maps to the scen_* functions that reach the edited lines through calls.
//
// With a coverage map (output/coverage/map.json, built by --coverage) tests come from what they ran instead: a
// changed method selects the tests that entered it; a changed const/var/signal the tests of the methods naming it;
// a scene the tests that created its own script; other files walk the graph up to the nearest covered script.
// Tests the map does not know (new, or failed during the coverage run) still come from the graph.
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { COV_MAP, NEW_ID, runCoverage } from './coverage.mjs';
import { gdMembers, isCommentOrBlank, memberAt } from './gd_members.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const MAP_PATH = 'tests/affected_map.txt';
const SMOKE_DIR = 'tests/smoke/';
const V_SAMPLE = [1, 40];
const SKIP_PREFIXES = ['.godot/', 'output/', 'build/', 'reference/'];
const TEXT_EXT = new Set(['gd', 'tscn', 'tres', 'gdshader', 'gdshaderinc', 'godot', 'cfg', 'json']);
const MAX_TEXT = 2 << 20;
// They name every autoload, translation and export filter: walking into them would select everything.
const ROOTS = new Set(['project.godot', 'export_presets.cfg']);
// Changes the player sees: run their scenarios with a window and read the PNGs.
const VISIBLE = [/^src\/ui\//, /^scenes\//, /^assets\//, /^data\/ui_unity\//, /^i18n\//, /\.gdshader(inc)?$/];
// Changes only a phone exercises (plugin, real SDK backends, export).
const DEVICE_ONLY = [/^android\//, /^src\/platform\/android_/, /^addons\/GodotGooglePlayBilling\//,
  /^export_presets\.cfg$/, /^tools\/device_smoke\.sh$/, /^tests\/smoke\/device_main\.tscn$/];
const GAME_CONTENT = /^(src|scenes)\//;
const ASSET_EXT = new Set(['png', 'webp', 'jpg', 'jpeg', 'svg', 'ogg', 'wav', 'mp3', 'ttf', 'otf']);
// Every file preloads config.gd: its ids and icon names ("gold_pack") would tie each asset to the whole game.
const NO_BARE_NAMES = new Set(['src/config.gd']);
// Unity layer data quotes the sprites it draws ("Popup_Lose", "Atlas:Sprite_2").
const NAME_JSON = /^data\/ui_unity\/[^_/][^/]*\.json$/;
// Name → file indexes (every sprite, every prefab): the files that ask for a name use it, not the index's readers.
const INDEXES = /^data\/ui_unity\/_[^/]+\.json$/;
const TEST_FILE = /^tests\/(test_[^/]+)\.gd$/;
// Scripts the coverage run instruments (tools/coverage.mjs).
const COVERED = /^src\/.+\.gd$/;
// Methods allowed to have no test (tools/affected.sh --run fails on the others).
const ALLOW_PATH = 'tests/untested_allow.txt';

// ------------------------------------------------------------------ helpers

function git(args, allowFail = false) {
  const r = spawnSync('git', ['-c', 'core.quotepath=off', ...args], { cwd: ROOT, encoding: 'utf8', maxBuffer: 256 << 20 });
  if (r.status !== 0) {
    if (allowFail) return '';
    throw new Error(`git ${args.join(' ')}: ${(r.stderr || '').trim()}`);
  }
  return r.stdout;
}

const base = (p) => path.posix.basename(p);
const ext = (p) => { const b = base(p); const i = b.lastIndexOf('.'); return i > 0 ? b.slice(i + 1) : ''; };
const stem = (p) => { const b = base(p); const i = b.lastIndexOf('.'); return i > 0 ? b.slice(0, i) : b; };
// An edited foo.png.import or foo.gd.uid stands for foo.png / foo.gd.
const owner = (p) => p.replace(/\.(import|uid)$/, '');
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
// File names worth matching as quoted strings: "popup_reward", "ShopCashLayer"; not "shop", "level".
const distinct = (n) => n.length >= 6 && (n.includes('_') || /[a-z][A-Z]/.test(n));

function readText(rel) {
  try {
    return fs.readFileSync(path.join(ROOT, rel), 'utf8');
  } catch {
    return null;
  }
}

function listFiles() {
  const out = git(['ls-files', '-z', '-co', '--exclude-standard']);
  return [...new Set(out.split('\0'))]
    .filter((f) => f && !SKIP_PREFIXES.some((s) => f.startsWith(s)) && fs.existsSync(path.join(ROOT, f)));
}

// GDScript without comments ("Game cộng reward" in a doc comment is not a use of Game), and also without string
// contents (for autoload names: tr("Game over") is not one either).
function stripGd(text) {
  const code = [];
  const bare = [];
  for (const line of text.split('\n')) {
    let quote = null;
    let a = '';
    let b = '';
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (quote) {
        a += c;
        if (c === '\\') a += line[++i] ?? '';
        else if (c === quote) {
          quote = null;
          b += '""';
        }
        continue;
      }
      if (c === '#') break;
      a += c;
      if (c === '"' || c === "'") quote = c;
      else b += c;
    }
    code.push(a);
    bare.push(b);
  }
  return { code: code.join('\n'), bare: bare.join('\n') };
}

function parseAutoloads(text) {
  const out = [];
  let inSection = false;
  for (const line of text.split(/\r?\n/)) {
    if (line.startsWith('[')) {
      inSection = line.trim() === '[autoload]';
      continue;
    }
    const m = inSection && /^(\w+)="\*?res:\/\/([^"]+)"/.exec(line);
    if (m && !m[1].startsWith('_')) out.push([m[1], m[2]]);
  }
  return out;
}

// ------------------------------------------------------------------ reference graph

function buildGraph(files) {
  const fileSet = new Set(files);
  const dirs = new Set();
  for (const f of files) for (let i = f.indexOf('/'); i >= 0; i = f.indexOf('/', i + 1)) dirs.add(f.slice(0, i + 1));
  const uids = new Map();
  const texts = new Map();
  const byName = new Map();
  const addName = (n, f, bare = false) => {
    if (!distinct(n)) return;
    if (!byName.has(n)) byName.set(n, []);
    byName.get(n).push({ f, bare });
  };
  for (const f of files) {
    if (f.endsWith('.uid')) {
      const m = /uid:\/\/[a-z0-9]+/.exec(readText(f) || '');
      if (m) uids.set(m[0], owner(f));
      continue;
    }
    if (f.endsWith('.import')) {
      const m = /uid="(uid:\/\/[a-z0-9]+)"/.exec(readText(f) || '');
      if (m) uids.set(m[1], owner(f));
      continue;
    }
    // "popup_reward.gd" always. A bare stem in CamelCase ("ShopCashLayer", a Unity layer loaded by name), or naming
    // an asset (ThemeKit.icon("lb_piece")). A bare snake_case stem of a script or scene ("weekly_pass") is a save key
    // or feature id far more often than a file name.
    addName(base(f), f);
    if (/[A-Z]/.test(stem(f)) || ASSET_EXT.has(ext(f))) addName(stem(f), f, true);
    if (!TEXT_EXT.has(ext(f)) || fs.statSync(path.join(ROOT, f)).size > MAX_TEXT) continue;
    const t = readText(f);
    if (t == null) continue;
    texts.set(f, t);
    const head = /^\[gd_(?:scene|resource)[^\]]*uid="(uid:\/\/[a-z0-9]+)"/.exec(t);
    if (head) uids.set(head[1], f);
  }
  const autoloads = parseAutoloads(texts.get('project.godot') || '');
  const exact = new Map();
  const prefixes = [];
  const link = (src, dst) => {
    if (src === dst) return;
    if (!exact.has(dst)) exact.set(dst, new Set());
    exact.get(dst).add(src);
  };
  for (const [f, raw] of texts) {
    const e = ext(f);
    const gd = e === 'gd' ? stripGd(raw) : null;
    const t = gd ? gd.code : raw;
    for (const m of t.matchAll(/res:\/\/([^"'\s)\]<>,;]*)/g)) {
      let p = m[1];
      let isPrefix = false;
      const cut = p.search(/[%{*]/);
      if (cut >= 0) {
        p = p.slice(0, cut);
        isPrefix = true;
      }
      if (!p) continue;
      if (p.endsWith('/')) isPrefix = true;
      else if (!isPrefix && !fileSet.has(p) && dirs.has(p + '/')) {
        p += '/';
        isPrefix = true;
      }
      // A prefix is a directory the file lists ("res://scenes/") or a path built at run time ("res://scenes/%s").
      if (!isPrefix) link(f, p);
      else if (p.includes('/')) prefixes.push([p, f, cut < 0]);
    }
    for (const m of t.matchAll(/uid:\/\/[a-z0-9]+/g)) {
      const p = uids.get(m[0]);
      if (p) link(f, p);
    }
    if (e === 'gdshader' || e === 'gdshaderinc') {
      for (const m of t.matchAll(/#include\s+"([^"]+)"/g)) {
        if (!m[1].startsWith('res://')) link(f, path.posix.normalize(path.posix.join(path.posix.dirname(f), m[1])));
      }
    }
    if (gd) for (const [name, p] of autoloads) if (new RegExp(`\\b${name}\\b`).test(gd.bare)) link(f, p);
    if (gd || NAME_JSON.test(f)) {
      const bareOk = !NO_BARE_NAMES.has(f);
      for (const m of t.matchAll(/"([^"\\\s]{6,})"/g)) {
        for (const s of new Set([m[1], ...m[1].split(/[:/]/)])) {
          for (const n of byName.get(s) || []) if (bareOk || !n.bare) link(f, n.f);
        }
      }
    }
  }
  return { files, fileSet, texts, exact, prefixes, autoloads, memo: new Map() };
}

// {exact, prefix}: files that name `p` directly, and files that build a path that may be `p` at run time.
function dependents(g, p) {
  if (g.memo.has(p)) return g.memo.get(p);
  const exactDeps = new Set([...(g.exact.get(p) || [])].filter((d) => !ROOTS.has(d)));
  const prefixDeps = new Set();
  const dirDeps = new Set();
  for (const [pre, src, dir] of g.prefixes) {
    if (!p.startsWith(pre) || src === p || ROOTS.has(src)) continue;
    prefixDeps.add(src);
    if (dir) dirDeps.add(src);
  }
  const r = { exact: exactDeps, prefix: prefixDeps, dir: dirDeps };
  g.memo.set(p, r);
  return r;
}

// ------------------------------------------------------------------ map file

function globRe(glob) {
  let s = '';
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === '*' && glob[i + 1] === '*') {
      i++;
      if (glob[i + 1] === '/') {
        i++;
        s += '(?:.*/)?';
      } else s += '.*';
    } else if (c === '*') s += '[^/]*';
    else if (c === '?') s += '[^/]';
    else s += esc(c);
  }
  return new RegExp(`^${s}$`);
}

function parseMap(text) {
  const rules = [];
  const errors = [];
  text.split(/\r?\n/).forEach((raw, i) => {
    const line = raw.replace(/##.*$/, '').trim();
    if (!line || line.startsWith('#')) return;
    const tok = line.split(/\s+/);
    const sep = tok.indexOf(':');
    const where = `${MAP_PATH}:${i + 1}`;
    if (sep <= 0 || sep === tok.length - 1) {
      errors.push(`${where}: cần dạng "<đích...> : <mẫu...>"`);
      return;
    }
    const rule = { where, scens: new Set(), tests: new Set(), allTests: false, dflt: false, none: false,
      globs: tok.slice(sep + 1) };
    for (const t of tok.slice(0, sep)) {
      if (t === '*') rule.dflt = true;
      else if (t === '-') rule.none = true;
      else if (t === 'test:*') rule.allTests = true;
      else if (/^test:test_\w+$/.test(t)) rule.tests.add(t.slice(5));
      else if (/^[A-Z][A-Z0-9]*$/.test(t)) rule.scens.add(t);
      else errors.push(`${where}: đích lạ "${t}"`);
    }
    rule.res = rule.globs.map(globRe);
    rule.stops = rule.dflt || rule.none || rule.scens.size > 0;
    rules.push(rule);
  });
  return { rules, errors };
}

const rulesFor = (ctx, p) => ctx.rules.filter((r) => r.res.some((re) => re.test(p)));

function defaultScenarios() {
  const m = /SCENS=\(([A-Z0-9 ]+)\)/.exec(readText('tools/smoke.sh') || '');
  return m ? m[1].trim().split(/\s+/) : null;
}

// ------------------------------------------------------------------ smoke code (tests/smoke/*.gd)

function smokeModel(texts) {
  const funcs = [];
  const decls = [];
  const lineCache = new Map();
  for (const [f, t] of texts) {
    if (!f.startsWith(SMOKE_DIR) || ext(f) !== 'gd') continue;
    const lines = t.split(/\r?\n/);
    lineCache.set(f, lines);
    lines.forEach((l, i) => {
      const fm = /^(?:static\s+)?func\s+(\w+)/.exec(l);
      if (fm) {
        let s = i;
        while (s > 0 && lines[s - 1].startsWith('##')) s--;
        let e = i + 1;
        while (e < lines.length && (lines[e].trim() === '' || /^\s/.test(lines[e]))) e++;
        let last = e - 1;
        while (last > i && lines[last].trim() === '') last--;
        funcs.push({ id: funcs.length, file: f, name: fm[1], start: s + 1, end: last + 1,
          body: lines.slice(i + 1, last + 1).join('\n') });
        return;
      }
      const dm = /^(?:static\s+)?(?:const|var|enum|signal)\s+(\w+)/.exec(l);
      if (dm) decls.push({ file: f, name: dm[1], line: i + 1 });
    });
  }
  const scenOf = new Map();
  for (const fn of funcs) {
    const m = /^scen_([a-z0-9]+)$/.exec(fn.name);
    if (m) scenOf.set(fn.id, m[1] === 'g2' ? 'G' : m[1].toUpperCase());
  }
  // Scenarios that take screenshots (worth a window run).
  const shooting = new Set();
  for (const [id, code] of scenOf) if (/\b(shot|film|tc_look)\s*\(/.test(funcs[id].body)) shooting.add(code);
  return { funcs, decls, scenOf, shooting, lineCache, registry: new Set(scenOf.values()), callerMemo: new Map() };
}

function callersOf(model, name) {
  if (model.callerMemo.has(name)) return model.callerMemo.get(name);
  const re = new RegExp(`\\b${name}\\s*\\(|"${name}"|\\b${name}\\.(?:bind|call)\\b`);
  const out = model.funcs.filter((f) => f.name !== name && re.test(f.body)).map((f) => f.id);
  model.callerMemo.set(name, out);
  return out;
}

function usersOfSymbol(model, name) {
  const re = new RegExp(`\\b${name}\\b`);
  return model.funcs.filter((f) => re.test(f.body)).map((f) => f.id);
}

// Scenarios whose scen_* function reaches one of `seeds` through calls.
function scenariosFrom(model, seeds) {
  const out = new Set();
  const seen = new Set();
  const queue = [...seeds];
  while (queue.length) {
    const id = queue.shift();
    if (seen.has(id)) continue;
    seen.add(id);
    if (model.scenOf.has(id)) {
      out.add(model.scenOf.get(id));
      continue;
    }
    queue.push(...callersOf(model, model.funcs[id].name));
  }
  return out;
}

// Edit inside a tests/smoke/*.gd file. `lines` null: the whole file.
function smokeFileScenarios(ctx, file, lines) {
  const model = ctx.model;
  const own = model.funcs.filter((f) => f.file === file);
  const text = model.lineCache.get(file);
  const ownScens = [...new Set(own.filter((f) => model.scenOf.has(f.id)).map((f) => model.scenOf.get(f.id)))];
  const fallback = ownScens.length ? { scens: new Set(ownScens), dflt: false } : { scens: new Set(), dflt: true };
  if (!text) return { ...fallback, why: 'file kịch bản bị xoá' };
  const seeds = new Set();
  const direct = new Set();
  let fileLevel = false;
  const take = (ln) => {
    const src = text[ln - 1] ?? '';
    // Dispatch tables name their scenarios: `"WP": "res://tests/smoke/scen_events.gd"`, `return await scen_wp(r)`.
    for (const m of src.matchAll(/"([A-Z][A-Z0-9]*)"/g)) if (model.registry.has(m[1])) direct.add(m[1]);
    for (const m of src.matchAll(/\bscen_([a-z0-9]+)\s*\(/g)) direct.add(m[1] === 'g2' ? 'G' : m[1].toUpperCase());
    const fn = own.find((f) => ln >= f.start && ln <= f.end);
    if (fn) {
      seeds.add(fn.id);
      return;
    }
    if (src.trim() === '' || /^\s*#/.test(src)) return;
    let a = ln - 1;
    while (a > 0 && (text[a].trim() === '' || /^\s/.test(text[a]))) a--;
    const d = /^(?:static\s+)?(?:const|var|enum|signal)\s+(\w+)/.exec(text[a] ?? '');
    if (d) for (const id of usersOfSymbol(model, d[1])) seeds.add(id);
    else fileLevel = true;
  };
  if (lines == null) for (let ln = 1; ln <= text.length; ln++) take(ln);
  else for (const ln of lines) take(ln);
  const scens = scenariosFrom(model, seeds);
  for (const c of direct) if (model.registry.has(c)) scens.add(c);
  if (scens.size) return { scens, dflt: fileLevel, why: 'hàm scen_* gọi tới dòng sửa' };
  if (seeds.size || fileLevel) return { ...fallback, why: 'dòng sửa không thuộc kịch bản nào' };
  return { scens: new Set(), dflt: false, why: 'chỉ sửa comment' };
}

// scen_* functions that quote this file's name ("popup_reward.gd").
function mentions(ctx, p) {
  const names = [base(p), stem(p)].filter(distinct);
  if (!names.length || p.startsWith('tests/')) return [];
  const out = new Set();
  for (const [id, code] of ctx.model.scenOf) {
    const body = ctx.model.funcs[id].body;
    if (names.some((n) => body.includes(`"${n}"`))) out.add(code);
  }
  return [...out];
}

// ------------------------------------------------------------------ selection

function smokeFor(ctx, file, lines) {
  const res = { scens: new Map(), dflt: false, mapped: false, why: '' };
  const add = (code, via) => { if (!res.scens.has(code)) res.scens.set(code, via); };
  if (/^tests\/cases\/[^/]+\.csv$/.test(file)) {
    const code = stem(file).toUpperCase();
    if (ctx.model.registry.has(code)) {
      add(code, file);
      res.mapped = true;
      return res;
    }
  }
  if (file.startsWith(SMOKE_DIR) && ext(file) === 'gd') {
    const r = smokeFileScenarios(ctx, file, lines);
    for (const c of r.scens) add(c, file);
    res.dflt = r.dflt;
    res.mapped = true;
    res.why = r.why;
    return res;
  }
  const queue = [file];
  const seen = new Set(queue);
  while (queue.length) {
    const n = queue.shift();
    for (const c of mentions(ctx, n)) {
      add(c, n === file ? `scen_${c.toLowerCase()} nhắc tên` : `${n} (scen_${c.toLowerCase()} nhắc tên)`);
    }
    const stops = rulesFor(ctx, n).filter((r) => r.stops);
    if (stops.length) {
      res.mapped = true;
      for (const r of stops) {
        if (r.dflt) res.dflt = true;
        for (const c of r.scens) add(c, n);
      }
      continue;
    }
    if (n !== file && n.startsWith('tests/')) continue;
    // A run-time path ("res://scenes/%s.tscn") only counts when no game file names this one outright.
    const d = dependents(ctx.g, n);
    const game = (s) => [...s].filter((x) => !x.startsWith('tests/') && !INDEXES.test(x));
    const exactGame = game(d.exact);
    for (const x of exactGame.length ? exactGame : game(d.prefix)) {
      if (!seen.has(x)) {
        seen.add(x);
        queue.push(x);
      }
    }
  }
  return res;
}

function staticTests(ctx, file) {
  const out = new Set();
  let all = false;
  for (const r of rulesFor(ctx, file)) {
    if (r.allTests) all = true;
    for (const t of r.tests) out.add(t);
  }
  const parent = new Map([[file, null]]);
  const queue = [file];
  const via = {};
  while (queue.length) {
    const n = queue.shift();
    const m = TEST_FILE.exec(n);
    if (m && ctx.g.fileSet.has(n)) {
      out.add(m[1]);
      const chain = [];
      for (let p = parent.get(n); p != null && p !== file; p = parent.get(p)) chain.unshift(p);
      via[m[1]] = chain;
    }
    const d = dependents(ctx.g, n);
    for (const x of [...d.exact, ...d.prefix]) {
      if (!parent.has(x)) {
        parent.set(x, n);
        queue.push(x);
      }
    }
  }
  return { tests: out, all, via };
}

// ------------------------------------------------------------------ coverage map

function loadCoverage(rel) {
  let text;
  try {
    text = fs.readFileSync(path.resolve(ROOT, rel), 'utf8');
  } catch {
    return null;
  }
  let map;
  try {
    map = JSON.parse(text);
  } catch {
    return { path: rel, broken: true };
  }
  if (map.version !== 1 || !Array.isArray(map.tests) || !map.files) return { path: rel, broken: true };
  const names = map.tests.map((t) => t.name);
  // A test that failed or stopped during the coverage run may not have reached all it normally reaches.
  const trusted = new Set(map.tests.filter((t) => !t.failed).map((t) => t.name));
  const count = git(['rev-list', '--count', `${map.commit}..HEAD`], true).trim();
  return { path: rel, ...map, names, trusted, behind: count === '' ? null : Number(count) };
}

// Members and lines of a script: the working copy, or `ref`'s version when `ref` is given.
function parsed(ctx, file, ref = null) {
  const key = `${ref ?? ''}:${file}`;
  if (!ctx.parsed.has(key)) {
    const text = ref ? git(['show', `${ref}:${file}`], true) : readText(file);
    ctx.parsed.set(key, text == null || text === '' ? null : { members: gdMembers(text), lines: text.split('\n') });
  }
  return ctx.parsed.get(key);
}

// Test names that entered `id` of `file`, or every method of it when id is null.
function covTests(ctx, file, id = null) {
  const funcs = ctx.cov.files[file]?.funcs || {};
  const out = new Set();
  for (const [k, idx] of Object.entries(funcs)) {
    if (id != null && k !== id) continue;
    for (const i of idx) if (ctx.g.fileSet.has(`tests/${ctx.cov.names[i]}.gd`)) out.add(ctx.cov.names[i]);
  }
  return out;
}

// Covered methods that name `name`: anywhere in `file` and in scripts extending it, after a dot elsewhere among
// the scripts that refer to `file` (Wallet.KINDS, Game.wallet, shop.refresh()).
function symbolUsers(ctx, file, name, skipId = null) {
  const bare = new RegExp(`\\b${esc(name)}\\b`);
  const dotted = new RegExp(`\\.${esc(name)}\\b`);
  const out = [];
  for (const f of new Set([file, ...dependents(ctx.g, file).exact])) {
    if (!ctx.cov.files[f]) continue;
    const p = parsed(ctx, f);
    if (!p) continue;
    const re = f === file || new RegExp(`^extends\\s+"res://${esc(file)}"`, 'm').test(p.lines.join('\n')) ? bare : dotted;
    for (const m of p.members) {
      if (m.kind !== 'func' || (f === file && m.id === skipId)) continue;
      if (re.test(p.lines.slice(m.start - 1, m.end).join('\n'))) out.push([f, m.id]);
    }
  }
  return out;
}

// Scripts a scene or resource uses that no other scene or resource uses: their tests are the ones creating it.
function ownedScripts(ctx, scene) {
  const t = ctx.g.texts.get(scene) || '';
  const out = [];
  for (const m of t.matchAll(/res:\/\/([^"]+\.gd)"/g)) {
    const s = m[1];
    if (!ctx.cov.files[s] || out.includes(s)) continue;
    const users = [...dependents(ctx.g, s).exact].filter((d) => /\.(tscn|tres)$/.test(d));
    if (users.every((u) => u === scene)) out.push(s);
  }
  return out;
}

// What the changed lines of a covered script touch. sides: {neu, old} line sets of the working copy and of `ref`.
function changedMembers(ctx, file, sides, ref) {
  const r = { funcs: new Map(), syms: [], classes: new Set(), whole: false };
  for (const [ver, lines] of [[null, sides.neu], [ref, sides.old]]) {
    if (!lines.size) continue;
    const p = parsed(ctx, file, ver);
    if (!p) {
      r.whole = true;
      continue;
    }
    for (const ln of lines) {
      if (isCommentOrBlank(p.lines[ln - 1])) continue;
      const m = memberAt(p.members, ln);
      if (!m) r.whole = true;
      else if (m.kind === 'func') r.funcs.set(m.id, m.name);
      else if (['const', 'enum', 'signal', 'var'].includes(m.kind)) r.syms.push(m);
      else if (m.kind === 'class') r.classes.add(m.id);
      else r.whole = true;
    }
  }
  return r;
}

function coverageTests(ctx, file, sides, ref, st) {
  const out = new Map();
  const add = (names, why) => { for (const t of names) if (!out.has(t)) out.set(t, why); };
  for (const r of rulesFor(ctx, file)) add(r.tests, MAP_PATH);
  // New tests, and tests whose coverage is partial: the graph decides for them.
  add([...st.tests].filter((t) => !ctx.cov.trusted.has(t)), 'đồ thị (test chưa có trong bản đo)');
  const queue = [file];
  const seen = new Set(queue);
  while (queue.length) {
    const n = queue.shift();
    const d = dependents(ctx.g, n);
    const own = /\.(tscn|tres)$/.test(n) && !ctx.cov.files[n] ? ownedScripts(ctx, n) : [];
    // Tests that name the file or list its directory read it themselves. A test building the path at run time
    // ("res://scenes/%s.tscn") only counts when coverage cannot tell whether it loaded this file.
    const measured = !!ctx.cov.files[n] || own.length > 0;
    const of = n === file ? 'file' : n;
    for (const x of [...d.exact, ...d.prefix]) {
      const m = TEST_FILE.exec(x);
      if (!m || !ctx.g.fileSet.has(x)) continue;
      if (d.exact.has(x)) add([m[1]], `nhắc tên ${of}`);
      else if (d.dir.has(x)) add([m[1]], `đọc thư mục của ${of}`);
      else if (!measured) add([m[1]], `dựng đường dẫn tới ${of} lúc chạy`);
    }
    if (ctx.cov.files[n]) {
      if (n !== file || !sides) {
        add(covTests(ctx, n), n === file ? 'chạy qua file' : `chạy qua ${n}`);
        continue;
      }
      const ch = changedMembers(ctx, file, sides, ref);
      const funcs = ctx.cov.files[file].funcs;
      for (const [id, name] of ch.funcs) {
        if (funcs[id]) {
          add(covTests(ctx, file, id), `chạy qua ${id}`);
          continue;
        }
        // A method added after the coverage run: the tests of its callers, or of the whole file.
        const callers = symbolUsers(ctx, file, name, id);
        if (callers.length) for (const [f, c] of callers) add(covTests(ctx, f, c), `${id} mới, gọi từ ${f === file ? '' : `${f}:`}${c}`);
        else ch.whole = true;
      }
      for (const m of ch.syms) {
        const users = symbolUsers(ctx, file, m.name);
        for (const [f, c] of users) add(covTests(ctx, f, c), `${m.name} dùng ở ${f === file ? '' : `${f}:`}${c}`);
        // A member var is set up when an object is created.
        const made = m.kind === 'var' ? covTests(ctx, file, NEW_ID) : new Set();
        add(made, `${m.name}: tạo object`);
        if (!users.length && !made.size) ch.whole = true;
      }
      for (const c of ch.classes) {
        const tests = new Set(Object.keys(funcs).filter((k) => k.startsWith(`${c}.`)).flatMap((k) => [...covTests(ctx, file, k)]));
        if (tests.size) add(tests, `chạy qua class ${c}`);
        else ch.whole = true;
      }
      if (ch.whole) add(covTests(ctx, file), 'chạy qua file');
      continue;
    }
    if (own.length) {
      for (const s of own) add(covTests(ctx, s), `tạo ${n} (${s})`);
      continue;
    }
    if (TEST_FILE.test(n) && n !== file) continue;
    for (const x of [...d.exact, ...d.prefix]) {
      if (!seen.has(x)) {
        seen.add(x);
        queue.push(x);
      }
    }
  }
  return { tests: new Set(out.keys()), why: Object.fromEntries(out) };
}

function testsFor(ctx, file, sides, ref) {
  const st = staticTests(ctx, file);
  // Test code, test infrastructure and map rules that pick every test keep the graph.
  if (!ctx.cov || ctx.cov.broken || st.all || file.startsWith('tests/') || file.startsWith('tools/')) {
    return { ...st, mode: 'static' };
  }
  return { ...coverageTests(ctx, file, sides, ref, st), all: false, mode: 'coverage', staticCount: st.tests.size };
}

// ------------------------------------------------------------------ methods without a test

// tests/untested_allow.txt: "<file>:<method> ## <reason> (YYYY-MM-DD)"; * stands for any characters in either part.
function parseAllow(text, name = ALLOW_PATH) {
  const rules = [];
  const errors = [];
  (text || '').split(/\r?\n/).forEach((raw, i) => {
    const line = raw.trim();
    if (!line || line.startsWith('#')) return;
    const where = `${name}:${i + 1}`;
    const m = /^([^\s:]+):(\S+)\s+##\s+(.*\S)\s*$/.exec(line);
    if (!m || !/\(\d{4}-\d{2}-\d{2}\)$/.test(m[3])) {
      errors.push(`${where}: cần dạng "<file>:<hàm> ## <lý do> (YYYY-MM-DD)"`);
      return;
    }
    const re = (glob) => new RegExp(`^${glob.split('*').map(esc).join('.*')}$`);
    rules.push({ where, file: m[1], func: m[2], fileRe: re(m[1]), funcRe: re(m[2]) });
  });
  return { rules, errors };
}

const allowRule = (ctx, file, id) => ctx.allow.rules.find((r) => r.fileRe.test(file) && r.funcRe.test(id));

// Methods of an instrumented script whose code changed in the working copy; every method of a new or whole file.
function changedFuncs(ctx, file, sides) {
  if (!COVERED.test(file)) return [];
  const p = parsed(ctx, file);
  if (!p) return [];
  if (!sides) return p.members.filter((m) => m.kind === 'func' && !m.abstract).map((m) => m.id);
  const out = new Set();
  for (const ln of sides.neu) {
    if (isCommentOrBlank(p.lines[ln - 1])) continue;
    const m = memberAt(p.members, ln);
    if (m?.kind === 'func' && !m.abstract) out.add(m.id);
  }
  return [...out];
}

// allowed: listed in untested_allow.txt. tested: some test entered it. untested: the measured tests never did.
// unmeasured: no map, or the method is newer than the map (or the map is partial). measured: tests just ran with
// coverage (--run), so a method they never entered is untested even in a partial map.
function funcStatus(ctx, file, id, measured = false) {
  if (allowRule(ctx, file, id)) return 'allowed';
  const funcs = ctx.cov && !ctx.cov.broken ? ctx.cov.files[file]?.funcs : null;
  if (!funcs || !(id in funcs)) return 'unmeasured';
  if (covTests(ctx, file, id).size) return 'tested';
  return ctx.cov.complete || measured ? 'untested' : 'unmeasured';
}

function diffHunks(ref, file) {
  const out = git(['diff', '-U0', '--no-renames', ref, '--', file], true);
  return [...out.matchAll(/^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/gm)].map((m) => ({
    oldStart: Number(m[1]), oldCount: m[2] === undefined ? 1 : Number(m[2]),
    newStart: Number(m[3]), newCount: m[4] === undefined ? 1 : Number(m[4]) }));
}

// Lines of the working copy (and, for a pure deletion, the lines around it): what the smoke code needs.
function changedLines(hunks) {
  const lines = new Set();
  for (const h of hunks) {
    if (h.newCount === 0) {
      lines.add(Math.max(1, h.newStart));
      lines.add(h.newStart + 1);
    } else for (let k = 0; k < h.newCount; k++) lines.add(h.newStart + k);
  }
  return lines;
}

// Added or changed lines of the working copy, removed or changed lines of ref's version.
function changedSides(hunks) {
  const neu = new Set();
  const old = new Set();
  for (const h of hunks) {
    for (let k = 0; k < h.newCount; k++) neu.add(h.newStart + k);
    for (let k = 0; k < h.oldCount; k++) old.add(h.oldStart + k);
  }
  return { neu, old };
}

function changedFiles(ref) {
  const out = [];
  const seen = new Set();
  const push = (status, p) => {
    if (!p || seen.has(p) || SKIP_PREFIXES.some((s) => p.startsWith(s))) return;
    seen.add(p);
    out.push({ status, path: p, lines: undefined });
  };
  const diff = git(['diff', '--name-status', '--no-renames', '-z', ref]).split('\0');
  for (let i = 0; i + 1 < diff.length; i += 2) push(diff[i][0], diff[i + 1]);
  for (const p of git(['ls-files', '-z', '-o', '--exclude-standard']).split('\0')) push('?', p);
  return out;
}

function parseFileArg(a) {
  const m = /^(.*?):([\d,-]+)$/.exec(a);
  const p = (m ? m[1] : a).replace(/\\/g, '/').replace(/^\.\//, '');
  if (!m) return { status: 'M', path: p, lines: null };
  const lines = new Set();
  for (const part of m[2].split(',').filter(Boolean)) {
    const [a1, b1] = part.split('-').map(Number);
    for (let k = a1; k <= (b1 || a1); k++) lines.add(k);
  }
  return { status: 'M', path: p, lines };
}

function order(ctx, codes) {
  const pos = (c) => {
    const i = ctx.dflt.indexOf(c);
    return i >= 0 ? `0${String(i).padStart(2, '0')}` : `1${c}`;
  };
  return [...codes].sort((a, b) => pos(a).localeCompare(pos(b)));
}

function select(ctx, changed, ref) {
  const tests = new Set();
  let allTests = false;
  const smoke = new Map();
  const window = new Set();
  const unmapped = [];
  const device = [];
  const levels = [];
  const perFile = [];
  const funcs = [];
  for (const c of changed) {
    const p = owner(c.path);
    let lines = c.lines;
    // null: the whole file (new file, --files without lines, foo.gd.uid standing for foo.gd).
    let sides = lines == null ? null : { neu: lines, old: new Set() };
    if (lines === undefined) {
      if (c.status === '?' || c.status === 'A') lines = sides = null;
      else {
        const hunks = diffHunks(ref, c.path);
        lines = changedLines(hunks);
        sides = changedSides(hunks);
      }
    }
    // foo.gd.uid stands for foo.gd for the tests, but no method of it changed.
    const methods = p === c.path ? changedFuncs(ctx, p, sides) : [];
    if (p !== c.path) sides = null;
    const t = testsFor(ctx, p, sides, ref);
    const status = {};
    for (const id of methods) {
      status[id] = funcStatus(ctx, p, id);
      funcs.push({ file: p, id, status: status[id] });
    }
    const having = (st) => methods.filter((id) => status[id] === st);
    if (t.all) allTests = true;
    for (const x of t.tests) tests.add(x);
    const s = smokeFor(ctx, p, lines);
    const codes = new Set(s.scens.keys());
    if (s.dflt) for (const d of ctx.dflt) codes.add(d);
    for (const code of codes) if (!smoke.has(code)) smoke.set(code, p);
    if (VISIBLE.some((re) => re.test(p))) for (const code of codes) if (ctx.model.shooting.has(code)) window.add(code);
    if (!s.mapped && !codes.size && GAME_CONTENT.test(p)) unmapped.push(p);
    if (DEVICE_ONLY.some((re) => re.test(p))) device.push(p);
    const lv = /^data\/levels\/level_(\d+)\.json$/.exec(p);
    if (lv) levels.push(Number(lv[1]));
    perFile.push({ status: c.status, path: c.path, tests: [...t.tests].sort(), allTests: t.all, testMode: t.mode,
      staticTests: t.staticCount ?? t.tests.size, testWhy: t.why || {}, untested: having('untested'),
      unmeasured: having('unmeasured'),
      smoke: order(ctx, s.scens.keys()), dflt: s.dflt, via: Object.fromEntries(s.scens), why: s.why });
  }
  let vRange = null;
  if (smoke.has('V')) {
    vRange = levels.length ? [Math.min(...levels), Math.max(...levels)] : V_SAMPLE;
  }
  return { tests: allTests ? [] : [...tests].sort(), allTests, smoke: order(ctx, smoke.keys()),
    window: order(ctx, window), vRange, unmapped, device, ...gateLists(funcs), funcs, perFile };
}

// "file:method" lists by status, for the report and the gate.
function gateLists(funcs) {
  const of = (st) => funcs.filter((f) => f.status === st).map((f) => `${f.file}:${f.id}`);
  return { untested: of('untested'), unmeasured: of('unmeasured'), allowed: of('allowed') };
}

// Seconds the selected tests took in the coverage run (instrumented, so slower than a plain run).
function estimate(ctx, sel) {
  if (!ctx.cov || ctx.cov.broken) return null;
  const ms = new Map(ctx.cov.tests.map((t) => [t.name, t.ms]));
  const sum = (names) => Math.round(names.reduce((a, n) => a + (ms.get(n) || 0), 0) / 1000);
  return { selected: sum(sel.allTests ? ctx.cov.names : sel.tests), all: sum(ctx.cov.names) };
}

// test.sh matches file name prefixes, so "test_ui_shop.gd" runs that file only (not test_ui_shop_fx.gd).
function commands(sel) {
  const cmds = [];
  if (sel.allTests) cmds.push({ argv: ['tools/test.sh'] });
  else if (sel.tests.length) cmds.push({ argv: ['tools/test.sh', ...sel.tests.map((t) => `${t}.gd`)] });
  const headless = sel.smoke.filter((c) => c !== 'V');
  if (headless.length) cmds.push({ argv: ['tools/smoke.sh', 'headless', ...headless] });
  if (sel.vRange) {
    cmds.push({ argv: ['tools/smoke.sh', 'headless', 'V'], env: { SMOKE_ARGS: `from=${sel.vRange[0]} to=${sel.vRange[1]}` } });
  }
  return cmds;
}

const show = (c) => Object.entries(c.env || {}).map(([k, v]) => `${k}="${v}" `).join('') + c.argv.join(' ');

// ------------------------------------------------------------------ check

function check(ctx) {
  const problems = [...ctx.mapErrors];
  if (!ctx.dfltParsed) problems.push('không đọc được bộ kịch bản mặc định (SCENS=(...)) trong tools/smoke.sh');
  const tests = new Set(ctx.g.files.map((f) => TEST_FILE.exec(f)?.[1]).filter(Boolean));
  const covered = new Set(ctx.dflt);
  for (const r of ctx.rules) {
    r.globs.forEach((glob, i) => {
      if (!ctx.g.files.some((f) => r.res[i].test(f))) problems.push(`${r.where}: mẫu "${glob}" không khớp file nào`);
    });
    for (const c of r.scens) {
      covered.add(c);
      if (!ctx.model.registry.has(c)) problems.push(`${r.where}: không có kịch bản ${c} (static func scen_${c.toLowerCase()})`);
    }
    for (const t of r.tests) if (!tests.has(t)) problems.push(`${r.where}: không có tests/${t}.gd`);
  }
  for (const c of ctx.dflt) if (!ctx.model.registry.has(c)) problems.push(`tools/smoke.sh: bộ mặc định có ${c} nhưng không có scen_${c.toLowerCase()}`);
  for (const c of ctx.model.registry) if (!covered.has(c)) problems.push(`kịch bản ${c} không có dòng nào trong ${MAP_PATH}: không thay đổi nào chọn được nó`);
  let orphans = 0;
  for (const f of ctx.g.files) {
    if (!GAME_CONTENT.test(f) || /\.(uid|import)$/.test(f)) continue;
    const s = smokeFor(ctx, f, null);
    if (!s.mapped && !s.scens.size) {
      orphans++;
      problems.push(`${f}: không tới được file nào có trong ${MAP_PATH} (thêm dòng, hoặc "-" nếu không kịch bản nào chạy tới)`);
    }
  }
  problems.push(...ctx.allow.errors);
  for (const r of ctx.allow.rules) {
    const files = ctx.g.files.filter((f) => COVERED.test(f) && r.fileRe.test(f));
    if (!files.length) problems.push(`${r.where}: "${r.file}" không khớp script nào trong src/`);
    else if (!files.some((f) => (parsed(ctx, f)?.members || []).some((m) => m.kind === 'func' && r.funcRe.test(m.id)))) {
      problems.push(`${r.where}: "${r.file}:${r.func}" không khớp hàm nào (đổi tên hay đã xoá?)`);
    }
  }
  return { problems, orphans };
}

// ------------------------------------------------------------------ main

function usage() {
  console.log(`tools/affected.sh [ref] [--run] [--json] [-v] [--static] [--files <file[:dòng]>...]
tools/affected.sh --check
tools/affected.sh --coverage [--keep] [lọc test...]
  ref        so với merge-base của ref và HEAD (mặc định HEAD), cộng file chưa commit và file mới
  --files    các file này (và dòng, ví dụ tests/smoke/scen_events.gd:120-140) thay cho git diff
  --run      chạy luôn test rồi smoke headless (window vẫn phải chạy tay và đọc ảnh)
  --json     in kết quả dạng JSON
  -v         in đủ test và đường dẫn chọn từng kịch bản
  --static   chọn test theo đồ thị tĩnh, bỏ qua bản đo độ phủ
  --coverage-map <file>   bản đo khác ${COV_MAP}
  --allow-file <file>     danh sách miễn trừ khác ${ALLOW_PATH}
  --check    kiểm ${MAP_PATH}: mẫu khớp file, mã kịch bản và test có thật, mọi file src/ scenes/ có kịch bản
  --coverage đo test nào chạy qua hàm nào của src/ (chạy cả bộ test trên bản sao có chèn lệnh, khoảng 10 phút),
             ghi ${COV_MAP}; --keep giữ bản sao ở output/coverage/snap`);
}

function main(argv) {
  const opts = { ref: null, run: false, json: false, verbose: false, check: false, files: null, static: false,
    covMap: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--run') opts.run = true;
    else if (a === '--static') opts.static = true;
    else if (a === '--coverage-map' && i + 1 < argv.length) opts.covMap = argv[++i];
    else if (a === '--allow-file' && i + 1 < argv.length) opts.allowFile = argv[++i];
    else if (a === '--json') opts.json = true;
    else if (a === '-v' || a === '--verbose') opts.verbose = true;
    else if (a === '--check') opts.check = true;
    else if (a === '-h' || a === '--help') return usage(), 0;
    else if (a === '--files') {
      opts.files = [];
      while (i + 1 < argv.length && !argv[i + 1].startsWith('--')) opts.files.push(parseFileArg(argv[++i]));
    } else if (!a.startsWith('-') && opts.ref == null) opts.ref = a;
    else {
      console.error(`tham số lạ: ${a}`);
      usage();
      return 2;
    }
  }
  const g = buildGraph(listFiles());
  const map = parseMap(readText(MAP_PATH) || '');
  const parsedDefault = defaultScenarios();
  const ctx = { g, rules: map.rules, mapErrors: map.errors, model: smokeModel(g.texts),
    dflt: parsedDefault || ['A', 'B', 'C', 'D', 'E', 'M', 'S'], dfltParsed: parsedDefault != null,
    cov: opts.static ? null : loadCoverage(opts.covMap ?? COV_MAP), parsed: new Map(),
    allow: opts.allowFile ? parseAllow(fs.readFileSync(path.resolve(ROOT, opts.allowFile), 'utf8'), opts.allowFile)
      : parseAllow(readText(ALLOW_PATH)) };

  if (opts.check) {
    const { problems } = check(ctx);
    if (opts.json) console.log(JSON.stringify({ ok: problems.length === 0, problems }, null, 1));
    else {
      for (const p of problems) console.log(`AFFECTED MAP ${p}`);
      console.log(problems.length ? `AFFECTED MAP FAILED (${problems.length})`
        : `AFFECTED MAP OK (${ctx.rules.length} dòng, ${ctx.model.registry.size} kịch bản, ${ctx.allow.rules.length} dòng ${ALLOW_PATH})`);
    }
    return problems.length ? 1 : 0;
  }

  let ref = 'HEAD';
  if (opts.ref) ref = git(['merge-base', opts.ref, 'HEAD']).trim();
  const changed = opts.files ?? changedFiles(ref);
  const sel = select(ctx, changed, ref);
  const cmds = commands(sel);
  if (opts.json) {
    const cov = ctx.cov && { path: ctx.cov.path, broken: !!ctx.cov.broken, commit: ctx.cov.commit,
      created: ctx.cov.created, behind: ctx.cov.behind, complete: ctx.cov.complete };
    console.log(JSON.stringify({ ref: opts.files ? null : (opts.ref || 'HEAD'), changed: changed.length, coverage: cov,
      ...sel, estimate: estimate(ctx, sel), commands: cmds.map(show) }, null, 1));
    if (!opts.run) return 0;
  } else report(ctx, opts, changed, sel, cmds);
  return opts.run ? runAll(ctx, opts, sel, cmds) : 0;
}

function printList(title, items, max = 20) {
  if (!items.length) return;
  console.log(`\n${title}`);
  for (const x of items.slice(0, max)) console.log(`  ${x}`);
  if (items.length > max) console.log(`  ... và ${items.length - max} hàm nữa`);
}

function report(ctx, opts, changed, sel, cmds) {
  const what = opts.files ? 'các file đưa vào' : `so với ${opts.ref ? `merge-base với ${opts.ref}` : 'HEAD'} (gồm chưa commit)`;
  const cov = ctx.cov;
  if (opts.static) console.log('Chọn test theo đồ thị tĩnh (--static).');
  else if (!cov) console.log(`Chọn test theo đồ thị tĩnh: chưa có ${opts.covMap ?? COV_MAP} (đo bằng tools/affected.sh --coverage, khoảng 10 phút).`);
  else if (cov.broken) console.log(`${cov.path} không đọc được: chọn test theo đồ thị tĩnh; đo lại bằng tools/affected.sh --coverage.`);
  else {
    const age = cov.behind == null ? `commit ${String(cov.commit).slice(0, 7)} không còn trong lịch sử`
      : cov.behind ? `sau đó ${cov.behind} commit` : 'đúng HEAD';
    console.log(`Chọn test theo độ phủ: ${cov.path} (đo ${String(cov.created).slice(0, 10)}, ${age}${cov.complete ? '' : ', đo một phần'}).`);
  }
  console.log(`Thay đổi ${what}: ${changed.length} file`);
  for (const f of sel.perFile) {
    let tests = f.allTests ? 'mọi test' : `${f.tests.length} test`;
    if (f.testMode === 'coverage' && f.staticTests !== f.tests.length) tests += ` (đồ thị tĩnh: ${f.staticTests})`;
    let smoke = [...f.smoke, ...(f.dflt ? ['bộ mặc định'] : [])].join(' ') || 'không';
    const vias = [...new Set(Object.values(f.via).filter((v) => v !== owner(f.path)))];
    if (vias.length && !opts.verbose) smoke += ` (từ ${vias.slice(0, 3).join(', ')}${vias.length > 3 ? ', ...' : ''})`;
    console.log(`  ${f.status} ${f.path} → ${tests}; smoke: ${smoke}${f.why ? `; ${f.why}` : ''}`);
    if (opts.verbose) {
      if (f.testMode === 'coverage') for (const t of f.tests) console.log(`      ${t} ← ${f.testWhy[t]}`);
      else if (f.tests.length) console.log(`      test: ${f.tests.join(' ')}`);
      for (const [code, via] of Object.entries(f.via)) if (via !== f.path) console.log(`      ${code} ← ${via}`);
    }
  }
  printList(`Hàm đã sửa mà không test nào chạy tới (viết test, hoặc ghi vào ${ALLOW_PATH} kèm lý do; --run báo lỗi):`,
    sel.untested);
  if (!opts.static) printList('Hàm đã sửa chưa có trong bản đo (hàm mới, hoặc bản đo một phần; --run đo luôn):', sel.unmeasured);
  if (sel.unmapped.length) {
    console.log(`\nChưa có kịch bản nào phủ (thêm dòng vào ${MAP_PATH}):`);
    for (const p of sel.unmapped) console.log(`  ${p}`);
  }
  console.log('');
  if (!cmds.length) console.log('Không cần chạy test.');
  for (const c of cmds) console.log(show(c));
  const est = estimate(ctx, sel);
  if (est && (sel.tests.length || sel.allTests)) {
    console.log(`# test đã chọn mất khoảng ${est.selected} giây trong lần đo độ phủ (cả bộ ${est.all} giây)`);
  }
  if (sel.window.length) {
    console.log(`tools/smoke.sh window ${sel.window.join(' ')}    # rồi đọc ảnh PNG (docs/TESTING.md bước 4)`);
  }
  if (sel.device.length) console.log(`Máy thật: ${sel.device.join(', ')} chỉ chạy trên điện thoại → người dùng gọi /device-test`);
}

// Exit code like test.sh and smoke.sh: the worst of all commands (2 > 1 > 0). Unless --static the selected tests run
// on the instrumented copy (their rows go into the map), and a changed method none of them entered fails the run
// unless tests/untested_allow.txt lists it.
function runAll(ctx, opts, sel, cmds) {
  let worst = 0;
  let measured = false;
  for (const c of cmds) {
    if (!opts.static && c.argv[0] === 'tools/test.sh') {
      const filters = c.argv.slice(1);
      console.log(`\n$ tools/affected.sh --coverage ${filters.join(' ')}    # test đã chọn, đo độ phủ luôn`);
      const r = runCoverage({ filters, keep: false });
      worst = Math.max(worst, Math.min(r.rc, 2));
      measured = r.map != null;
      continue;
    }
    console.log(`\n$ ${show(c)}`);
    const r = spawnSync('bash', c.argv, { cwd: ROOT, stdio: 'inherit', env: { ...process.env, ...(c.env || {}) } });
    const rc = r.status ?? 2;
    worst = Math.max(worst, rc > 2 ? 2 : rc);
  }
  if (opts.static || !sel.funcs.length) return worst;
  if (measured) ctx.cov = loadCoverage(COV_MAP);
  const now = sel.funcs.map((f) => ({ ...f, status: funcStatus(ctx, f.file, f.id, measured) }));
  const missing = now.filter((f) => f.status === 'untested').map((f) => `${f.file}:${f.id}`);
  const unknown = now.filter((f) => f.status === 'unmeasured').map((f) => `${f.file}:${f.id}`);
  const allowed = now.filter((f) => f.status === 'allowed').length;
  printList(`Cổng test: ${missing.length} hàm đã sửa không test nào chạy tới (viết test, hoặc ghi vào ${ALLOW_PATH} kèm lý do):`,
    missing);
  printList('Chưa đo được (lần đo lỗi):', unknown);
  if (missing.length) {
    console.log(`affected: thiếu test cho ${missing.length} hàm (mã 1)`);
    worst = Math.max(worst, 1);
  } else {
    console.log(`\nCổng test: ${now.length - allowed - unknown.length}/${now.length} hàm đã sửa có test chạy tới${allowed ? `, ${allowed} miễn trừ` : ''}.`);
  }
  return worst;
}

const ARGV = process.argv.slice(2);
if (ARGV.includes('--coverage')) {
  process.exitCode = (await import('./coverage.mjs')).main(ARGV.filter((a) => a !== '--coverage'));
} else process.exitCode = main(ARGV);
