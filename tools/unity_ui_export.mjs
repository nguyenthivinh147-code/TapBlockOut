#!/usr/bin/env node
// Exports UGUI layer prefabs of color-cube-match-puzzle (Unity) to layout specs for src/ui/unity_ui.gd.
// Nested prefabs are flattened with their overrides; every number stays in Unity canvas units (886x1920 reference).
//
// Run: node tools/unity_ui_export.mjs [--src "E:/PROJECT HORUS/color-cube-match-puzzle"] [--only Name,Name]
// Out: data/ui_unity/<Prefab>.json, data/ui_unity/_sprites.json, data/ui_unity/_materials.json,
//      textures copied to assets/ui/cc/ (run --import or an editor scan afterwards).

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { parseUnityFile, parseYaml } from "./unity_yaml.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT_DIR = path.join(ROOT, "data", "ui_unity");
const TEX_DIR = path.join(ROOT, "assets", "ui", "cc");
const TEX_RES = "res://assets/ui/cc/";

const args = process.argv.slice(2);
const arg = (k, d) => {
	const i = args.indexOf(k);
	return i >= 0 ? args[i + 1] : d;
};
const SRC = arg("--src", "E:/PROJECT HORUS/color-cube-match-puzzle");
const ONLY = (arg("--only", "") || "").split(",").filter(Boolean);
const PREFAB_DIRS = [
	"Assets/_Game/Prefabs/Layers",
	"Assets/_Game/Layer/Prefab",
	"Assets/_Game/Prefabs/UI",
	"Assets/_Game/Prefabs/Components",
];
// Main menu and gameplay HUD stay as they are in this game; ad banners have no Godot screen.
const SKIP_PREFABS = new Set(["MainMenuUILayer", "GamePlayUILayer", "BannerAds", "IngameAdsBar"]);

const MASK = (1n << 63n) - 1n;
const xorId = (a, b) => ((BigInt(a) ^ BigInt(b)) & MASK).toString();

// --- asset index (guid -> path) ---

const guidPath = new Map();
function indexDir(dir) {
	let ents;
	try {
		ents = fs.readdirSync(dir, { withFileTypes: true });
	} catch {
		return;
	}
	for (const e of ents) {
		const p = path.join(dir, e.name);
		if (e.isDirectory()) indexDir(p);
		else if (e.name.endsWith(".meta")) {
			const fd = fs.openSync(p, "r");
			const buf = Buffer.alloc(160);
			fs.readSync(fd, buf, 0, 160, 0);
			fs.closeSync(fd);
			const m = /guid: ([0-9a-f]{32})/.exec(buf.toString("utf8"));
			if (m) guidPath.set(m[1], p.slice(0, -5));
		}
	}
}

// --- prefab flattening ---

const flatCache = new Map();

function loadFlat(file) {
	if (flatCache.has(file)) return flatCache.get(file);
	const objs = parseUnityFile(fs.readFileSync(file, "utf8"));
	for (const doc of [...objs.values()]) {
		if (doc.type !== "PrefabInstance") continue;
		const srcGuid = doc.data.m_SourcePrefab?.guid;
		const srcFile = guidPath.get(srcGuid);
		if (!srcFile) {
			console.warn(`  thiếu prefab nguồn ${srcGuid} trong ${path.basename(file)}`);
			continue;
		}
		const src = loadFlat(srcFile);
		const pid = doc.id;
		const mod = doc.data.m_Modification || {};
		const removed = new Set((mod.m_RemovedComponents || []).concat(mod.m_RemovedGameObjects || []).map((r) => xorId(r.fileID, pid)));
		for (const [sid, sdoc] of src) {
			if (sdoc.type === "PrefabInstance") continue;
			const nid = xorId(sid, pid);
			if (removed.has(nid)) continue;
			const clone = { ...sdoc, id: nid, stripped: false, data: remapRefs(structuredClone(sdoc.data), pid) };
			objs.set(nid, clone);
		}
		for (const m of mod.m_Modifications || []) {
			const tid = xorId(m.target.fileID, pid);
			const target = objs.get(tid);
			if (!target) continue;
			setPath(target.data, m.propertyPath, m.value, m.objectReference);
		}
		const parent = mod.m_TransformParent?.fileID || "0";
		for (const sdoc of src.values()) {
			if ((sdoc.type === "RectTransform" || sdoc.type === "Transform") && (sdoc.data.m_Father?.fileID || "0") === "0") {
				const root = objs.get(xorId(sdoc.id, pid));
				if (root) root.data.m_Father = { fileID: parent };
			}
		}
		for (const a of mod.m_AddedGameObjects || []) {
			const t = objs.get(xorId(a.targetCorrespondingSourceObject.fileID, pid));
			if (!t) continue;
			const kids = (t.data.m_Children ||= []);
			if (kids.some((k) => k.fileID === a.addedObject.fileID)) continue;
			const at = Number(a.insertIndex);
			if (at >= 0 && at <= kids.length) kids.splice(at, 0, { fileID: a.addedObject.fileID });
			else kids.push({ fileID: a.addedObject.fileID });
		}
		for (const a of mod.m_AddedComponents || []) {
			const go = objs.get(xorId(a.targetCorrespondingSourceObject.fileID, pid));
			if (!go) continue;
			const comps = (go.data.m_Component ||= []);
			if (!comps.some((c) => c.component.fileID === a.addedObject.fileID)) comps.push({ component: { fileID: a.addedObject.fileID } });
		}
		for (const r of removed) {
			for (const o of objs.values()) {
				if (o.type === "GameObject" && o.data.m_Component) o.data.m_Component = o.data.m_Component.filter((c) => c.component.fileID !== r);
			}
		}
	}
	// Objects added under nested transforms by older Unity versions: attach by m_Father.
	for (const o of objs.values()) {
		if (o.stripped || (o.type !== "RectTransform" && o.type !== "Transform")) continue;
		const f = o.data.m_Father?.fileID || "0";
		if (f === "0") continue;
		const p = objs.get(f);
		if (!p || p.stripped) continue;
		const kids = (p.data.m_Children ||= []);
		if (!kids.some((k) => k.fileID === o.id)) kids.push({ fileID: o.id });
	}
	flatCache.set(file, objs);
	return objs;
}

