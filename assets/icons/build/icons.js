// Icon generator — the single source of truth for assets/icons/*.svg + *.png.
// Style: flat-shaded faceted "low-poly" vector art, light from top-left, 3 tones per
// material (l / m / d), no outlines, no gradients, no filters. Full spec: docs/STYLES.md.
//
//   node assets/icons/build/icons.js            -> writes all 24 svg + png
//   node assets/icons/build/icons.js sheet      -> also writes build/contact_sheet.png
//   node assets/icons/build/icons.js <id> ...   -> only those ids
//
// PNG rendering needs @resvg/resvg-js; resolved from ~/svg2png-tmp or the local node path.

const fs = require("fs");
const path = require("path");
const os = require("os");

let Resvg = null;
for (const p of [
	path.join(os.homedir(), "svg2png-tmp", "node_modules", "@resvg", "resvg-js"),
	"@resvg/resvg-js",
]) {
	try {
		Resvg = require(p).Resvg;
		break;
	} catch (_) {}
}

const OUT = path.join(__dirname, "..");
const SIZE = 256;

// ---------------------------------------------------------------- palette
const P = {
	plate: "#171a1e",
	plateFacet: "#1e2227",
	plateEdge: "#2a3038",
	shadow: "#07090b",
	gun: { l: "#9aa4ae", m: "#636d77", d: "#3d454d" }, // steel / gunmetal
	dark: { l: "#4b5159", m: "#30353b", d: "#1f2327" }, // black polymer / rubber
	olive: { l: "#8e9862", m: "#636e42", d: "#41492b" }, // military green
	tan: { l: "#c9ac7c", m: "#9e835a", d: "#6e5a3c" }, // coyote / cardboard
	brass: { l: "#e6bd60", m: "#bf9136", d: "#845f20" }, // cartridge brass
	white: { l: "#f2f4f6", m: "#c9ced4", d: "#99a1a9" }, // medical / paper
	red: { l: "#e85a5a", m: "#b93434", d: "#7e2020" }, // blood / danger
};

function hexToRgb(h) {
	const n = parseInt(h.slice(1), 16);
	return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function rgbToHex(r, g, b) {
	return (
		"#" +
		[r, g, b]
			.map((v) =>
				Math.max(0, Math.min(255, Math.round(v)))
					.toString(16)
					.padStart(2, "0")
			)
			.join("")
	);
}
function mix(h, target, t) {
	const a = hexToRgb(h);
	const b = hexToRgb(target);
	return rgbToHex(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t);
}
// Accent material derived from the icon's accent color (readAccents below)
function tone(hex) {
	return { l: mix(hex, "#ffffff", 0.3), m: hex, d: mix(hex, "#000000", 0.38) };
}

// ---------------------------------------------------------------- primitives
const pts = (arr) => arr.map(([x, y]) => `${+x.toFixed(1)},${+y.toFixed(1)}`).join(" ");
const poly = (arr, fill, extra = "") => `<polygon points="${pts(arr)}" fill="${fill}" ${extra}/>`;
const rect = (x, y, w, h, fill, extra = "") =>
	`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}" ${extra}/>`;
const circle = (cx, cy, r, fill, extra = "") => `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}" ${extra}/>`;
const ellipse = (cx, cy, rx, ry, fill, extra = "") =>
	`<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${fill}" ${extra}/>`;
const line = (arr, stroke, w, extra = "") =>
	`<polyline points="${pts(arr)}" fill="none" stroke="${stroke}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" ${extra}/>`;
const g = (inner, extra = "") => `<g ${extra}>${inner.join("\n")}</g>`;

// Regular polygon approximating a circle/ellipse with visible facets (low-poly look).
function facetEllipse(cx, cy, rx, ry, fill, n = 10, rot = 0, extra = "") {
	const arr = [];
	for (let i = 0; i < n; i++) {
		const a = rot + (i / n) * Math.PI * 2;
		arr.push([cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]);
	}
	return poly(arr, fill, extra);
}

// Isometric axes (2:1-ish). Right axis goes right-up, left axis goes left-up.
const R = [0.866, -0.5];
const L = [-0.866, -0.5];
const add = (p, v, k) => [p[0] + v[0] * k, p[1] + v[1] * k];
const up = (p, h) => [p[0], p[1] - h];

// Iso box standing on (cx, baseY) = front-bottom corner. w along right axis, d along left.
// Three visible faces: left face lit (m), right face shaded (d), top brightest (l).
function isoBox(cx, baseY, w, d, h, mat, opts = {}) {
	const A = [cx, baseY];
	const B = add(A, R, w);
	const C = add(A, L, d);
	const D = add(B, L, d);
	const faces = [
		poly([A, C, up(C, h), up(A, h)], opts.left || mat.m),
		poly([A, B, up(B, h), up(A, h)], opts.right || mat.d),
		poly([up(A, h), up(B, h), up(D, h), up(C, h)], opts.top || mat.l),
	];
	return { svg: faces.join("\n"), A, B, C, D };
}

// Vertical cylinder: three vertical tone bands + faceted caps.
function cylinder(x, y, w, h, mat, opts = {}) {
	const ry = opts.ry ?? w * 0.22;
	const bandL = Math.round(w * 0.18);
	const bandM = Math.round(w * 0.42);
	const body = [
		rect(x, y, bandL, h, mat.l),
		rect(x + bandL, y, bandM, h, mat.m),
		rect(x + bandL + bandM, y, w - bandL - bandM, h, mat.d),
	];
	const bottom = facetEllipse(x + w / 2, y + h, w / 2, ry, mat.d, 12);
	const top = facetEllipse(x + w / 2, y, w / 2, ry, opts.top || mat.l, 12);
	return [bottom, ...body, top].join("\n");
}

const shadow = (cy = 208, rx = 72, ry = 11) => ellipse(128, cy, rx, ry, P.shadow, 'opacity="0.55"');

function plate() {
	return [
		`<clipPath id="plateClip"><rect x="0" y="0" width="${SIZE}" height="${SIZE}" rx="24"/></clipPath>`,
		`<g clip-path="url(#plateClip)">`,
		rect(0, 0, SIZE, SIZE, P.plate),
		poly(
			[
				[0, 0],
				[SIZE, 0],
				[0, SIZE],
			],
			P.plateFacet
		),
		`</g>`,
		`<rect x="3" y="3" width="${SIZE - 6}" height="${SIZE - 6}" rx="21" fill="none" stroke="${P.plateEdge}" stroke-width="3"/>`,
	].join("\n");
}

function wrap(inner) {
	return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}">\n${plate()}\n${inner}\n</svg>\n`;
}

