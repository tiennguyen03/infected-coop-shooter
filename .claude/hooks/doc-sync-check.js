// PreToolUse hook (Bash). Blocks `git commit` when code/assets are staged but no
// documentation is. Exit 2 = block (stderr goes back to Claude). Exit 0 = allow.
// Bypass: put [no-docs] in the commit message (for pure fixups / WIP).
const { execSync } = require("child_process");

let input = "";
try {
	input = require("fs").readFileSync(0, "utf8");
} catch (_) {}
let command = "";
try {
	command = JSON.parse(input).tool_input?.command || "";
} catch (_) {}

if (!/\bgit\s+commit\b/.test(command) || /\[no-docs\]/.test(command)) process.exit(0);

let staged = [];
try {
	staged = execSync("git diff --cached --name-only", { encoding: "utf8" }).split(/\r?\n/).filter(Boolean);
} catch (_) {
	process.exit(0);
}
// `git commit -a` / `git commit <paths>` stage at commit time: include unstaged tracked changes then.
if (/\s-a\b|\s--all\b/.test(command)) {
	try {
		staged.push(...execSync("git diff --name-only", { encoding: "utf8" }).split(/\r?\n/).filter(Boolean));
	} catch (_) {}
}

const isCode = (f) => /^(src\/|assets\/|default\.project\.json|rokit\.toml)/.test(f) && !/\.md$/.test(f);
const isDoc = (f) => /^(CLAUDE\.md|handoff\/|docs\/)/.test(f) || /\.md$/.test(f);

const code = staged.filter(isCode);
const docs = staged.filter(isDoc);
if (code.length && !docs.length) {
	process.stderr.write(
		[
			"doc-sync: code/assets are staged but no documentation is.",
			"Update and stage the matching docs before committing (see CLAUDE.md > Doc-sync):",
			"  - handoff/README.md   (current state / open work — replace stale lines, don't append)",
			"  - docs/HISTORY.md     (one line per shipped sprint or feature)",
			"  - the feature's own doc under docs/ or assets/*/README.md, docs/STYLES.md for visuals",
			"Staged code: " + code.slice(0, 8).join(", ") + (code.length > 8 ? ", ..." : ""),
			"Bypass for pure fixups: add [no-docs] to the commit message.",
		].join("\n") + "\n"
	);
	process.exit(2);
}
process.exit(0);