function remapRefs(v, pid) {
	if (Array.isArray(v)) return v.map((x) => remapRefs(x, pid));
	if (v && typeof v === "object") {
		if ("fileID" in v && !("guid" in v) && v.fileID !== "0" && Object.keys(v).length === 1) return { fileID: xorId(v.fileID, pid) };
		const o = {};
		for (const k of Object.keys(v)) o[k] = remapRefs(v[k], pid);
		return o;
	}
	return v;
}

function setPath(data, propertyPath, value, objRef) {
	const segs = propertyPath.split(".");
	let cur = data;
	for (let i = 0; i < segs.length; i++) {
		const s = segs[i];
		const last = i === segs.length - 1;
		if (s === "Array") continue;
		const dm = /^data\[(\d+)\]$/.exec(s);
		if (s === "size" && Array.isArray(cur)) {
			cur.length = Number(value);
			for (let k = 0; k < cur.length; k++) if (cur[k] === undefined) cur[k] = {};
			return;
		}
		const key = dm ? Number(dm[1]) : s;
		if (last) {
			const old = cur[key];
			const isRef = (old && typeof old === "object" && "fileID" in old) || (value === "" && objRef && objRef.fileID !== "0");
			cur[key] = isRef ? objRef : value;
			return;
		}
		if (cur[key] === undefined || cur[key] === null || typeof cur[key] !== "object") cur[key] = segs[i + 1] === "Array" ? [] : {};
		cur = cur[key];
	}
}

// --- sprites, textures, materials ---

const sprites = {};
const materials = {};
const texNames = new Map();

function pngSize(file) {
	const b = fs.readFileSync(file);
	if (b.readUInt32BE(12) !== 0x49484452) return null;
	return [b.readUInt32BE(16), b.readUInt32BE(20)];
}

// Same basename in several folders (Resources/ and Resources_moved/ both hold UI_Maincenter.png):
// prefix the folder two levels up so the name does not depend on export order.
let imageBaseCount = null;
function texName(file) {
	if (texNames.has(file)) return texNames.get(file);
	if (!imageBaseCount) {
		imageBaseCount = new Map();
		for (const p of guidPath.values()) if (/\.png$/i.test(p)) imageBaseCount.set(path.basename(p), (imageBaseCount.get(path.basename(p)) || 0) + 1);
	}
	let base = path.basename(file);
	if ((imageBaseCount.get(base) || 0) > 1) base = path.basename(path.dirname(path.dirname(file))) + "_" + base;
	base = base.replace(/\s+/g, "_");
	texNames.set(file, base);
	return base;
}

// Unity imports for Android at the platform max size (light1.png 860 px -> 256); the Godot import
// gets the same process/size_limit, and _sprites.json keeps source sizes so regions can be rescaled.
const texInfo = {};
function copyTex(file) {
	const name = texName(file);
	const dst = path.join(TEX_DIR, name);
	if (!fs.existsSync(dst) || fs.statSync(dst).size !== fs.statSync(file).size) fs.copyFileSync(file, dst);
	if (!texInfo[name]) {
		const size = pngSize(file) || [0, 0];
		const limit = androidMaxSize(file);
		texInfo[name] = { size, limit: limit < Math.max(...size) ? limit : 0 };
		const imp = dst + ".import";
		const want = `process/size_limit=${texInfo[name].limit}`;
		const old = fs.existsSync(imp) ? fs.readFileSync(imp, "utf8") : "";
		if (!old.includes(want)) fs.writeFileSync(imp, importFile(old, texInfo[name].limit));
	}
	return name;
}