// ---------------------------------------------------------------- icons
const ICONS = {};

// 1. Hollow Point Rounds — three cartridges, hollow red-ringed tips
ICONS.hollow_point_rounds = (acc) => {
	const cart = (x, base, h = 86) => {
		const y0 = base - h; // shoulder (casing top)
		return [
			rect(x, y0, 10, h, P.brass.l),
			rect(x + 10, y0, 10, h, P.brass.m),
			rect(x + 20, y0, 10, h, P.brass.d),
			rect(x - 2, base - 8, 34, 8, P.brass.d),
			rect(x, base - 16, 30, 4, P.brass.d),
			poly([[x, y0], [x + 2, y0 - 22], [x + 15, y0 - 44], [x + 15, y0]], P.gun.m),
			poly([[x + 15, y0 - 44], [x + 28, y0 - 22], [x + 30, y0], [x + 15, y0]], P.gun.d),
			poly([[x + 2, y0 - 22], [x + 15, y0 - 44], [x + 9, y0 - 20]], P.gun.l),
			poly([[x + 9, y0 - 28], [x + 15, y0 - 40], [x + 21, y0 - 28]], acc.d),
			rect(x, y0 - 4, 30, 5, acc.m),
		].join("\n");
	};
	return [shadow(206, 78, 11), cart(70, 194), cart(156, 194), cart(113, 206, 92)].join("\n");
};

// 2. Adrenaline Injector — auto-injector pen, tilted
ICONS.adrenaline_injector = (acc) => {
	const body = [
		rect(28, 124, 30, 8, P.white.m),
		rect(28, 124, 30, 3, P.white.l),
		rect(58, 108, 130, 10, P.dark.l),
		rect(58, 118, 130, 20, P.dark.m),
		rect(58, 138, 130, 10, P.dark.d),
		rect(52, 112, 14, 32, P.gun.d),
		rect(52, 112, 14, 8, P.gun.l),
		rect(88, 114, 68, 28, acc.d),
		rect(90, 116, 64, 24, acc.m),
		rect(90, 116, 64, 7, acc.l),
		rect(186, 106, 26, 44, P.gun.m),
		rect(186, 106, 26, 10, P.gun.l),
		rect(186, 140, 26, 10, P.gun.d),
		rect(212, 116, 10, 24, acc.m),
	];
	return [shadow(208, 84, 10), g(body, 'transform="rotate(-38 128 128)"')].join("\n");
};

// 3. Tactical Drone Beacon — tripod beacon with blue lamp and signal chevrons
ICONS.tactical_drone_beacon = (acc) => {
	return [
		shadow(210, 80, 10),
		poly([[114, 176], [122, 176], [72, 210], [62, 210]], P.dark.m),
		poly([[134, 176], [142, 176], [194, 210], [184, 210]], P.dark.d),
		poly([[124, 180], [132, 180], [134, 212], [122, 212]], P.dark.m),
		cylinder(102, 118, 52, 62, P.gun),
		rect(102, 150, 52, 6, P.dark.d),
		rect(110, 104, 36, 14, P.dark.m),
		rect(110, 104, 36, 4, P.dark.l),
		poly([[112, 104], [128, 78], [144, 104]], acc.m),
		poly([[112, 104], [128, 78], [124, 104]], acc.l),
		line([[88, 86], [96, 72], [110, 64]], acc.m, 6),
		line([[168, 86], [160, 72], [146, 64]], acc.m, 6),
		line([[72, 74], [84, 52], [106, 40]], acc.m, 6, 'opacity="0.55"'),
		line([[184, 74], [172, 52], [150, 40]], acc.m, 6, 'opacity="0.55"'),
	].join("\n");
};

// 4. Emergency Ammo Cache — iso ammo crate
ICONS.emergency_ammo_cache = (acc) => {
	const box = isoBox(92, 200, 112, 64, 74, P.olive);
	const { A, B, C } = box;
	const seamL = [up(A, 56), up(C, 56), up(C, 60), up(A, 60)];
	const seamR = [up(A, 56), up(B, 56), up(B, 60), up(A, 60)];
	const stencil = [add(up(A, 22), L, 10), add(up(A, 22), L, 54), add(up(A, 44), L, 54), add(up(A, 44), L, 10)];
	const glyph = (k) => {
		const p = add(up(A, 24), R, k);
		return poly([p, add(p, R, 10), up(add(p, R, 10), 22), up(add(p, R, 5), 30), up(p, 22)], P.white.d);
	};
	const hb = add(up(A, 74), R, 46);
	const handle = poly([add(hb, L, 20), add(hb, L, 44), up(add(hb, L, 44), 8), up(add(hb, L, 20), 8)], P.dark.m);
	return [
		shadow(206, 92, 12),
		box.svg,
		poly(seamL, P.olive.d),
		poly(seamR, P.olive.d),
		poly(stencil, P.white.m),
		poly([stencil[0], stencil[1], add(stencil[1], [0, 1], 6), add(stencil[0], [0, 1], 6)], acc.l),
		glyph(16),
		glyph(36),
		glyph(56),
		glyph(76),
		handle,
	].join("\n");
};

