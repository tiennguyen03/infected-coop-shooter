// Upload built animation clips to Roblox via Open Cloud as Animation assets owned by the
// group Boomin Dev Studios (270506601), without Studio:
//   lune run assets/animations/build/build_rbxm.luau          (writes build/out/<clip>.rbxm)
//   node assets/animations/build/upload_animations.js <clip> ...
// Prints `<clip> rbxassetid://<id>` per clip: write each into Config.Animations.Ids and
// ASSET_IDS.md. The API key is read from ROBLOX_OPEN_CLOUD_API_KEY, or from the robloxstudio
// MCP entry in ~/.claude.json; it is held in memory only and never printed. Needs asset:read
// + asset:write for the group.

const fs = require("fs");
const path = require("path");
const os = require("os");

const GROUP_ID = "270506601";
const OUT = path.join(__dirname, "out");

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
	const file = path.join(OUT, name + ".rbxm");
	if (!fs.existsSync(file)) throw new Error("missing " + file + " (run build_rbxm.luau first)");
	const form = new FormData();
	form.append(
		"request",
		JSON.stringify({
			assetType: "Animation",
			displayName: name,
			description: "Infected Co-op Shooter animation clip (assets/animations)",
			creationContext: { creator: { groupId: GROUP_ID } },
		})
	);
	form.append("fileContent", new Blob([fs.readFileSync(file)], { type: "model/x-rbxm" }), name + ".rbxm");
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
		const id = op.response && op.response.assetId;
		if (!id) throw new Error("upload finished without an assetId: " + scrub(JSON.stringify(op), key));
		return id;
	}
	throw new Error("rate limited four times");
}

(async () => {
	const key = loadKey();
	const names = process.argv.slice(2);
	let failed = 0;
	for (const name of names) {
		try {
			console.log(`${name} rbxassetid://${await upload(key, name)}`);
		} catch (e) {
			failed++;
			console.log(`${name} ERROR ${scrub(e.message, key)}`);
		}
	}
	process.exit(failed ? 1 : 0);
})();