function androidMaxSize(file) {
	const meta = texMeta(file);
	let size = Number(meta.maxTextureSize || 2048);
	for (const p of meta.platformSettings || []) {
		if (p.buildTarget === "Android" && String(p.overridden) === "1") size = Number(p.maxTextureSize || size);
	}
	return size;
}

// Keep an existing .import (uid, dest paths) and only change the size limit; Godot fills the rest on import.
function importFile(old, limit) {
	if (old.includes("process/size_limit=")) return old.replace(/process\/size_limit=\d+/, `process/size_limit=${limit}`);
	return [
		"[remap]",
		"",
		'importer="texture"',
		'type="CompressedTexture2D"',
		"",
		"[params]",
		"",
		"compress/mode=0",
		"mipmaps/generate=false",
		"process/fix_alpha_border=true",
		"process/premult_alpha=false",
		`process/size_limit=${limit}`,
		"detect_3d/compress_to=1",
		"",
	].join("\n");
}

const metaCache = new Map();
function texMeta(file) {
	if (!metaCache.has(file)) metaCache.set(file, parseYaml(fs.readFileSync(file + ".meta", "utf8")).TextureImporter || {});
	return metaCache.get(file);
}

function spriteKey(ref) {
	if (!ref || ref.fileID === "0" || !ref.guid) return null;
	const file = guidPath.get(ref.guid);
	if (!file || !/\.(png|jpg|jpeg|tga|psd)$/i.test(file)) return null;
	const meta = texMeta(file);
	const size = /\.png$/i.test(file) ? pngSize(file) : null;
	if (!size) {
		console.warn(`  bỏ qua sprite không phải PNG: ${file}`);
		return null;
	}
	const ppu = Number(meta.spritePixelsToUnits || 100);
	let name = null;
	let rect = null;
	let border = null;
	const sheet = meta.spriteSheet?.sprites || [];
	if (String(meta.spriteMode) === "2" || sheet.length) {
		let sp = sheet.find((s) => String(s.internalID) === ref.fileID);
		if (!sp) {
			const tbl = meta.internalIDToNameTable || [];
			const hit = tbl.find((e) => Object.values(e.first || {})[0] === ref.fileID);
			if (hit) sp = sheet.find((s) => s.name === hit.second);
		}
		if (sp) {
			name = sp.name;
			rect = [Number(sp.rect.x), size[1] - Number(sp.rect.y) - Number(sp.rect.height), Number(sp.rect.width), Number(sp.rect.height)];
			border = sp.border;
		}
	}
	if (!rect) {
		rect = [0, 0, size[0], size[1]];
		border = meta.spriteBorder;
	}
	const tex = copyTex(file);
	const key = name ? `${tex.replace(/\.png$/i, "")}:${name}` : tex.replace(/\.png$/i, "");
	if (!sprites[key]) {
		const b = border || {};
		// Unity border x=left, y=bottom, z=right, w=top; stored as Godot left, top, right, bottom.
		sprites[key] = { tex: TEX_RES + tex, src: texInfo[tex].size, r: rect, b: [num(b.x), num(b.w), num(b.z), num(b.y)], ppu };
	}
	return key;
}

function materialKey(ref) {
	if (!ref || !ref.guid) return null;
	const file = guidPath.get(ref.guid);
	if (!file) return null;
	if (file.endsWith(".mat")) {
		const key = path.basename(file, ".mat");
		if (!materials[key]) materials[key] = matParams(parseUnityFile(fs.readFileSync(file, "utf8")), null);
		return key;
	}
	if (file.endsWith(".asset")) {
		const key = `${path.basename(file, ".asset")} (atlas)`;
		if (!materials[key]) materials[key] = matParams(parseUnityFile(fs.readFileSync(file, "utf8")), ref.fileID);
		return key;
	}
	return null;
}

function matParams(docs, fileID) {
	const doc = fileID ? docs.get(fileID) : [...docs.values()].find((d) => d.type === "Material");
	if (!doc) return {};
	const d = doc.data;
	const props = d.m_SavedProperties || {};
	const floats = {};
	for (const e of props.m_Floats || []) Object.assign(floats, e);
	const colors = {};
	for (const e of props.m_Colors || []) for (const [k, v] of Object.entries(e)) colors[k] = color(v);
	const kw = Array.isArray(d.m_ValidKeywords) ? d.m_ValidKeywords : String(d.m_ShaderKeywords || "").split(" ").filter(Boolean);
	const f = (k, dv = 0) => (floats[k] === undefined ? dv : Number(floats[k]));
	return {
		underlay: kw.includes("UNDERLAY_ON"),
		face_color: colors._FaceColor || "ffffffff",
		face_dilate: f("_FaceDilate"),
		outline_width: f("_OutlineWidth"),
		outline_softness: f("_OutlineSoftness"),
		outline_color: colors._OutlineColor || "000000ff",
		underlay_color: colors._UnderlayColor || "00000080",
		underlay_offset: [f("_UnderlayOffsetX"), f("_UnderlayOffsetY")],
		underlay_dilate: f("_UnderlayDilate"),
		underlay_softness: f("_UnderlaySoftness"),
		weight_normal: f("_WeightNormal"),
		weight_bold: f("_WeightBold", 0.5),
		scale_ratio: [f("_ScaleRatioA", 1), f("_ScaleRatioB", 1), f("_ScaleRatioC", 1)],
		gradient_scale: f("_GradientScale", 7),
	};
}