// 5. Air Support Authorization — strike jet under a targeting ring (Legendary)
ICONS.air_support_authorization = (acc) => {
	const jetL = [
		poly([[128, 48], [128, 196], [118, 190], [116, 108]], P.gun.l),
		poly([[118, 118], [118, 150], [54, 162], [54, 152]], P.gun.m),
		poly([[118, 168], [118, 190], [92, 202], [92, 194]], P.gun.m),
	];
	const jetR = [
		poly([[128, 48], [128, 196], [138, 190], [140, 108]], P.gun.m),
		poly([[138, 118], [138, 150], [202, 162], [202, 152]], P.gun.d),
		poly([[138, 168], [138, 190], [164, 202], [164, 194]], P.gun.d),
	];
	const ring = [
		`<circle cx="128" cy="128" r="92" fill="none" stroke="${acc.d}" stroke-width="3"/>`,
		`<circle cx="128" cy="128" r="80" fill="none" stroke="${acc.m}" stroke-width="7"/>`,
		line([[128, 30], [128, 56]], acc.m, 7),
		line([[128, 200], [128, 226]], acc.m, 7),
		line([[30, 128], [56, 128]], acc.m, 7),
		line([[200, 128], [226, 128]], acc.m, 7),
		poly([[128, 118], [136, 128], [128, 138], [120, 128]], acc.l),
	];
	return [...jetL, ...jetR, ...ring].join("\n");
};

// 6. Kevlar Plate Carrier — vest front
ICONS.kevlar_plate_carrier = (acc) => {
	return [
		shadow(210, 80, 10),
		poly([[128, 66], [104, 52], [78, 60], [66, 122], [84, 206], [128, 206]], P.dark.l),
		poly([[128, 66], [152, 52], [178, 60], [190, 122], [172, 206], [128, 206]], P.dark.m),
		rect(84, 176, 88, 5, P.dark.d),
		rect(84, 190, 88, 5, P.dark.d),
		rect(98, 92, 60, 76, P.gun.m),
		rect(98, 92, 12, 76, P.gun.l),
		rect(146, 92, 12, 76, P.gun.d),
		rect(98, 92, 60, 6, P.gun.l),
		rect(106, 70, 44, 12, acc.m),
		rect(106, 70, 44, 4, acc.l),
		rect(90, 60, 10, 20, acc.d),
		rect(156, 60, 10, 20, acc.d),
	].join("\n");
};

// 7. Vampire Serum — blood vial
ICONS.vampire_serum = (acc) => {
	const glassL = [[100, 70], [100, 170], [112, 192], [128, 196], [128, 70]];
	const glassR = [[128, 70], [128, 196], [144, 192], [156, 170], [156, 70]];
	return [
		shadow(206, 64, 10),
		poly(glassL, "#3a4049"),
		poly(glassR, "#2b3037"),
		poly([[100, 118], [100, 170], [112, 192], [128, 196], [128, 118]], P.red.m),
		poly([[128, 118], [128, 196], [144, 192], [156, 170], [156, 118]], P.red.d),
		rect(100, 118, 12, 56, P.red.l),
		poly([[100, 118], [156, 118], [156, 124], [100, 124]], acc.l, 'opacity="0.6"'),
		rect(140, 86, 10, 4, P.gun.l),
		rect(140, 100, 10, 4, P.gun.l),
		rect(140, 132, 10, 4, P.white.l, 'opacity="0.5"'),
		rect(96, 48, 64, 24, P.gun.m),
		rect(96, 48, 14, 24, P.gun.l),
		rect(146, 48, 14, 24, P.gun.d),
		rect(96, 48, 64, 6, P.gun.l),
		rect(94, 70, 68, 6, P.gun.d),
		poly([[184, 150], [196, 168], [192, 180], [176, 180], [172, 168]], acc.m),
		poly([[184, 150], [172, 168], [176, 180], [182, 180]], acc.l),
	].join("\n");
};

// 8. Ricochet Rounds — bullet with a bouncing path
ICONS.ricochet_rounds = (acc) => {
	const spark = (x, y) => poly([[x, y - 14], [x + 10, y], [x, y + 14], [x - 10, y]], acc.l);
	return [
		line([[52, 190], [112, 90], [164, 178], [214, 110]], acc.d, 14),
		line([[52, 190], [112, 90], [164, 178], [214, 110]], acc.m, 8),
		spark(112, 88),
		spark(164, 180),
		poly([[206, 94], [230, 92], [226, 118]], acc.m),
		g(
			[
				rect(-30, -11, 34, 22, P.brass.m),
				rect(-30, -11, 34, 7, P.brass.l),
				rect(-30, 4, 34, 7, P.brass.d),
				rect(-34, -13, 6, 26, P.brass.d),
				poly([[4, -11], [26, -4], [30, 0], [26, 4], [4, 11]], P.gun.m),
				poly([[4, -11], [26, -4], [30, 0], [4, 0]], P.gun.l),
			],
			'transform="translate(68 164) rotate(-59)"'
		),
	].join("\n");
};

