// Upload one generated .wav to Roblox via Open Cloud as an Audio asset owned by the group
// Boomin Dev Studios (270506601), without Studio:
//   node assets/audio/build/upload_audio.js assets/audio/warden_drone.wav "Warden fight loop"
// Prints `<file> rbxassetid://<id>`: write it where the sound is wired and in
// assets/audio/ASSET_IDS.md. Audio uploads are capped per month: one call per file you need.
// The API key is read from ROBLOX_OPEN_CLOUD_API_KEY, or from the robloxstudio MCP entry in
// ~/.claude.json (as upload_animations.js); held in memory only and never printed.

const fs = require("fs");
const path = require("path");
const os = require("os");

const GROUP_ID = "270506601";

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
	for (let i = 0; i < 120; i++) {
		const res = await fetch("https://apis.roblox.com/assets/v1/" + opPath, { headers: { "x-api-key": key } });
		const body = await res.json().catch(() => ({}));
		if (body.done) return body;
		await sleep(1000);
	}
	throw new Error("operation timed out: " + opPath);
}

async function upload(key, file, displayName) {
	if (!fs.existsSync(file)) throw new Error("missing " + file);
	const form = new FormData();
	form.append(
		"request",
		JSON.stringify({
			assetType: "Audio",
			displayName,
			description: "Infected Co-op Shooter sound (assets/audio)",
			creationContext: { creator: { groupId: GROUP_ID } },
		})
	);
	form.append("fileContent", new Blob([fs.readFileSync(file)], { type: "audio/wav" }), path.basename(file));
	const res = await fetch("https://apis.roblox.com/assets/v1/assets", {
		method: "POST",
		headers: { "x-api-key": key },
		body: form,
	});
	const body = await res.json().catch(() => ({}));
	if (!res.ok) throw new Error(`HTTP ${res.status}: ${scrub(JSON.stringify(body), key)}`);
	const op = await pollOperation(key, body.path);
	if (op.error) throw new Error("operation error: " + scrub(JSON.stringify(op.error), key));
	const id = op.response && op.response.assetId;
	if (!id) throw new Error("upload finished without an assetId: " + scrub(JSON.stringify(op), key));
	return id;
}

(async () => {
	const [file, displayName] = process.argv.slice(2);
	if (!file) {
		console.log("usage: node upload_audio.js <file.wav> [display name]");
		process.exit(2);
	}
	let key = "";
	try {
		key = loadKey();
		console.log(`${file} rbxassetid://${await upload(key, file, displayName || path.basename(file, ".wav"))}`);
	} catch (e) {
		console.log(`${file} ERROR ${scrub(e.message, key || "\u0000")}`);
		process.exit(1);
	}
})();