// --- animator: default state of layer 0, exported as Hermite curves ---

const anims = {};

function exportController(file) {
	const key = path.basename(file, ".controller");
	if (anims[key] !== undefined) return key;
	anims[key] = null;
	const docs = parseUnityFile(fs.readFileSync(file, "utf8"));
	const ctl = [...docs.values()].find((d) => d.type === "AnimatorController");
	const smRef = ctl?.data.m_AnimatorLayers?.[0]?.m_StateMachine?.fileID;
	const sm = docs.get(smRef);
	const state = docs.get(sm?.data.m_DefaultState?.fileID);
	const motion = state?.data.m_Motion;
	const clipFile = motion?.guid ? guidPath.get(motion.guid) : null;
	if (!clipFile || !clipFile.endsWith(".anim")) {
		console.warn(`  controller ${key}: không có clip mặc định`);
		return key;
	}
	anims[key] = { state: state.data.m_Name, speed: num(state.data.m_Speed, 1), ...exportClip(clipFile) };
	return key;
}

function exportClip(file) {
	const doc = [...parseUnityFile(fs.readFileSync(file, "utf8")).values()].find((d) => d.type === "AnimationClip");
	const d = doc.data;
	const set = d.m_AnimationClipSettings || {};
	const curves = [];
	const keys = (c) => (c?.m_Curve || []).map((k) => [r4(k.time), r4(k.value), slope(k.inSlope), slope(k.outSlope)]);
	for (const c of d.m_FloatCurves || []) curves.push({ path: c.path || "", attr: c.attribute, cls: num(c.classID), keys: keys(c.curve) });
	const vecCurves = [
		["m_PositionCurves", "m_LocalPosition"],
		["m_ScaleCurves", "m_LocalScale"],
		["m_EulerCurves", "localEulerAnglesRaw"],
	];
	for (const [field, attr] of vecCurves) {
		for (const c of d[field] || []) {
			for (const ax of ["x", "y", "z"]) {
				const ks = (c.curve?.m_Curve || []).map((k) => [r4(k.time), r4(k.value?.[ax]), slope(k.inSlope?.[ax]), slope(k.outSlope?.[ax])]);
				if (ks.some((k) => k[1] !== ks[0][1]) || attr !== "m_LocalPosition" || ax !== "z") curves.push({ path: c.path || "", attr: `${attr}.${ax}`, cls: 224, keys: ks });
			}
		}
	}
	for (const c of d.m_PPtrCurves || []) {
		curves.push({ path: c.path || "", attr: c.attribute, cls: num(c.classID), sprites: (c.curve || []).map((k) => [r4(k.time), spriteKey(k.value)]) });
	}
	return { clip: d.m_Name, length: r4(num(set.m_StopTime) - num(set.m_StartTime)), loop: set.m_LoopTime === "1", curves };
}

// Unity writes infinite slopes for stepped keys.
function slope(v) {
	if (v === "Infinity" || v === "-Infinity") return null;
	return r4(v);
}

// --- tree ---

const BUILTIN = {
	fe87c0e1cc204ed48ad3b37840f39efc: "Image",
	"1344c3c82d62a2a41a3576d8abb8e3ea": "RawImage",
	"4e29b1a8efbd4b44bb3f3716e73f07ff": "Button",
	"9085046f02f69544eb97fd06b6048fe2": "Toggle",
	"31a19414c41e5ae4aae2af33fee712f6": "Mask",
	"3312d7739989d2b4e91e6319e9a96d76": "RectMask2D",
	"1aa08ab6e0800fa44ae55d278d1423e3": "ScrollRect",
	"67db9e8f0e2ae9c40bc1e2b64352a6b4": "Slider",
	"30649d3a9faa99c48a7b1166b86bf2a0": "HorizontalLayoutGroup",
	"59f8146938fff824cb5fd77236b75775": "VerticalLayoutGroup",
	"8a8695521f0d02e499659fee002a26c2": "GridLayoutGroup",
	"306cc8c2b49d7114eaa3623786fc2126": "LayoutElement",
	"3245ec927659c4140ac4f8d17403cc18": "ContentSizeFitter",
	"86710e43de46f6f4bac7c8e0b8ea2c05": "AspectRatioFitter",
	e19747de3f5aca642ab2be37e372fb86: "Outline",
	cfabb0440166ab443bba8876756fdfa9: "Shadow",
	f4688fdb7df04437aeb418b961361dc5: "TextMeshProUGUI",
	"2da0c512f12947e489f739169773d7ca": "TMP_InputField",
	"5f7201a12d95ffc409449d95f23cf332": "Text",
};
const SKIP_SCRIPTS = new Set(["GraphicRaycaster", "Localize", "ImageStateKeeper", "RectTransformStateKeeper", "TMP_StateHandler", "UIParticle", "EventTrigger", "Canvas", "CanvasScaler"]);