// 9. Shrapnel Magazine — rifle mag with fragments flying off
ICONS.shrapnel_magazine = (acc) => {
	const shard = (x, y, s, r, t) =>
		poly([[0, -s], [s * 0.7, 0], [0, s * 1.2], [-s * 0.7, 0]], t, `transform="translate(${x} ${y}) rotate(${r})"`);
	return [
		shadow(210, 70, 10),
		poly([[100, 96], [128, 96], [136, 200], [116, 208], [96, 160]], P.dark.l),
		poly([[128, 96], [160, 96], [176, 150], [172, 200], [136, 200]], P.dark.m),
		rect(100, 122, 60, 5, P.dark.d),
		rect(102, 146, 64, 5, P.dark.d),
		rect(106, 170, 64, 5, P.dark.d),
		rect(100, 86, 60, 10, P.gun.m),
		rect(100, 86, 60, 4, P.gun.l),
		poly([[108, 86], [152, 86], [146, 66], [114, 66]], P.brass.m),
		poly([[108, 86], [114, 66], [122, 66], [122, 86]], P.brass.l),
		poly([[114, 66], [146, 66], [136, 52], [124, 52]], P.gun.m),
		shard(70, 70, 14, 25, acc.m),
		shard(190, 60, 12, -20, acc.m),
		shard(60, 120, 10, -40, acc.l),
		shard(200, 108, 10, 35, acc.l),
		shard(176, 36, 8, 10, acc.d),
		shard(92, 44, 8, -15, acc.d),
	].join("\n");
};

// 10. Incendiary Gel — fuel canister with a flame
ICONS.incendiary_gel = (acc) => {
	const can = isoBox(100, 204, 66, 44, 92, P.olive);
	const { A, B, C } = can;
	const spoutBase = add(add(up(A, 92), R, 14), L, 22);
	const flame = [
		poly([[118, 110], [100, 70], [120, 36], [136, 60], [150, 46], [160, 86], [146, 112]], acc.m),
		poly([[118, 110], [100, 70], [120, 36], [126, 70]], acc.l),
		poly([[128, 112], [118, 84], [132, 62], [144, 90], [142, 112]], acc.l, 'opacity="0.85"'),
		poly([[128, 112], [118, 84], [124, 72], [128, 90]], "#fff4d0"),
	];
	return [
		shadow(210, 70, 10),
		can.svg,
		poly([up(A, 30), up(C, 30), up(C, 40), up(A, 40)], acc.d),
		poly([up(A, 30), up(B, 30), up(B, 40), up(A, 40)], mix(acc.d, "#000000", 0.3)),
		poly([spoutBase, add(spoutBase, R, 14), up(add(spoutBase, R, 14), 10), up(spoutBase, 10)], P.gun.d),
		...flame,
	].join("\n");
};

// 11. Repulsor Mine Kit — disc mine with blue pulse
ICONS.repulsor_mine_kit = (acc) => {
	return [
		shadow(206, 92, 10),
		`<ellipse cx="128" cy="158" rx="104" ry="36" fill="none" stroke="${acc.m}" stroke-width="4" opacity="0.35"/>`,
		`<ellipse cx="128" cy="158" rx="90" ry="30" fill="none" stroke="${acc.m}" stroke-width="5" opacity="0.7"/>`,
		facetEllipse(128, 176, 72, 24, P.gun.d, 14),
		rect(56, 158, 144, 18, P.gun.d),
		poly([[56, 158], [56, 176], [128, 200], [128, 182]], P.gun.m),
		facetEllipse(128, 158, 72, 24, P.gun.l, 14),
		facetEllipse(128, 158, 54, 18, P.gun.m, 14),
		facetEllipse(128, 152, 26, 10, acc.d, 10),
		rect(102, 142, 52, 10, acc.d),
		facetEllipse(128, 142, 26, 10, acc.m, 10),
		facetEllipse(128, 142, 12, 5, acc.l, 8),
		line([[108, 142], [92, 110]], P.dark.l, 5),
		line([[148, 142], [164, 110]], P.dark.l, 5),
		line([[128, 138], [128, 100]], P.dark.l, 5),
	].join("\n");
};

// 12. Shock Coil — tesla coil with arcs
ICONS.shock_coil = (acc) => {
	const base = isoBox(114, 208, 84, 52, 22, P.dark);
	return [
		shadow(212, 84, 10),
		base.svg,
		cylinder(108, 96, 40, 92, P.gun),
		rect(108, 112, 40, 6, P.dark.d),
		rect(108, 132, 40, 6, P.dark.d),
		rect(108, 152, 40, 6, P.dark.d),
		rect(108, 172, 40, 6, P.dark.d),
		facetEllipse(128, 92, 44, 16, P.gun.d, 12),
		facetEllipse(128, 86, 44, 16, P.gun.m, 12),
		facetEllipse(128, 84, 30, 10, P.gun.l, 12),
		facetEllipse(128, 66, 14, 14, acc.m, 8, Math.PI / 8),
		facetEllipse(124, 62, 6, 6, acc.l, 6),
		line([[116, 60], [92, 54], [80, 36], [56, 30]], acc.l, 5),
		line([[140, 60], [166, 50], [172, 32], [200, 26]], acc.l, 5),
		line([[142, 70], [176, 78], [190, 66], [214, 72]], acc.m, 4, 'opacity="0.8"'),
		line([[114, 72], [84, 84], [66, 76]], acc.m, 4, 'opacity="0.8"'),
	].join("\n");
};

