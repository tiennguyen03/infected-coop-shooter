-- Loads src/shared data modules outside Roblox (Lune), with stubs for the only Roblox
-- datatypes they use (Color3.fromRGB, Vector3.new, Enum items) and a fake
-- ReplicatedStorage so `require(ReplicatedStorage.Shared.Config)` resolves to the file.
-- Only pure data modules load here; anything that touches Instances errors on purpose.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Shared = {}

local Color3 = {}
function Color3.fromRGB(r: number, g: number, b: number)
	for _, channel in { r, g, b } do
		if type(channel) ~= "number" or channel < 0 or channel > 255 then
			error(`Color3.fromRGB channel out of range: {channel}`, 2)
		end
	end
	return { kind = "Color3", R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r: number?, g: number?, b: number?)
	return { kind = "Color3", R = r or 0, G = g or 0, B = b or 0 }
end

local Vector3 = {}
function Vector3.new(x: number?, y: number?, z: number?)
	return { kind = "Vector3", X = x or 0, Y = y or 0, Z = z or 0 }
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)

local Vector2 = {}
function Vector2.new(x: number?, y: number?)
	return { kind = "Vector2", X = x or 0, Y = y or 0 }
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

local Enum = setmetatable({}, {
	__index = function(_, enumName: string)
		return setmetatable({}, {
			__index = function(_, itemName: string)
				return { kind = "EnumItem", EnumType = enumName, Name = itemName }
			end,
		})
	end,
})

local cache: { [string]: any } = {}
local loadFile: (file: string) -> any

-- Lune's fs calls yield, and a metamethod cannot yield, so the folder tree is read once
-- up front and the __index below only looks names up in it.
local function index(path: string): { [string]: any }
	local entries = {}
	for _, name in fs.readDir(path) do
		local full = `{path}/{name}`
		if fs.isDir(full) then
			entries[name] = { dir = full }
		else
			local moduleName = string.match(name, "^(.+)%.luau$")
			if moduleName then
				entries[moduleName] = { file = full }
			end
		end
	end
	return entries
end

local function folder(path: string)
	local entries = index(path)
	return setmetatable({}, {
		__index = function(_, name: string)
			local entry = entries[name]
			if entry and entry.file then
				return { __file = entry.file }
			end
			error(`no module at {path}/{name} (tests resolve modules, not folders)`, 2)
		end,
	})
end

local sharedFolder: any = nil

local game = {}
function game.GetService(_self: any, name: string)
	if name == "ReplicatedStorage" then
		return { Shared = sharedFolder }
	end
	error(`game:GetService("{name}") is not available in tests (data modules only)`, 2)
end

local function requireRef(ref: any)
	if type(ref) == "table" and type(ref.__file) == "string" then
		return loadFile(ref.__file)
	end
	error("tests can only require src/shared modules through ReplicatedStorage.Shared", 2)
end

-- The globals a data module may see: Luau builtins plus the stubs above.
local function environment()
	return {
		assert = assert,
		error = error,
		getmetatable = getmetatable,
		ipairs = ipairs,
		next = next,
		pairs = pairs,
		pcall = pcall,
		print = print,
		rawequal = rawequal,
		rawget = rawget,
		rawlen = rawlen,
		rawset = rawset,
		select = select,
		setmetatable = setmetatable,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		typeof = typeof,
		xpcall = xpcall,
		bit32 = bit32,
		coroutine = coroutine,
		math = math,
		os = os,
		string = string,
		table = table,
		utf8 = utf8,
		Color3 = Color3,
		Vector2 = Vector2,
		Vector3 = Vector3,
		Enum = Enum,
		game = game,
		require = requireRef,
	}
end

function loadFile(file: string): any
	if sharedFolder == nil then
		sharedFolder = folder("src/shared")
	end
	if cache[file] == nil then
		local env = environment()
		local chunk = luau.load(fs.readFile(file), { debugName = file, environment = env })
		pcall(setfenv, chunk, env)
		cache[file] = chunk()
	end
	return cache[file]
end

-- Shared.require("Config") loads src/shared/Config.luau.
function Shared.require(name: string): any
	return loadFile(`src/shared/{name}.luau`)
end

return Shared