function scriptName(guid) {
	if (BUILTIN[guid]) return BUILTIN[guid];
	const p = guidPath.get(guid);
	return p ? path.basename(p, ".cs") : `?${guid.slice(0, 8)}`;
}

const num = (v, d = 0) => (v === undefined || v === null || v === "" ? d : Number(v));
const r4 = (v) => Math.round(num(v) * 10000) / 10000;
const vec = (v, d = [0, 0]) => (v ? [r4(v.x ?? d[0]), r4(v.y ?? d[1])] : d);

function color(c) {
	if (!c) return "ffffffff";
	const h = (x) =>
		Math.round(Math.min(1, Math.max(0, num(x, 1))) * 255)
			.toString(16)
			.padStart(2, "0");
	return h(c.r) + h(c.g) + h(c.b) + h(c.a);
}

function zRotation(q) {
	if (!q) return 0;
	const z = num(q.z);
	const w = num(q.w, 1);
	const deg = (2 * Math.atan2(z, w) * 180) / Math.PI;
	return Math.round(deg * 100) / 100;
}

function buildTree(objs) {
	const roots = [...objs.values()].filter((o) => !o.stripped && o.type === "RectTransform" && (o.data.m_Father?.fileID || "0") === "0");
	if (!roots.length) return null;
	const goOf = new Map();
	for (const o of objs.values()) if (o.data?.m_GameObject?.fileID) goOf.set(o.id, o.data.m_GameObject.fileID);
	const refNode = (ref) => (ref && ref.fileID && ref.fileID !== "0" ? goOf.get(ref.fileID) || ref.fileID : null);
	return node(objs, roots[0].id, refNode);
}