// 13. Hunter's Mark Optics — rifle scope with a red glowing objective
ICONS.hunters_mark_optics = (acc) => {
	return [
		shadow(206, 92, 10),
		rect(94, 150, 16, 30, P.dark.m),
		rect(150, 150, 16, 30, P.dark.m),
		rect(70, 176, 120, 12, P.dark.d),
		rect(70, 176, 120, 4, P.dark.l),
		rect(62, 108, 132, 12, P.gun.l),
		rect(62, 120, 132, 20, P.gun.m),
		rect(62, 140, 132, 12, P.gun.d),
		rect(116, 88, 26, 22, P.dark.m),
		rect(116, 88, 26, 6, P.dark.l),
		rect(120, 82, 18, 8, P.dark.d),
		rect(190, 100, 26, 60, P.gun.m),
		rect(190, 100, 26, 14, P.gun.l),
		rect(190, 146, 26, 14, P.gun.d),
		rect(216, 104, 8, 52, P.dark.m),
		rect(44, 96, 30, 68, P.gun.m),
		rect(44, 96, 30, 16, P.gun.l),
		rect(44, 148, 30, 16, P.gun.d),
		facetEllipse(42, 130, 10, 34, acc.d, 10),
		facetEllipse(42, 130, 7, 26, acc.m, 10),
		facetEllipse(42, 118, 3, 8, acc.l, 6),
		poly([[128, 56], [150, 76], [128, 70], [106, 76]], acc.m),
		poly([[128, 56], [128, 70], [106, 76]], acc.l),
	].join("\n");
};

// 14. Plague Rat Charm — rat silhouette on a cord with a green tag
ICONS.plague_rat_charm = (acc) => {
	return [
		shadow(208, 84, 10),
		// cord loop the tag hangs from
		line([[110, 130], [98, 72], [128, 50], [158, 72], [146, 130]], P.tan.d, 5),
		line([[196, 196], [224, 182], [222, 158]], P.gun.m, 7),
		poly([[60, 190], [70, 148], [100, 132], [134, 128], [168, 136], [196, 162], [200, 196], [128, 196]], P.gun.m),
		poly([[128, 128], [168, 136], [196, 162], [200, 196], [128, 196]], P.gun.d),
		poly([[70, 148], [100, 132], [134, 128], [128, 150], [96, 158]], P.gun.l),
		poly([[60, 190], [34, 174], [38, 162], [70, 148]], P.gun.m),
		poly([[34, 174], [26, 172], [38, 162]], P.red.m),
		poly([[76, 146], [80, 124], [96, 134]], P.gun.l),
		poly([[82, 142], [84, 130], [92, 136]], P.red.d),
		poly([[54, 160], [62, 158], [60, 166]], acc.l),
		rect(96, 192, 10, 14, P.gun.d),
		rect(160, 192, 10, 14, P.gun.d),
		poly([[108, 128], [148, 128], [152, 160], [104, 160]], acc.m),
		poly([[108, 128], [148, 128], [148, 136], [108, 136]], acc.l),
		circle(128, 132, 3, P.dark.d),
	].join("\n");
};

// 15. High-Grain Powder — powder can with spilled grains
ICONS.high_grain_powder = (acc) => {
	return [
		shadow(208, 80, 10),
		cylinder(84, 72, 80, 128, P.dark),
		rect(84, 110, 14, 44, P.brass.l),
		rect(98, 110, 34, 44, P.brass.m),
		rect(132, 110, 32, 44, P.brass.d),
		rect(104, 122, 22, 6, P.dark.m),
		rect(104, 134, 30, 6, P.dark.m),
		facetEllipse(124, 72, 40, 10, P.gun.m, 12),
		facetEllipse(124, 68, 32, 8, P.gun.l, 12),
		...[[178, 190], [192, 198], [204, 188], [186, 204], [200, 206], [212, 200], [174, 204]].map(([x, y], i) =>
			poly([[x, y - 6], [x + 6, y], [x, y + 6], [x - 6, y]], i % 2 ? acc.m : acc.l)
		),
		poly([[160, 208], [184, 180], [214, 208]], acc.d),
	].join("\n");
};

// 16. Combat Stimulants — pill bottle + capsules
ICONS.combat_stimulants = (acc) => {
	const capsule = (x, y, r) =>
		g(
			[
				rect(-26, -10, 26, 20, P.white.m),
				rect(0, -10, 26, 20, acc.m),
				rect(-26, -10, 52, 5, P.white.l),
				rect(-26, 5, 26, 5, P.white.d),
				rect(0, 5, 26, 5, acc.d),
				facetEllipse(-26, 0, 10, 10, P.white.m, 8),
				facetEllipse(26, 0, 10, 10, acc.m, 8),
			],
			`transform="translate(${x} ${y}) rotate(${r})"`
		);
	return [
		shadow(208, 80, 10),
		cylinder(90, 92, 68, 104, P.white),
		rect(96, 118, 56, 44, P.dark.m),
		rect(96, 118, 10, 44, P.dark.l),
		poly(
			[[124, 128], [132, 128], [132, 136], [140, 136], [140, 144], [132, 144], [132, 152], [124, 152], [124, 144], [116, 144], [116, 136], [124, 136]],
			acc.l
		),
		rect(86, 70, 76, 24, acc.m),
		rect(86, 70, 14, 24, acc.l),
		rect(148, 70, 14, 24, acc.d),
		facetEllipse(124, 70, 38, 10, acc.l, 12),
		capsule(188, 184, -30),
		capsule(66, 196, 15),
	].join("\n");
};

// 17. Lightweight Boots — combat boot, speed chevrons
ICONS.lightweight_boots = (acc) => {
	return [
		shadow(208, 84, 10),
		// sole
		poly([[76, 186], [214, 186], [216, 202], [72, 202]], P.dark.m),
		poly([[76, 186], [214, 186], [214, 191], [76, 191]], P.dark.l),
		// shaft + foot (side view, toe to the right)
		poly([[92, 62], [142, 62], [146, 146], [196, 164], [214, 186], [76, 186], [76, 154], [92, 150]], P.olive.m),
		poly([[92, 62], [112, 62], [112, 150], [96, 154], [76, 154], [92, 150]], P.olive.l),
		poly([[146, 146], [196, 164], [214, 186], [150, 186]], P.olive.d),
		// toe cap + heel counter
		poly([[164, 186], [214, 186], [196, 164], [176, 160]], P.dark.l),
		poly([[76, 154], [96, 154], [100, 186], [76, 186]], P.dark.m),
		// collar
		rect(90, 58, 54, 10, P.dark.m),
		// laces
		...[0, 1, 2, 3].map((i) => line([[110, 82 + i * 16], [134, 78 + i * 16]], acc.l, 4)),
		...[0, 1, 2, 3].map((i) => line([[110, 78 + i * 16], [134, 82 + i * 16]], acc.m, 4)),
		// speed chevrons
		poly([[44, 96], [62, 96], [50, 114], [62, 132], [44, 132], [32, 114]], acc.m),
		poly([[26, 104], [38, 104], [32, 114], [38, 124], [26, 124], [20, 114]], acc.d),
	].join("\n");
};

