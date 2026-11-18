// Upload exported FBX meshes to Roblox via Open Cloud as Model assets owned by the group
// Boomin Dev Studios (270506601), without Studio.
//   node assets/3d/build/upload_models.js <name> ...      (assets/3d/export/<name>.fbx)
// Appends results to build/carrier_uploaded.json  { name: { modelId, uploadedAt } }; an entry
// already there is skipped unless --force. The game loads a Model asset's MeshPart with
// InsertService:LoadAsset (MeshAssets `modelId`), so no Studio step reads a MeshId.
// The API key is read from ROBLOX_OPEN_CLOUD_API_KEY, or from the robloxstudio MCP entry in
// ~/.claude.json. It is held in memory only and never printed. Needs asset:read + asset:write
// for the group.

const fs = require("fs");
const path = require("path");
const os = require("os");

const GROUP_ID = "270506601";
const EXPORT = path.join(__dirname, "..", "export");
const IDS_FILE = path.join(__dirname, "carrier_uploaded.json");

function loadKey() {
	if (process.env.ROBLOX_OPEN_CLOUD_API_KEY) return process.env.ROBLOX_OPEN_CLOUD_API_KEY;
	const cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".claude.json"), "utf8"));
	const env = (cfg.mcpServers && cfg.mcpServers.robloxstudio && cfg.mcpServers.robloxstudio.env) || {};
	if (!env.ROBLOX_OPEN_CLOUD_API_KEY) throw new Error("no ROBLOX_OPEN_CLOUD_API_KEY in env or ~/.claude.json");
	return env.ROBLOX_OPEN_CLOUD_API_KEY;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const scrub = (s, key) => String(s).split(key).join("<key>");

async function pollOperation(key, opPath) {
	for (let i = 0; i < 90; i++) {
		const res = await fetch("https://apis.roblox.com/assets/v1/" + opPath, { headers: { "x-api-key": key } });
		const body = await res.json().catch(() => ({}));
		if (body.done) return body;
		await sleep(1000);
	}
	throw new Error("operation timed out: " + opPath);
}

async function upload(key, name) {
	const file = path.join(EXPORT, name + ".fbx");
	if (!fs.existsSync(file)) throw new Error("missing " + file + " (run build_assets.py first)");
	const form = new FormData();
	form.append(
		"request",
		JSON.stringify({
			assetType: "Model",
			displayName: name,
			description: "Infected Co-op Shooter: Carrier v2 kit mesh (assets/3d/build/carrier_kit.py)",
			creationContext: { creator: { groupId: GROUP_ID } },
		})
	);
	form.append("fileContent", new Blob([fs.readFileSync(file)], { type: "model/fbx" }), name + ".fbx");
	for (let attempt = 0; attempt < 4; attempt++) {
		const res = await fetch("https://apis.roblox.com/assets/v1/assets", {
			method: "POST",
			headers: { "x-api-key": key },
			body: form,
		});
		const body = await res.json().catch(() => ({}));
		if (res.status === 429) {
			await sleep(5000 * (attempt + 1));
			continue;
		}
		if (!res.ok) throw new Error(`HTTP ${res.status}: ${scrub(JSON.stringify(body), key)}`);
		const op = await pollOperation(key, body.path);
		if (op.error) throw new Error("operation error: " + scrub(JSON.stringify(op.error), key));
		const modelId = op.response && op.response.assetId;
		if (!modelId) throw new Error("upload finished without an assetId: " + scrub(JSON.stringify(op), key));
		return Number(modelId);
	}
	throw new Error("rate limited four times");
}

(async () => {
	const key = loadKey();
	const force = process.argv.includes("--force");
	const names = process.argv.slice(2).filter((a) => !a.startsWith("--"));
	const results = fs.existsSync(IDS_FILE) ? JSON.parse(fs.readFileSync(IDS_FILE, "utf8")) : {};
	let failed = 0;
	for (const name of names) {
		if (results[name] && !force) {
			console.log(`${name} already uploaded: ${results[name].modelId}`);
			continue;
		}
		try {
			const modelId = await upload(key, name);
			results[name] = { modelId, uploadedAt: new Date().toISOString() };
			fs.writeFileSync(IDS_FILE, JSON.stringify(results, null, 2) + "\n");
			console.log(`${name} model=${modelId}`);
		} catch (e) {
			failed++;
			console.log(`${name} ERROR ${scrub(e.message, key)}`);
		}
	}
	console.log(`DONE ${names.length - failed}/${names.length} -> ${path.relative(process.cwd(), IDS_FILE)}`);
	process.exit(failed ? 1 : 0);
})();