function node(objs, tid, refNode) {
	const t = objs.get(tid);
	if (!t || t.type !== "RectTransform") return null;
	const go = objs.get(t.data.m_GameObject?.fileID);
	if (!go) console.warn(`  RectTransform ${tid} không có GameObject (${t.data.m_GameObject?.fileID})`);
	const d = t.data;
	const n = {
		n: go?.data.m_Name ?? "?",
		id: go?.id,
		a: String(go?.data.m_IsActive ?? "1") === "1",
		r: [...vec(d.m_AnchorMin), ...vec(d.m_AnchorMax), ...vec(d.m_AnchoredPosition), ...vec(d.m_SizeDelta), ...vec(d.m_Pivot, [0.5, 0.5])],
	};
	const sc = vec(d.m_LocalScale, [1, 1]);
	if (sc[0] !== 1 || sc[1] !== 1) n.s = sc;
	const z = zRotation(d.m_LocalRotation);
	if (z) n.z = z;
	const cs = [];
	for (const c of go?.data.m_Component || []) {
		const comp = objs.get(c.component.fileID);
		if (!comp || comp.type === "RectTransform" || comp.type === "CanvasRenderer") continue;
		const cd = comp.data;
		const enabled = String(cd.m_Enabled ?? "1") === "1";
		if (comp.type === "CanvasGroup") {
			n.cg = { alpha: r4(num(cd.m_Alpha, 1)), inter: cd.m_Interactable === "1", block: cd.m_BlocksRaycasts === "1", ignore_parent: cd.m_IgnoreParentGroups === "1" };
			continue;
		}
		if (comp.type === "Canvas") {
			n.canvas = { override_sort: cd.m_OverrideSorting === "1", order: num(cd.m_SortingOrder) };
			continue;
		}
		if (comp.type === "Animator") {
			const ctl = guidPath.get(cd.m_Controller?.guid);
			n.anim = { controller: ctl ? exportController(ctl) : null, on: enabled };
			continue;
		}
		if (comp.type !== "MonoBehaviour") continue;
		const sname = scriptName(cd.m_Script?.guid || "");
		if (!enabled && sname !== "Image" && sname !== "CutoutMaskUI" && sname !== "TextMeshProUGUI") continue;
		switch (sname) {
			case "Image":
			case "CutoutMaskUI":
				n.img = {
					sp: spriteKey(cd.m_Sprite),
					c: color(cd.m_Color),
					t: num(cd.m_Type),
					pa: cd.m_PreserveAspect === "1",
					fc: cd.m_FillCenter !== "0",
					fm: num(cd.m_FillMethod),
					fa: r4(num(cd.m_FillAmount, 1)),
					fo: num(cd.m_FillOrigin),
					cw: cd.m_FillClockwise !== "0",
					ppu: r4(num(cd.m_PixelsPerUnitMultiplier, 1)),
					rt: cd.m_RaycastTarget === "1",
					on: enabled,
				};
				if (cd.m_Material?.guid) n.img.mat = path.basename(guidPath.get(cd.m_Material.guid) || "", ".mat");
				// CutoutMaskUI: an Image drawn where the parent Mask's stencil does not match (outside its shape).
				if (sname === "CutoutMaskUI") n.img.cut = true;
				break;
			case "RawImage": {
				const f = guidPath.get(cd.m_Texture?.guid);
				n.raw = { tex: f && /\.png$/i.test(f) ? TEX_RES + copyTex(f) : null, c: color(cd.m_Color), uv: cd.m_UVRect, rt: cd.m_RaycastTarget === "1" };
				break;
			}
			case "TextMeshProUGUI":
				n.txt = {
					s: String(cd.m_text ?? ""),
					fs: r4(cd.m_fontSize),
					auto: cd.m_enableAutoSizing === "1" ? [r4(cd.m_fontSizeMin), r4(cd.m_fontSizeMax)] : null,
					c: color(cd.m_fontColor),
					h: num(cd.m_HorizontalAlignment, 1),
					v: num(cd.m_VerticalAlignment, 256),
					w: cd.m_enableWordWrapping !== "0",
					ov: num(cd.m_overflowMode),
					st: num(cd.m_fontStyle),
					mat: materialKey(cd.m_sharedMaterial),
					font: path.basename(guidPath.get(cd.m_fontAsset?.guid) || "", ".asset"),
					cs: r4(cd.m_characterSpacing),
					ws: r4(cd.m_wordSpacing),
					ls: r4(cd.m_lineSpacing),
					m: cd.m_margin ? [r4(cd.m_margin.x), r4(cd.m_margin.y), r4(cd.m_margin.z), r4(cd.m_margin.w)] : [0, 0, 0, 0],
					rt: cd.m_RaycastTarget === "1",
					rich: cd.m_isRichText !== "0",
					on: enabled,
				};
				break;
			case "Button":
			case "Toggle": {
				const colors = cd.m_Colors || {};
				const b = {
					tr: num(cd.m_Transition, 1),
					c: [color(colors.m_NormalColor), color(colors.m_HighlightedColor), color(colors.m_PressedColor), color(colors.m_DisabledColor)],
					mult: r4(num(colors.m_ColorMultiplier, 1)),
					dur: r4(num(colors.m_FadeDuration, 0.1)),
					inter: cd.m_Interactable !== "0",
					target: refNode(cd.m_TargetGraphic),
				};
				if (cd.m_SpriteState) b.sprites = { pressed: spriteKey(cd.m_SpriteState.m_PressedSprite), disabled: spriteKey(cd.m_SpriteState.m_DisabledSprite) };
				if (sname === "Toggle") {
					b.on = cd.m_IsOn === "1";
					b.graphic = refNode(cd.graphic);
					b.group = refNode(cd.m_Group);
					n.tog = b;
				} else n.btn = b;
				break;
			}
			case "HorizontalLayoutGroup":
			case "VerticalLayoutGroup":
			case "GridLayoutGroup": {
				const p = cd.m_Padding || {};
				const l = {
					t: sname[0].toLowerCase(),
					pad: [num(p.m_Left), num(p.m_Right), num(p.m_Top), num(p.m_Bottom)],
					al: num(cd.m_ChildAlignment),
				};
				if (sname === "GridLayoutGroup") {
					l.cell = vec(cd.m_CellSize);
					l.sp = vec(cd.m_Spacing);
					l.corner = num(cd.m_StartCorner);
					l.axis = num(cd.m_StartAxis);
					l.cons = num(cd.m_Constraint);
					l.count = num(cd.m_ConstraintCount, 2);
				} else {
					l.sp = r4(cd.m_Spacing);
					l.cw = cd.m_ChildControlWidth === "1";
					l.ch = cd.m_ChildControlHeight === "1";
					l.ew = cd.m_ChildForceExpandWidth === "1";
					l.eh = cd.m_ChildForceExpandHeight === "1";
					l.sw = cd.m_ChildScaleWidth === "1";
					l.sh = cd.m_ChildScaleHeight === "1";
					l.rev = cd.m_ReverseArrangement === "1";
				}
				n.lay = l;
				break;
			}
			case "LayoutElement":
				n.le = {
					ignore: cd.m_IgnoreLayout === "1",
					min: [r4(num(cd.m_MinWidth, -1)), r4(num(cd.m_MinHeight, -1))],
					pref: [r4(num(cd.m_PreferredWidth, -1)), r4(num(cd.m_PreferredHeight, -1))],
					flex: [r4(num(cd.m_FlexibleWidth, -1)), r4(num(cd.m_FlexibleHeight, -1))],
				};
				break;
			case "ContentSizeFitter":
				n.fit = { h: num(cd.m_HorizontalFit), v: num(cd.m_VerticalFit) };
				break;
			case "AspectRatioFitter":
				n.arf = { mode: num(cd.m_AspectMode), ratio: r4(num(cd.m_AspectRatio, 1)) };
				break;
			case "Mask":
				n.mask = { show: cd.m_ShowMaskGraphic !== "0" };
				break;
			case "RectMask2D":
				n.rmask = true;
				break;
			case "ScrollRect":
				n.scroll = {
					h: cd.m_Horizontal === "1",
					v: cd.m_Vertical === "1",
					content: refNode(cd.m_Content),
					viewport: refNode(cd.m_Viewport),
					move: num(cd.m_MovementType, 1),
					elastic: r4(num(cd.m_Elasticity, 0.1)),
					inertia: cd.m_Inertia !== "0",
					decel: r4(num(cd.m_DecelerationRate, 0.135)),
					wheel: r4(num(cd.m_ScrollSensitivity, 1)),
				};
				break;
			case "Outline":
			case "Shadow":
				(n.fx ||= []).push({ t: sname, c: color(cd.m_EffectColor), d: vec(cd.m_EffectDistance) });
				break;
			case "AudioUIController":
				n.snd = true;
				break;
			case "ClickVibrationEffect":
			case "ButtonVibration":
			case "ToggleVibration":
				n.vib = true;
				break;
			case "Slider":
				n.slider = {
					fill: refNode(cd.m_FillRect),
					handle: refNode(cd.m_HandleRect),
					dir: num(cd.m_Direction),
					min: r4(num(cd.m_MinValue, 0)),
					max: r4(num(cd.m_MaxValue, 1)),
					whole: cd.m_WholeNumbers === "1",
					value: r4(num(cd.m_Value)),
					inter: cd.m_Interactable !== "0",
				};
				break;
			case "TMP_InputField":
				n.input = {
					text_view: refNode(cd.m_TextViewport),
					text: refNode(cd.m_TextComponent),
					placeholder: refNode(cd.m_Placeholder),
					limit: num(cd.m_CharacterLimit),
					// LineType 0 single line, 1 multi line submit, 2 multi line newline.
					line: num(cd.m_LineType),
					content: num(cd.m_ContentType),
					s: String(cd.m_Text ?? ""),
					caret: cd.m_CustomCaretColor === "1" ? color(cd.m_CaretColor) : null,
					sel: color(cd.m_SelectionColor),
					blink: r4(num(cd.m_CaretBlinkRate, 0.85)),
					ro: cd.m_ReadOnly === "1",
					inter: cd.m_Interactable !== "0",
				};
				break;
			default:
				if (!SKIP_SCRIPTS.has(sname)) cs.push({ name: sname, ...scriptFields(cd, refNode) });
		}
	}
	if (cs.length) n.cs = cs;
	const kids = [];
	for (const k of d.m_Children || []) {
		const c = node(objs, k.fileID, refNode);
		if (c) kids.push(c);
	}
	if (kids.length) n.ch = kids;
	return n;
}

