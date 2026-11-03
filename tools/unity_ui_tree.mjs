#!/usr/bin/env node
// Prints the node tree of an exported Unity layout (data/ui_unity/<Layer>.json) with UView paths.
// Run: node tools/unity_ui_tree.mjs PopupOkLayer [--all]   (--all also lists script fields)

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const name = process.argv[2];
const all = process.argv.includes("--all");
if (!name) {
	console.log("node tools/unity_ui_tree.mjs <Layer> [--all]");
	process.exit(1);
}
const data = JSON.parse(fs.readFileSync(path.join(ROOT, "data", "ui_unity", name + ".json"), "utf8"));
const ids = new Map();
const index = (n, p) => {
	ids.set(n.id, p);
	const counts = {};
	for (const c of n.ch || []) {
		counts[c.n] = (counts[c.n] || 0) + 1;
		const key = counts[c.n] === 1 ? c.n : `${c.n}#${counts[c.n]}`;
		index(c, p === "" ? key : `${p}/${key}`);
	}
};
index(data.root, "");

const walk = (n, depth) => {
	const p = ids.get(n.id);
	const r = n.r;
	const anchors = r[0] === r[2] && r[1] === r[3] ? `@${r[0]},${r[1]}` : `@${r[0]},${r[1]}-${r[2]},${r[3]}`;
	const parts = [`${"  ".repeat(depth)}${p === "" ? "<root>" : p}`, anchors, `pos ${r[4]},${r[5]} size ${r[6]}x${r[7]}`];
	if (!n.a) parts.push("[inactive]");
	if (n.s) parts.push(`scale ${n.s}`);
	if (n.z) parts.push(`rot ${n.z}`);
	if (n.img) parts.push(`img ${n.img.sp ?? "#" + n.img.c}${n.img.t ? " t" + n.img.t : ""}`);
	if (n.txt) parts.push(`txt "${n.txt.s.replace(/\n/g, "\\n").slice(0, 40)}" ${n.txt.fs}${n.txt.auto ? " auto" + JSON.stringify(n.txt.auto) : ""} ${n.txt.mat ?? ""}`);
	if (n.btn) parts.push("BUTTON");
	if (n.tog) parts.push(`TOGGLE${n.tog.on ? " on" : ""}`);
	if (n.lay) parts.push(`layout ${n.lay.t}`);
	if (n.fit) parts.push("fitter");
	if (n.scroll) parts.push("SCROLL");
	if (n.mask || n.rmask) parts.push("mask");
	if (n.img?.cut) parts.push("CUTOUT");
	if (n.slider) parts.push(`SLIDER ${n.slider.value} [${n.slider.min},${n.slider.max}] dir ${n.slider.dir}`);
	if (n.input) parts.push(`INPUT ${n.input.line ? "multi" : "single"} limit ${n.input.limit}`);
	if (n.anim) parts.push(`anim ${n.anim.controller}${n.anim.on ? "" : " (off)"}`);
	for (const c of n.cs || []) parts.push(`{${c.name}}`);
	console.log(parts.join("  "));
	if (all) {
		for (const c of n.cs || []) {
			for (const [k, v] of Object.entries(c)) {
				if (k === "name") continue;
				const show = JSON.stringify(v, (kk, vv) => (vv && typeof vv === "object" && "node" in vv ? `->${ids.get(vv.node) ?? vv.node}` : vv));
				console.log(`${"  ".repeat(depth + 2)}${c.name}.${k} = ${show.length > 160 ? show.slice(0, 160) + "…" : show}`);
			}
		}
	}
	for (const c of n.ch || []) walk(c, depth + 1);
};
walk(data.root, 0);
