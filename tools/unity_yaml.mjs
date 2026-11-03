// Minimal parser for the YAML subset Unity writes (scenes, prefabs, .meta, .mat).
// parseUnityFile(text) -> Map<fileID string, {cls, id, stripped, type, data}>; parseYaml(text) -> plain object.
// Scalars stay strings; flow maps/seqs and block maps/seqs become objects/arrays.

const HEADER = /^--- !u!(\d+) &(-?\d+)( stripped)?\s*$/;

export function parseUnityFile(text) {
	const docs = new Map();
	const lines = text.split(/\r?\n/);
	let cur = null;
	let body = [];
	const flush = () => {
		if (!cur) return;
		const obj = parseLines(body);
		const type = Object.keys(obj)[0] || "";
		docs.set(cur.id, { cls: cur.cls, id: cur.id, stripped: cur.stripped, type, data: obj[type] || {} });
	};
	for (const line of lines) {
		const m = HEADER.exec(line);
		if (m) {
			flush();
			cur = { cls: Number(m[1]), id: m[2], stripped: !!m[3] };
			body = [];
		} else if (cur) {
			body.push(line);
		}
	}
	flush();
	return docs;
}

export function parseYaml(text) {
	const lines = text.split(/\r?\n/).filter((l) => !l.startsWith("%") && !l.startsWith("---"));
	return parseLines(lines);
}

function indentOf(line) {
	let i = 0;
	while (i < line.length && line[i] === " ") i++;
	return i;
}

function parseLines(lines) {
	const src = lines.filter((l) => l.trim() !== "" || true);
	const st = { lines: src, i: 0 };
	skipBlank(st);
	if (st.i >= src.length) return {};
	return parseBlock(st, indentOf(src[st.i]));
}

function skipBlank(st) {
	while (st.i < st.lines.length && st.lines[st.i].trim() === "") st.i++;
}

function parseBlock(st, indent) {
	skipBlank(st);
	const line = st.lines[st.i];
	if (line === undefined) return null;
	if (line.slice(indent).startsWith("- ") || line.slice(indent) === "-") return parseSeq(st, indent);
	return parseMap(st, indent);
}

function parseSeq(st, indent) {
	const out = [];
	while (true) {
		skipBlank(st);
		const line = st.lines[st.i];
		if (line === undefined || indentOf(line) !== indent) break;
		const rest = line.slice(indent);
		if (!(rest.startsWith("- ") || rest === "-")) break;
		const item = rest === "-" ? "" : rest.slice(2);
		const itemIndent = indent + 2;
		if (item === "") {
			st.i++;
			out.push(parseBlock(st, indentOf(st.lines[st.i] || "")));
		} else if (isMapEntry(item)) {
			// "- key: value" starts a map whose other keys sit at indent + 2.
			st.lines[st.i] = " ".repeat(itemIndent) + item;
			out.push(parseMap(st, itemIndent));
		} else {
			st.i++;
			out.push(parseScalarTail(st, item, itemIndent));
		}
	}
	return out;
}

function isMapEntry(s) {
	if (s.startsWith("{") || s.startsWith("[") || s.startsWith("'") || s.startsWith('"')) return false;
	return /^[^\s:][^:]*:( |$)/.test(s);
}

function parseMap(st, indent) {
	const out = {};
	while (true) {
		skipBlank(st);
		const line = st.lines[st.i];
		if (line === undefined || indentOf(line) !== indent) break;
		const rest = line.slice(indent);
		if (rest.startsWith("- ")) break;
		const m = /^([^:]+?):(?: (.*))?$/.exec(rest);
		if (!m) {
			st.i++;
			continue;
		}
		const key = m[1];
		const val = m[2] === undefined ? "" : m[2];
		st.i++;
		if (val === "") {
			skipBlank(st);
			const next = st.lines[st.i];
			if (next !== undefined) {
				const ni = indentOf(next);
				const nrest = next.slice(ni);
				if (ni > indent || (ni === indent && (nrest.startsWith("- ") || nrest === "-"))) {
					out[key] = parseBlock(st, ni);
					continue;
				}
			}
			out[key] = "";
		} else {
			out[key] = parseScalarTail(st, val, indent + 1);
		}
	}
	return out;
}

// Value text after "key: " (line already consumed); continuation lines are more indented than minIndent - 1.
function parseScalarTail(st, val, minIndent) {
	const c = val[0];
	if (c === "{" || c === "[") {
		let text = val;
		let j = st.i;
		while (!balanced(text) && j < st.lines.length && indentOf(st.lines[j]) >= minIndent) text += " " + st.lines[j++].trim();
		const pos = { p: 0 };
		const v = balanced(text) ? parseFlow(text, pos) : undefined;
		skipWs(text, pos);
		// Not a real flow collection (e.g. text "{0} Gold"): keep it as a plain scalar.
		if (v === undefined || pos.p < text.length || pos.bad) return val;
		st.i = j;
		return v;
	}
	if (c === "'" || c === '"') {
		let text = val;
		const parts = [val];
		while (!closedQuote(text, c) && st.i < st.lines.length) {
			const l = st.lines[st.i++];
			parts.push(l.trim() === "" ? "" : l.trim());
			text = parts.join("\n");
		}
		return unquote(parts, c);
	}
	// Plain scalar: fold more-indented continuation lines.
	const parts = [val];
	while (st.i < st.lines.length) {
		const l = st.lines[st.i];
		if (l.trim() === "") {
			// A blank line inside a plain scalar only counts if a deeper line follows.
			let j = st.i;
			while (j < st.lines.length && st.lines[j].trim() === "") j++;
			if (j < st.lines.length && indentOf(st.lines[j]) >= minIndent && !isKeyLine(st.lines[j])) {
				parts.push("");
				st.i++;
				continue;
			}
			break;
		}
		if (indentOf(l) < minIndent || isKeyLine(l)) break;
		parts.push(l.trim());
		st.i++;
	}
	return fold(parts);
}