// Shallow copy of serialized fields of a custom script; object references become node ids.
function scriptFields(cd, refNode) {
	const out = {};
	for (const [k, v] of Object.entries(cd)) {
		if (k.startsWith("m_") || k === "serializedVersion") continue;
		out[k] = fieldValue(v, refNode);
	}
	return out;
}

function fieldValue(v, refNode) {
	if (Array.isArray(v)) return v.map((x) => fieldValue(x, refNode));
	if (v && typeof v === "object") {
		if (v.m_PersistentCalls) {
			// PersistentListenerMode: 1 void, 2 object, 3 int, 4 float, 5 string, 6 bool.
			return (v.m_PersistentCalls.m_Calls || []).map((c) => {
				const a = c.m_Arguments || {};
				const mode = num(c.m_Mode, 1);
				const arg = mode === 3 ? num(a.m_IntArgument) : mode === 4 ? num(a.m_FloatArgument) : mode === 5 ? a.m_StringArgument : mode === 6 ? a.m_BoolArgument === "1" : null;
				return { target: refNode(c.m_Target), method: c.m_MethodName, arg };
			});
		}
		if ("fileID" in v) {
			if (v.guid) {
				const p = guidPath.get(v.guid);
				if (p && /\.(png)$/i.test(p)) return { sprite: spriteKey(v) };
				if (p && p.endsWith(".asset")) exportAsset(p);
				return { asset: p ? path.basename(p) : v.guid };
			}
			return v.fileID === "0" ? null : { node: refNode(v) };
		}
		const o = {};
		for (const [k, x] of Object.entries(v)) o[k] = fieldValue(x, refNode);
		return o;
	}
	return v;
}

