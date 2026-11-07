// Upload rendered icon PNGs to Roblox via Open Cloud (Decal assets).
//   node assets/icons/build/upload.js [<id> ...]     (default: every icon in icons.js)
// Appends results to build/uploaded_ids.json  { id: { decalId, imageId, uploadedAt } }.
// The API key is read from ROBLOX_OPEN_CLOUD_API_KEY, or from the robloxstudio MCP entry in
// ~/.claude.json. It is held in memory only and never printed. Needs asset:read + asset:write.

const fs = require("fs");
const path = require("path");
const os = require("os");

const DIR = path.join(__dirname, "..");
const IDS_FILE = path.join(__dirname, "uploaded_ids.json");

function loadKey() {
	if (process.env.ROBLOX_OPEN_CLOUD_API_KEY) {
		return { key: process.env.ROBLOX_OPEN_CLOUD_API_KEY, user: process.env.ROBLOX_CREATOR_USER_ID || "67169996" };
	}
	const cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".claude.json"), "utf8"));
	const env = (cfg.mcpServers && cfg.mcpServers.robloxstudio && cfg.mcpServers.robloxstudio.env) || {};
	if (!env.ROBLOX_OPEN_CLOUD_API_KEY) throw new Error("no ROBLOX_OPEN_CLOUD_API_KEY in env or ~/.claude.json");
	return { key: env.ROBLOX_OPEN_CLOUD_API_KEY, user: env.ROBLOX_CREATOR_USER_ID || "67169996" };
}

function allIconIds() {
	const src = fs.readFileSync(path.join(__dirname, "icons.js"), "utf8");
	return [...src.matchAll(/^ICONS\.([a-z_]+) = /gm)].map((m) => m[1]);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const scrub = (s, key) => String(s).split(key).join("<key>");

async function pollOperation(key, opPath) {
	for (let i = 0; i < 40; i++) {
		const res = await fetch("https://apis.roblox.com/assets/v1/" + opPath, { headers: { "x-api-key": key } });
		const body = await res.json().catch(() => ({}));
		if (body.done) return body;
		await sleep(1000);
	}
	throw new Error("operation timed out: " + opPath);
}

// A Decal asset wraps an Image asset; IconId must use the image id.
async function imageIdForDecal(decalId) {
	const res = await fetch(`https://assetdelivery.roblox.com/v1/asset/?id=${decalId}`);
	const txt = await res.text();
	const m = txt.match(/rbxassetid:\/\/(\d+)|\?id=(\d+)/);
	return m ? m[1] || m[2] : null;
}

async function upload(auth, id) {
	const file = path.join(DIR, id + ".png");
	if (!fs.existsSync(file)) throw new Error("missing " + file + " (run icons.js first)");
	const form = new FormData();
	form.append(
		"request",
		JSON.stringify({
			assetType: "Decal",
			displayName: "icon_" + id,
			description: "Infected Co-op Shooter item icon",
			creationContext: { creator: { userId: auth.user } },
		})
	);
	form.append("fileContent", new Blob([fs.readFileSync(file)], { type: "image/png" }), id + ".png");
	const res = await fetch("https://apis.roblox.com/assets/v1/assets", {
		method: "POST",
		headers: { "x-api-key": auth.key },
		body: form,
	});
	const body = await res.json().catch(() => ({}));
	if (!res.ok) throw new Error(`HTTP ${res.status}: ${scrub(JSON.stringify(body), auth.key)}`);
	const op = await pollOperation(auth.key, body.path);
	if (op.error) throw new Error("operation error: " + scrub(JSON.stringify(op.error), auth.key));
	const decalId = op.response && op.response.assetId;
	if (!decalId) throw new Error("upload finished without an assetId: " + scrub(JSON.stringify(op), auth.key));
	// assetdelivery needs auth for fresh assets; when this returns null, resolve in Studio with
	// game:GetObjects("rbxassetid://<decalId>")[1].Texture and fill imageId in uploaded_ids.json.
	const imageId = await imageIdForDecal(decalId).catch(() => null);
	return { decalId, imageId };
}

(async () => {
	const auth = loadKey();
	const ids = process.argv.slice(2).length ? process.argv.slice(2) : allIconIds();
	const results = fs.existsSync(IDS_FILE) ? JSON.parse(fs.readFileSync(IDS_FILE, "utf8")) : {};
	let failed = 0;
	for (const id of ids) {
		try {
			const r = await upload(auth, id);
			results[id] = { ...r, uploadedAt: new Date().toISOString() };
			fs.writeFileSync(IDS_FILE, JSON.stringify(results, null, 2) + "\n");
			console.log(`${id} decal=${r.decalId} image=${r.imageId}`);
		} catch (e) {
			failed++;
			console.log(`${id} ERROR ${scrub(e.message, auth.key)}`);
		}
	}
	console.log(`DONE ${ids.length - failed}/${ids.length} uploaded -> ${path.relative(process.cwd(), IDS_FILE)}`);
	process.exit(failed ? 1 : 0);
})();
