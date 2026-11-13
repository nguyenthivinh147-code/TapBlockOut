// GDScript class members with their line spans. tools/coverage.mjs instruments the methods; tools/affected.mjs maps
// changed lines to the method (or declaration) that holds them.
//
// A member starts at a logical line (not inside brackets, a string or a backslash continuation) whose indentation
// is the body indentation of its class, and runs until the next such line at that indentation or less. Inner classes
// (`class Foo extends Bar:`) open a deeper body. Lambdas and nested blocks stay inside their method.

// Leading whitespace of a line.
const lead = (s) => /^[ \t]*/.exec(s)[0];

// Per physical line: whether it starts a logical line, the code without comment, and the column of each ':' outside
// brackets and strings (for the end of a signature).
function lex(text) {
  const raw = text.split('\n');
  const out = [];
  let depth = 0;
  let str = null;
  let cont = false;
  for (const line of raw) {
    const starts = depth === 0 && str == null && !cont;
    let code = '';
    const colons = [];
    let i = 0;
    for (; i < line.length; i++) {
      const c = line[i];
      if (str) {
        code += c;
        if (c === '\\') {
          code += line[i + 1] ?? '';
          i++;
        } else if (line.startsWith(str, i)) {
          code += str.slice(1);
          i += str.length - 1;
          str = null;
        }
        continue;
      }
      if (c === '#') break;
      if (c === '"' || c === "'") {
        str = line.startsWith(c.repeat(3), i) ? c.repeat(3) : c;
        code += str;
        i += str.length - 1;
        continue;
      }
      if ('([{'.includes(c)) depth++;
      else if (')]}'.includes(c)) depth = Math.max(0, depth - 1);
      else if (c === ':' && depth === 0) colons.push(i);
      code += c;
    }
    // A single-quoted string does not span lines; only """ / ''' carry over.
    if (str && str.length === 1) str = null;
    cont = /\\\s*$/.test(code) && str == null;
    const blank = code.trim() === '';
    out.push({ raw: line, code, colons, starts: starts && !blank, indent: lead(line).length, blank });
  }
  return out;
}

const ANNOT = /^(?:@\w+(?:\([^)]*\))?\s*)*/;

function classify(code) {
  const annots = ANNOT.exec(code.trim())[0];
  const rest = code.trim().slice(annots.length);
  let m = /^(static\s+)?func\s+(\w+)/.exec(rest);
  if (m) return { kind: 'func', name: m[2], isStatic: !!m[1], abstract: /@abstract\b/.test(annots) };
  m = /^class\s+(\w+)/.exec(rest);
  if (m) return { kind: 'class', name: m[1] };
  m = /^(static\s+)?(var|const|enum|signal)\s+(\w+)/.exec(rest);
  if (m) return { kind: m[2], name: m[3], isStatic: !!m[1] };
  if (/^(extends|class_name)\b/.test(rest) || (rest === '' && annots)) return { kind: 'header', name: '' };
  return { kind: 'other', name: '' };
}

// Members of a GDScript source. Each: {kind, name, cls ('' or 'Inner' or 'Inner.Deeper'), id ('cls.name' or
// 'name' for methods), start, end (1-based, inclusive), indent (string)}. Methods add sigEnd (line of the ':' that
// ends the signature), colon (its column), oneLiner (code after that ':'), bodyIndent (string), abstract.
export function gdMembers(text) {
  const L = lex(text);
  const members = [];
  const stack = [{ name: '', body: 0, owner: null }];
  const open = [];  // members whose end is not known yet, innermost last
  // Close every open member indented at least `indent`; it ends at the last code line before 0-based `upto`.
  const close = (upto, indent) => {
    while (open.length && open[open.length - 1].indentLen >= indent) {
      const m = open.pop();
      let e = upto - 1;
      while (e > m.start - 1 && L[e].blank) e--;
      m.end = Math.max(e + 1, m.sigEnd ?? m.start);
    }
  };
  for (let i = 0; i < L.length; i++) {
    const l = L[i];
    if (!l.starts) continue;
    while (stack.length > 1 && l.indent < stack[stack.length - 1].body) stack.pop();
    close(i, l.indent);
    const top = stack[stack.length - 1];
    if (l.indent !== top.body) continue;  // statement inside a method or declaration body
    const c = classify(l.code);
    const cls = stack.slice(1).map((s) => s.name).join('.');
    const m = { kind: c.kind, name: c.name, cls, id: cls ? `${cls}.${c.name}` : c.name, start: i + 1, end: i + 1,
      indent: lead(l.raw), indentLen: l.indent };
    if (c.kind === 'func') {
      m.isStatic = c.isStatic;
      m.abstract = c.abstract;
      // The signature ends at the first ':' outside brackets of this logical line.
      let j = i;
      let col = -1;
      for (; j < L.length; j++) {
        if (j > i && L[j].starts) break;
        if (L[j].colons.length) {
          col = L[j].colons[0];
          break;
        }
      }
      if (col >= 0 && !c.abstract) {
        m.sigEnd = j + 1;
        m.colon = col;
        m.oneLiner = L[j].code.slice(col + 1).trim();
        if (!m.oneLiner) {
          let k = j + 1;
          while (k < L.length && (L[k].blank || L[k].code.trim() === '')) k++;
          m.bodyIndent = k < L.length && L[k].indent > l.indent ? lead(L[k].raw) : `${m.indent}\t`;
        } else m.bodyIndent = `${m.indent}\t`;
      } else m.abstract = true;
    }
    members.push(m);
    open.push(m);
    if (c.kind === 'class') {
      let k = i + 1;
      while (k < L.length && !L[k].starts) k++;
      const body = k < L.length && L[k].indent > l.indent ? L[k].indent : l.indent + 1;
      stack.push({ name: c.name, body });
    }
  }
  close(L.length, -1);
  for (const m of members) delete m.indentLen;
  return members;
}

// The innermost member holding 1-based line `ln`, or null (blank or comment lines between members).
export function memberAt(members, ln) {
  let best = null;
  for (const m of members) {
    if (ln >= m.start && ln <= m.end && (!best || m.start >= best.start)) best = m;
  }
  return best;
}

// True when the line has no code (blank or only a comment).
export function isCommentOrBlank(line) {
  const t = (line ?? '').trim();
  return t === '' || t.startsWith('#');
}