// 18. Military Rations — MRE pouch
ICONS.military_rations = (acc) => {
	return [
		shadow(210, 72, 10),
		poly([[86, 60], [128, 56], [128, 204], [80, 200]], P.tan.l),
		poly([[128, 56], [170, 60], [176, 200], [128, 204]], P.tan.m),
		poly([[86, 60], [170, 60], [170, 74], [86, 72]], P.tan.d),
		rect(82, 52, 92, 10, P.tan.d),
		poly([[82, 66], [90, 70], [82, 74]], P.plate),
		poly([[96, 96], [160, 96], [162, 150], [94, 148]], P.dark.m),
		rect(104, 106, 32, 6, P.white.d),
		rect(104, 118, 44, 6, P.white.d),
		rect(104, 130, 24, 6, P.white.d),
		poly([[80, 164], [176, 164], [176, 176], [80, 176]], acc.m),
		poly([[80, 164], [176, 164], [176, 168], [80, 168]], acc.l),
	].join("\n");
};

// 19. Field Manual — closed book, iso
ICONS.field_manual = (acc) => {
	const A = [96, 196];
	const w = 84,
		d = 100,
		h = 30;
	const B = add(A, R, w),
		C = add(A, L, d);
	const pagesL = poly([A, C, up(C, h - 6), up(A, h - 6)], P.white.m);
	const pagesR = poly([A, B, up(B, h - 6), up(A, h - 6)], P.white.d);
	const pageLines = [10, 15, 20].map((k) => poly([up(A, k), up(B, k), up(B, k + 1.5), up(A, k + 1.5)], P.white.l));
	const cA = [A[0] - 4, A[1] - (h - 6)],
		cB = add(cA, R, w + 4),
		cC = add(cA, L, d + 4),
		cD = add(cB, L, d + 4);
	const cover = [
		poly([cA, cB, up(cB, 6), up(cA, 6)], P.olive.d),
		poly([cA, cC, up(cC, 6), up(cA, 6)], P.olive.m),
		poly([up(cA, 6), up(cB, 6), up(cD, 6), up(cC, 6)], P.olive.l),
	];
	const t0 = add(add(up(cA, 6), R, 16), L, 20);
	const stripe = poly([t0, add(t0, R, 60), add(add(t0, R, 60), L, 14), add(t0, L, 14)], acc.m);
	const t1 = add(add(up(cA, 6), R, 16), L, 44);
	const stripe2 = poly([t1, add(t1, R, 36), add(add(t1, R, 36), L, 8), add(t1, L, 8)], P.white.l);
	const t2 = add(add(up(cA, 6), R, 16), L, 60);
	const stripe3 = poly([t2, add(t2, R, 50), add(add(t2, R, 50), L, 8), add(t2, L, 8)], P.white.l, 'opacity="0.7"');
	const ribbon = poly(
		[
			add(up(cB, 6), L, 30),
			add(up(cB, 6), L, 40),
			add(add(cB, [0, 1], 28), L, 40),
			add(add(cB, [0, 1], 22), L, 35),
			add(add(cB, [0, 1], 28), L, 30),
		],
		acc.l
	);
	return [shadow(206, 96, 12), pagesL, pagesR, ...pageLines, ...cover, stripe, stripe2, stripe3, ribbon].join("\n");
};

// 20. Scavenger Pouch — dump pouch with drawstring
ICONS.scavenger_pouch = (acc) => {
	return [
		shadow(210, 80, 10),
		poly([[92, 96], [128, 100], [128, 204], [72, 196], [66, 130]], P.olive.m),
		poly([[128, 100], [166, 96], [190, 130], [184, 196], [128, 204]], P.olive.d),
		poly([[92, 96], [128, 100], [128, 130], [90, 128], [66, 130]], P.olive.l),
		poly([[88, 74], [168, 74], [172, 100], [84, 100]], P.dark.m),
		poly([[88, 74], [168, 74], [168, 82], [88, 82]], P.dark.l),
		line([[100, 86], [100, 120], [80, 150]], acc.m, 4),
		poly([[72, 148], [88, 148], [84, 166], [76, 166]], acc.m),
		rect(74, 164, 110, 5, P.olive.d),
		rect(118, 60, 10, 20, P.brass.m),
		rect(134, 56, 10, 24, P.brass.l),
		poly([[150, 60], [164, 56], [166, 76], [152, 78]], P.white.m),
		poly([[160, 100], [176, 100], [188, 128], [172, 128]], acc.d),
	].join("\n");
};