// JSON with tabs, but arrays of plain values and small objects stay on one line.
function stringify(v, ind = "") {
	const flat = (x) => x === null || typeof x !== "object";
	if (flat(v)) return JSON.stringify(v);
	const inner = ind + "\t";
	if (Array.isArray(v)) {
		if (v.every(flat)) return JSON.stringify(v).replace(/,/g, ", ");
		return "[\n" + v.map((x) => inner + stringify(x, inner)).join(",\n") + "\n" + ind + "]";
	}
	const keys = Object.keys(v).filter((k) => v[k] !== undefined);
	const one = JSON.stringify(v);
	if (one.length <= 100 && keys.every((k) => flat(v[k]) || (Array.isArray(v[k]) && v[k].every(flat)))) return one.replace(/,"/g, ', "').replace(/":/g, '": ');
	return "{\n" + keys.map((k) => inner + JSON.stringify(k) + ": " + stringify(v[k], inner)).join(",\n") + "\n" + ind + "}";
}

// Small ScriptableObjects the UI scripts read (RewardItemSO icons, VersionDataSO...), sprites as keys.
const assets = {};
function exportAsset(file) {
	const key = path.basename(file);
	if (key in assets) return;
	assets[key] = null;
	if (fs.statSync(file).size > 200000 || key === "LevelConfigSO.asset") return;
	const doc = [...parseUnityFile(fs.readFileSync(file, "utf8")).values()].find((d) => d.type === "MonoBehaviour");
	if (!doc || /TMP_FontAsset|SpriteAsset/.test(scriptName(doc.data.m_Script?.guid || ""))) {
		delete assets[key];
		return;
	}
	assets[key] = { script: scriptName(doc.data.m_Script?.guid || ""), ...scriptFields(doc.data, () => null) };
}

// --- main ---

function listPrefabs() {
	const out = [];
	for (const rel of PREFAB_DIRS) {
		const dir = path.join(SRC, rel);
		const walk = (d) => {
			for (const e of fs.readdirSync(d, { withFileTypes: true })) {
				const p = path.join(d, e.name);
				if (e.isDirectory()) walk(p);
				else if (e.name.endsWith(".prefab")) out.push(p);
			}
		};
		if (fs.existsSync(dir)) walk(dir);
	}
	return out;
}

function main() {
	const t0 = Date.now();
	indexDir(path.join(SRC, "Assets"));
	for (const pkg of ["com.unity.ugui@1.0.0", "com.unity.textmeshpro@3.0.7", "com.unity.textmeshpro@3.0.6"]) indexDir(path.join(SRC, "Library", "PackageCache", pkg));
	console.log(`index: ${guidPath.size} asset, ${Date.now() - t0} ms`);
	fs.mkdirSync(OUT_DIR, { recursive: true });
	fs.mkdirSync(TEX_DIR, { recursive: true });
	const files = listPrefabs().filter((f) => {
		const n = path.basename(f, ".prefab");
		return ONLY.length ? ONLY.includes(n) : !SKIP_PREFABS.has(n);
	});
	let n = 0;
	for (const f of files) {
		const name = path.basename(f, ".prefab");
		const tree = buildTree(loadFlat(f));
		if (!tree) {
			console.warn(`  ${name}: không có RectTransform gốc, bỏ qua`);
			continue;
		}
		const rel = path.relative(SRC, f).replace(/\\/g, "/");
		fs.writeFileSync(path.join(OUT_DIR, name + ".json"), stringify({ name, source: rel, root: tree }) + "\n");
		n++;
	}
	const sorted = (o) => Object.fromEntries(Object.keys(o).sort().map((k) => [k, o[k]]));
	// --only merges into the existing tables instead of dropping entries of other prefabs.
	const write = (file, table) => {
		const p = path.join(OUT_DIR, file);
		const old = ONLY.length && fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf8")) : {};
		fs.writeFileSync(p, JSON.stringify(sorted({ ...old, ...table }), null, "\t") + "\n");
	};
	write("_sprites.json", sprites);
	write("_materials.json", materials);
	write("_anims.json", anims);
	write("_assets.json", Object.fromEntries(Object.entries(assets).filter(([, v]) => v)));
	console.log(`xuất ${n} prefab, ${Object.keys(sprites).length} sprite, ${texNames.size} texture, ${Object.keys(materials).length} material (${Date.now() - t0} ms)`);
}

main();