function isKeyLine(l) {
	const r = l.trim();
	return r.startsWith("- ") || /^[A-Za-z_][\w.]*:( |$)/.test(r);
}

function balanced(s) {
	let d = 0;
	let q = null;
	for (const ch of s) {
		if (q) {
			if (ch === q) q = null;
		} else if (ch === "'" || ch === '"') q = ch;
		else if (ch === "{" || ch === "[") d++;
		else if (ch === "}" || ch === "]") d--;
	}
	return d <= 0;
}

function closedQuote(text, q) {
	// Ends with an unescaped closing quote after the opening one.
	if (text.length < 2) return false;
	if (q === "'") {
		const body = text.slice(1);
		let i = 0;
		while (i < body.length) {
			if (body[i] === "'") {
				if (body[i + 1] === "'") {
					i += 2;
					continue;
				}
				return i === body.length - 1 || body.slice(i + 1).trim() === "";
			}
			i++;
		}
		return false;
	}
	let i = 1;
	while (i < text.length) {
		if (text[i] === "\\") {
			i += 2;
			continue;
		}
		if (text[i] === '"') return true;
		i++;
	}
	return false;
}

// YAML line folding: single newline -> space, empty line -> newline.
function fold(parts) {
	let out = "";
	for (let k = 0; k < parts.length; k++) {
		const p = parts[k];
		if (k === 0) {
			out = p;
			continue;
		}
		if (p === "") out += "\n";
		else out += out.endsWith("\n") || out === "" ? p : " " + p;
	}
	return out;
}

function unquote(parts, q) {
	if (q === "'") {
		const s = fold(parts);
		return s.slice(1, s.lastIndexOf("'")).replace(/''/g, "'");
	}
	// Double-quoted: fold, but a trailing backslash joins lines without a space.
	let raw = "";
	for (let k = 0; k < parts.length; k++) {
		const p = parts[k];
		if (k === 0) raw = p;
		else if (raw.endsWith("\\") && !raw.endsWith("\\\\")) raw = raw.slice(0, -1) + p;
		else if (p === "") raw += "\n";
		else raw += raw.endsWith("\n") ? p : " " + p;
	}
	const body = raw.slice(1, raw.lastIndexOf('"'));
	return body.replace(/\\(x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|.)/gs, (_, e) => {
		switch (e[0]) {
			case "n":
				return "\n";
			case "t":
				return "\t";
			case "r":
				return "\r";
			case "0":
				return "\0";
			case "x":
			case "u":
			case "U":
				return String.fromCodePoint(parseInt(e.slice(1), 16));
			case "\n":
				return "";
			default:
				return e;
		}
	});
}

function parseFlow(s, pos) {
	skipWs(s, pos);
	const c = s[pos.p];
	if (c === "{") {
		pos.p++;
		const out = {};
		while (true) {
			skipWs(s, pos);
			if (pos.p >= s.length) {
				pos.bad = true;
				break;
			}
			if (s[pos.p] === "}") {
				pos.p++;
				break;
			}
			let key = "";
			while (pos.p < s.length && s[pos.p] !== ":" && s[pos.p] !== "}") key += s[pos.p++];
			if (s[pos.p] !== ":") {
				pos.bad = true;
				break;
			}
			pos.p++;
			out[key.trim()] = parseFlow(s, pos);
			skipWs(s, pos);
			if (s[pos.p] === ",") pos.p++;
			else if (s[pos.p] !== "}") {
				pos.bad = true;
				break;
			}
		}
		return out;
	}
	if (c === "[") {
		pos.p++;
		const out = [];
		while (true) {
			skipWs(s, pos);
			if (pos.p >= s.length) {
				pos.bad = true;
				break;
			}
			if (s[pos.p] === "]") {
				pos.p++;
				break;
			}
			out.push(parseFlow(s, pos));
			skipWs(s, pos);
			if (s[pos.p] === ",") pos.p++;
			else if (s[pos.p] !== "]") {
				pos.bad = true;
				break;
			}
		}
		return out;
	}
	if (c === "'" || c === '"') {
		let j = pos.p + 1;
		while (j < s.length && !(s[j] === c && s[j - 1] !== "\\")) j++;
		const v = s.slice(pos.p + 1, j);
		pos.p = j + 1;
		return v;
	}
	let v = "";
	while (pos.p < s.length && !",}]".includes(s[pos.p])) v += s[pos.p++];
	return v.trim();
}

function skipWs(s, pos) {
	while (pos.p < s.length && /\s/.test(s[pos.p])) pos.p++;
}
