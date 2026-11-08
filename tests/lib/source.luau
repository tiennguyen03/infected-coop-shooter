-- Reads every .luau file under src/ as text, for tests that check references between
-- files (remote names, upgrade ids, require paths) without running Roblox code.

local fs = require("@lune/fs")

local Source = {}

export type File = { path: string, dir: string, name: string, text: string }

local files: { File }? = nil

local function walk(dir: string, out: { File })
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, { path = path, dir = dir, name = name, text = fs.readFile(path) })
		end
	end
end

function Source.files(): { File }
	if not files then
		local out = {}
		walk("src", out)
		files = out
	end
	return files :: { File }
end

function Source.exists(path: string): boolean
	return fs.isFile(path) or fs.isDir(path)
end

function Source.read(path: string): string
	return fs.readFile(path)
end

return Source
