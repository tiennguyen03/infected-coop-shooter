#!/usr/bin/env bash
# Installs the Linux builds of the tools pinned in rokit.toml into a bin directory, for CI
# and cloud sessions where Rokit is not installed. Locally, `rokit install` does the same.
# Usage: bash scripts/install-tools.sh [bin-dir]   (default: $HOME/.local/bin)
set -euo pipefail

BIN="${1:-$HOME/.local/bin}"
mkdir -p "$BIN"

# Version of a rokit.toml entry, e.g. `rojo = "rojo-rbx/rojo@7.7.1"` -> 7.7.1.
version() {
	sed -n "s/^$1 = \"[^@]*@\(.*\)\"$/\1/p" rokit.toml
}

# fetch <url> <binary name inside the zip>
fetch() {
	local tmp
	tmp="$(mktemp -d)"
	# GitHub release downloads sometimes answer 502/504 for a while; retry for about a
	# minute before failing the build. CI caches the result, so this only runs per version.
	if ! curl -fsSL --retry 12 --retry-delay 5 --retry-all-errors -o "$tmp/tool.zip" "$1"; then
		rm -rf "$tmp"
		echo "download failed: $1" >&2
		return 1
	fi
	unzip -oq "$tmp/tool.zip" -d "$tmp"
	install -m 755 "$tmp/$2" "$BIN/$2"
	rm -rf "$tmp"
	echo "installed $2 from $1"
}

GH=https://github.com
v=$(version rojo)
fetch "$GH/rojo-rbx/rojo/releases/download/v$v/rojo-$v-linux-x86_64.zip" rojo
v=$(version StyLua)
fetch "$GH/JohnnyMorganz/StyLua/releases/download/v$v/stylua-linux-x86_64.zip" stylua
v=$(version selene)
fetch "$GH/Kampfkarren/selene/releases/download/$v/selene-$v-linux.zip" selene
v=$(version luau-lsp)
fetch "$GH/JohnnyMorganz/luau-lsp/releases/download/$v/luau-lsp-linux-x86_64.zip" luau-lsp
v=$(version lune)
# The Lune 0.8.9 release asset answered 504 for hours on 2026-11-09; build the same version
# from crates.io when the download keeps failing (a few minutes, once per cache).
if ! fetch "$GH/lune-org/lune/releases/download/v$v/lune-$v-linux-x86_64.zip" lune; then
	cargo install lune --version "$v" --locked --root "$HOME/.lune-build"
	install -m 755 "$HOME/.lune-build/bin/lune" "$BIN/lune"
	echo "built lune $v from crates.io"
fi