// 21. Ballistic Weave — woven fabric swatch
ICONS.ballistic_weave = (acc) => {
	const swatch = [[64, 56], [196, 48], [204, 196], [56, 204]];
	// point-in-convex-quad test (resvg panics on clipPath'd groups, so clip by hand)
	const inside = ([x, y]) => {
		for (let i = 0; i < 4; i++) {
			const [ax, ay] = swatch[i];
			const [bx, by] = swatch[(i + 1) % 4];
			if ((bx - ax) * (y - ay) - (by - ay) * (x - ax) < 0) return false;
		}
		return true;
	};
	const weave = [];
	const step = 20;
	for (let row = 0; row < 12; row++) {
		for (let col = 0; col < 12; col++) {
			const cx = 40 + col * step + (row % 2) * (step / 2);
			const cy = 40 + row * (step / 2);
			const dia = [[cx, cy - step / 2], [cx + step / 2, cy], [cx, cy + step / 2], [cx - step / 2, cy]];
			if (dia.every(inside)) weave.push(poly(dia, (row + col) % 2 ? P.gun.d : P.gun.m));
		}
	}
	return [
		shadow(208, 84, 10),
		poly(swatch, P.dark.m),
		...weave,
		`<polygon points="${pts(swatch)}" fill="none" stroke="${acc.m}" stroke-width="6" stroke-dasharray="14 10" stroke-linejoin="round"/>`,
		poly([[160, 160], [204, 156], [204, 196], [164, 198]], acc.m),
		poly([[160, 160], [204, 156], [204, 164], [160, 168]], acc.l),
		rect(172, 176, 22, 5, P.dark.d),
		rect(172, 184, 14, 5, P.dark.d),
	].join("\n");
};

// 22. Field Dressing — bandage roll + strip
ICONS.field_dressing = (acc) => {
	return [
		shadow(208, 90, 10),
		poly([[96, 96], [212, 104], [212, 176], [96, 180]], P.white.m),
		poly([[96, 96], [212, 104], [212, 118], [96, 110]], P.white.l),
		poly([[96, 166], [212, 162], [212, 176], [96, 180]], P.white.d),
		...[0, 1, 2, 3].map((i) => rect(130 + i * 20, 118, 6, 38, P.white.d, 'opacity="0.6"')),
		poly(
			[[164, 126], [176, 126], [176, 134], [184, 134], [184, 146], [176, 146], [176, 154], [164, 154], [164, 146], [156, 146], [156, 134], [164, 134]],
			acc.m
		),
		facetEllipse(96, 138, 50, 50, P.white.d, 14),
		facetEllipse(92, 134, 44, 44, P.white.m, 14),
		facetEllipse(86, 128, 34, 34, P.white.l, 12),
		facetEllipse(96, 138, 24, 24, P.white.d, 10),
		facetEllipse(96, 138, 12, 12, P.dark.m, 8),
		poly([[46, 150], [96, 150], [96, 164], [50, 166]], acc.m),
	].join("\n");
};

// 23. Signal Antenna — whip antenna on a field base
ICONS.signal_antenna = (acc) => {
	const base = isoBox(120, 208, 60, 42, 30, P.dark);
	const ind =[add(base.A, L, 10), add(base.A, L, 20), up(add(base.A, L, 20), 14), up(add(base.A, L, 10), 14)].map((p) => up(p, 8));
	return [
		shadow(212, 72, 10),
		base.svg,
		rect(122, 60, 6, 120, P.gun.l),
		rect(128, 60, 6, 120, P.gun.d),
		rect(116, 150, 24, 20, P.gun.m),
		rect(116, 150, 24, 5, P.gun.l),
		poly([[125, 60], [131, 60], [128, 40]], acc.m),
		facetEllipse(128, 60, 8, 8, acc.m, 8),
		facetEllipse(126, 58, 3, 3, acc.l, 6),
		line([[96, 72], [100, 52], [112, 40]], acc.m, 6),
		line([[160, 72], [156, 52], [144, 40]], acc.m, 6),
		line([[72, 84], [78, 50], [100, 26]], acc.m, 6, 'opacity="0.6"'),
		line([[184, 84], [178, 50], [156, 26]], acc.m, 6, 'opacity="0.6"'),
		line([[48, 96], [58, 46], [88, 14]], acc.m, 6, 'opacity="0.3"'),
		line([[208, 96], [198, 46], [168, 14]], acc.m, 6, 'opacity="0.3"'),
		poly(ind, acc.l),
	].join("\n");
};

// 24. Cheap Drone Parts — rotor arm, loose prop, taped battery
ICONS.cheap_drone_parts = (acc) => {
	const propBlade = (x, y, r, len) =>
		g(
			[
				poly(
					[[-len, 0], [-len * 0.5, -9], [0, -4], [len * 0.5, -9], [len, 0], [len * 0.5, 9], [0, 4], [-len * 0.5, 9]],
					P.gun.m
				),
				poly([[-len, 0], [-len * 0.5, -9], [0, -4], [0, 4], [-len * 0.5, 9]], P.gun.l),
			],
			`transform="translate(${x} ${y}) rotate(${r})"`
		);
	const b = isoBox(72, 196, 62, 30, 28, P.dark);
	const t0 = add(b.A, R, 24);
	const top = up(b.A, 28);
	const battery = [
		b.svg,
		poly([t0, add(t0, R, 14), up(add(t0, R, 14), 28), up(t0, 28)], acc.m),
		poly([add(top, R, 24), add(top, R, 38), add(add(top, R, 38), L, 30), add(add(top, R, 24), L, 30)], acc.l),
		poly([add(top, L, 8), add(top, L, 22), up(add(top, L, 22), 6), up(add(top, L, 8), 6)], P.red.m),
	];
	return [
		shadow(210, 88, 10),
		g(
			[rect(-58, -9, 116, 18, P.dark.m), rect(-58, -9, 116, 6, P.dark.l), rect(-58, 3, 116, 6, P.dark.d)],
			'transform="translate(122 140) rotate(-28)"'
		),
		facetEllipse(170, 118, 22, 22, P.dark.d, 10),
		facetEllipse(170, 112, 22, 22, P.dark.m, 10),
		facetEllipse(170, 110, 12, 12, P.gun.l, 8),
		propBlade(170, 108, -18, 62),
		propBlade(78, 72, 30, 50),
		...battery,
		facetEllipse(206, 196, 6, 6, P.gun.l, 6),
		facetEllipse(220, 184, 6, 6, P.gun.m, 6),
	].join("\n");
};

// ---------------------------------------------------------------- accent colors
// The 24 shipped icons are named after the old items, whose Color lived in ItemDefinitions.luau
// (deleted in the Sprint 18 loadout rework, commit c4ba1d7). Their accents are frozen here so a
// rebuild reproduces the uploaded art; call-ins and cards reuse those uploads by image id.
const LEGACY_ACCENTS = {
	hollow_point_rounds: [196, 58, 44],
	adrenaline_injector: [70, 214, 140],
	tactical_drone_beacon: [63, 167, 214],
	emergency_ammo_cache: [125, 140, 88],
	air_support_authorization: [214, 69, 51],
	kevlar_plate_carrier: [78, 132, 196],
	vampire_serum: [176, 38, 52],
	ricochet_rounds: [120, 200, 210],
	shrapnel_magazine: [190, 150, 70],
	incendiary_gel: [232, 120, 40],
	repulsor_mine_kit: [96, 150, 220],
	shock_coil: [120, 180, 255],
	hunters_mark_optics: [220, 60, 60],
	plague_rat_charm: [120, 170, 70],
	high_grain_powder: [200, 120, 60],
	combat_stimulants: [120, 200, 180],
	lightweight_boots: [150, 170, 110],
	military_rations: [180, 150, 90],
	field_manual: [110, 160, 210],
	scavenger_pouch: [150, 200, 120],
	ballistic_weave: [120, 130, 150],
	field_dressing: [210, 130, 130],
	signal_antenna: [130, 180, 220],
	cheap_drone_parts: [90, 160, 200],
};

// A new icon is named after its call-in or card id and takes that row's Color.
const DEFINITION_FILES = ["CallInDefinitions.luau", "UpgradeDefinitions.luau"];

function readAccents() {
	const out = {};
	for (const [id, [r, g, b]] of Object.entries(LEGACY_ACCENTS)) out[id] = rgbToHex(r, g, b);
	for (const file of DEFINITION_FILES) {
		const src = fs.readFileSync(path.join(__dirname, "..", "..", "..", "src", "shared", file), "utf8");
		// Named colors such as `local SUPPLY = Color3.fromRGB(...)`, used as `Color = SUPPLY`.
		const named = {};
		const constRe = /local ([A-Z_]+) = Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)/g;
		let m;
		while ((m = constRe.exec(src))) named[m[1]] = rgbToHex(+m[2], +m[3], +m[4]);
		// Each row from its Id up to the next Id, so a row never takes its neighbour's Color.
		const rows = src.split(/(?<![A-Za-z])(?=Id = ")/);
		for (const row of rows) {
			const id = /^Id = "([a-z_]+)"/.exec(row);
			if (!id) continue;
			const rgb = /Color = Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)/.exec(row);
			const ref = /Color = ([A-Z_]+)\b/.exec(row);
			if (rgb) out[id[1]] = rgbToHex(+rgb[1], +rgb[2], +rgb[3]);
			else if (ref && named[ref[1]]) out[id[1]] = named[ref[1]];
		}
	}
	return out;
}

// ---------------------------------------------------------------- main
function main() {
	const args = process.argv.slice(2);
	const wantSheet = args.includes("sheet");
	const ids = args.filter((a) => a !== "sheet");
	const accents = readAccents();
	const todo = ids.length ? ids : Object.keys(ICONS);
	const rendered = [];
	for (const id of todo) {
		if (!ICONS[id]) throw new Error("unknown icon " + id);
		if (!accents[id]) throw new Error("no accent color for " + id + " (LEGACY_ACCENTS or a definition row)");
		const svg = wrap(ICONS[id](tone(accents[id])));
		fs.writeFileSync(path.join(OUT, id + ".svg"), svg);
		if (Resvg) {
			const png = new Resvg(svg, { fitTo: { mode: "width", value: SIZE } }).render().asPng();
			fs.writeFileSync(path.join(OUT, id + ".png"), png);
		}
		rendered.push(id);
		console.log("ok " + id);
	}
	if (wantSheet && Resvg) {
		const cols = 6;
		const cell = 128;
		const all = Object.keys(ICONS);
		const rows = Math.ceil(all.length / cols);
		const parts = all.map((id, i) => {
			const svg = fs.readFileSync(path.join(OUT, id + ".svg"), "utf8");
			const inner = svg
				.replace(/^[\s\S]*?<svg[^>]*>/, "")
				.replace(/<\/svg>\s*$/, "")
				.replace(/id="(plateClip|swatch)"/g, `id="$1_${i}"`)
				.replace(/url\(#(plateClip|swatch)\)/g, `url(#$1_${i})`);
			const x = (i % cols) * cell + 8;
			const y = Math.floor(i / cols) * cell + 8;
			return `<g transform="translate(${x} ${y}) scale(${(cell - 16) / SIZE})">${inner}</g>`;
		});
		const sheet = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${cols * cell} ${rows * cell}"><rect width="100%" height="100%" fill="#2a2e35"/>${parts.join("")}</svg>`;
		const png = new Resvg(sheet, { fitTo: { mode: "width", value: cols * cell * 2 } }).render().asPng();
		fs.writeFileSync(path.join(__dirname, "contact_sheet.png"), png);
		console.log("sheet written");
	}
	console.log(`DONE ${rendered.length} icons${Resvg ? "" : " (svg only, resvg missing)"}`);
}

main();
