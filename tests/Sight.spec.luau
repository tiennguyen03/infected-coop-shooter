--!strict
-- Rules/Sight: the first-person sight picture. The last tests read every gun row out of
-- Config.luau itself (loaded with Lune's Roblox datatypes) and its mesh's numbers out of
-- MeshAssets.luau, so a gun cannot ship with a missing or broken view.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local ObjectiveDefinitions = require("../src/shared/ObjectiveDefinitions")
local Sight = require("../src/shared/Rules/Sight")
local expect = require("./expect")

local Vector3 = (roblox :: any).Vector3
local CFrame = (roblox :: any).CFrame

local function loadConfig(): any
	local env = {
		Vector3 = Vector3,
		Vector2 = (roblox :: any).Vector2,
		CFrame = CFrame,
		Color3 = (roblox :: any).Color3,
		UDim2 = (roblox :: any).UDim2,
		Enum = (roblox :: any).Enum,
		math = math,
		table = table,
		string = string,
		-- Config requires its one sibling, script.Parent.ObjectiveDefinitions.
		script = { Parent = { ObjectiveDefinitions = ObjectiveDefinitions } },
		require = function(module: any): any
			return module
		end,
	}
	local chunk = luau.load(
		fs.readFile("src/shared/Config.luau"),
		{ debugName = "Config", environment = env }
	)
	return chunk()
end

-- `field = Vector3.new(x, y, z)` of the mesh `name` in MeshAssets.luau.
local MESH_TEXT = fs.readFile("src/shared/MeshAssets.luau")
local function meshVector(name: string, field: string): any
	local block = string.match(MESH_TEXT, "\n\t" .. name .. " = (%b{})")
	if not block then
		error(`MeshAssets has no entry {name}`)
	end
	local x, y, z = string.match(
		block,
		"\n\t\t" .. field .. " = Vector3%.new%(([%d%.%-]+), ([%d%.%-]+), ([%d%.%-]+)%)"
	)
	if not x then
		error(`MeshAssets {name} has no {field}`)
	end
	return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
end

local Config = loadConfig()
local DEFAULTS = Config.Weapon.Sights

local RIFLE = {
	Kind = "irons",
	Hold = "long",
	Rear = Vector3.new(0, 0.6, 0),
	Front = Vector3.new(0, 0.6, -1.4),
	EyeRelief = 0.35,
	Zoom = 1.35,
}
local MUZZLE = Vector3.new(0, 0.36, -2)

local function with(changes: { [string]: any }): any
	local copy = table.clone(RIFLE) :: any
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

return {
	["a zoom of 1 keeps the hip field of view and more zoom narrows it"] = function()
		expect.near(Sight.fov(70, 1), 70, 1e-9, "1x")
		expect.near(Sight.fov(70, 1.345), 55, 0.1, "the old shared ADS view")
		-- tan(fov / 2) scales with 1 / zoom: what is seen is `zoom` times larger.
		local fov = Sight.fov(70, 6)
		expect.near(math.tan(math.rad(fov) / 2) * 6, math.tan(math.rad(35)), 1e-9, "6x")
		expect.near(fov, 13.3, 0.1, "6x in degrees")
	end,
	["the eye sits on the sight line, the relief behind the rear sight"] = function()
		local eye = Sight.eye(RIFLE.Rear, RIFLE.Front, 0.35)
		expect.near(eye.X, 0, 1e-6, "x")
		expect.near(eye.Y, 0.6, 1e-6, "y")
		expect.near(eye.Z, 0.35, 1e-6, "z")
		-- A line that is not level: still on it.
		local rear, front = Vector3.new(-0.3, 0.5, 0.1), Vector3.new(-0.3, 0.45, -0.7)
		local tilted = Sight.eye(rear, front, 1)
		expect.near((tilted - rear).Magnitude, 1, 1e-6, "relief")
		expect.near((tilted - rear).Unit:Dot((rear - front).Unit), 1, 1e-6, "collinear")
	end,
	["a camera on that eye sees the front sight dead centre behind the rear"] = function()
		-- What FirstPersonView does: the camera is lookAt(eye, front) in the gun's space.
		local rear, front = Vector3.new(-0.3, 0.54, -0.23), Vector3.new(-0.3, 0.5, -0.6)
		local eye = Sight.eye(rear, front, 0.3)
		local toCamera = CFrame.lookAt(eye, front):Inverse()
		local rearSeen, frontSeen = toCamera * rear, toCamera * front
		expect.near(rearSeen.X, 0, 1e-5, "rear x")
		expect.near(rearSeen.Y, 0, 1e-5, "rear y")
		expect.near(rearSeen.Z, -0.3, 1e-5, "rear ahead by the relief")
		expect.near(frontSeen.X, 0, 1e-5, "front x")
		expect.near(frontSeen.Y, 0, 1e-5, "front y")
		expect.equal(frontSeen.Z < rearSeen.Z, true, "front beyond the rear")
	end,
	["tilt is the angle between the sight line and the bore"] = function()
		expect.near(Sight.tilt(RIFLE.Rear, RIFLE.Front), 0, 1e-6, "parallel")
		expect.near(
			Sight.tilt(Vector3.new(0, 1, 0), Vector3.new(0, 0, -1)),
			45,
			1e-4,
			"45 degrees down"
		)
	end,
	["parallax: how far the bore must turn to meet the sight line at the zero"] = function()
		expect.near(Sight.parallax(1, 1), 45, 1e-6, "one stud at one stud")
		expect.equal(Sight.parallax(0.25, 100) < 0.2, true, "a rifle at 100 studs")
		expect.equal(Sight.parallax(0.25, 0), 90, "no distance")
	end,
	["the viewmodel grows only as far as the near plane needs, never past full size"] = function()
		expect.equal(Sight.viewScale(0.4, 0.1, 1, 1.25), 0.4, "far sight: the base scale")
		expect.near(Sight.viewScale(0.4, 0.1, 0.25, 1.25), 0.5, 1e-9, "close sight")
		expect.equal(Sight.viewScale(0.4, 0.5, 0.25, 1.25), 1, "a deep near plane: full size")
		expect.equal(Sight.viewScale(0.4, 0.1, 0, 1.25), 1, "no clearance")
	end,
	["irons raise and zoom together; a scope raises, then shades, then zooms"] = function()
		local raise, zoom, shade = Sight.phases(false, 0.5)
		expect.equal(raise, 0.5, "irons raise")
		expect.equal(zoom, 0.5, "irons zoom")
		expect.equal(shade, 0, "irons never shade")
		raise, zoom, shade = Sight.phases(true, 0)
		expect.equal(raise + zoom + shade, 0, "scope at the hip")
		raise, zoom, shade = Sight.phases(true, 1)
		expect.equal(raise, 1, "scope up")
		expect.equal(zoom, 1, "scope zoomed")
		expect.equal(shade, 1, "scope shaded")
		raise, zoom, shade = Sight.phases(true, 0.45)
		expect.equal(raise > 0.7, true, "the gun is nearly up")
		expect.equal(shade, 0, "before the picture")
		expect.equal(zoom, 0, "before the zoom")
		-- The picture and the zoom never run backwards.
		local lastZoom, lastShade = 0, 0
		for i = 0, 100 do
			local _, z, s = Sight.phases(true, i / 100)
			expect.equal(z >= lastZoom and s >= lastShade, true, `monotonic at {i}`)
			lastZoom, lastShade = z, s
		end
	end,
	["the blink is black as the picture arrives and clear at both ends"] = function()
		expect.equal(Sight.blink(0), 0, "hip")
		expect.equal(Sight.blink(1), 0, "scoped")
		expect.equal(Sight.blink(0.5), 1, "half way")
	end,
	["a magnified view kicks less on screen, irons kick as before"] = function()
		expect.equal(Sight.kickScale(1.35, 1.35), 1, "the standard sights")
		expect.equal(Sight.kickScale(1.15, 1.35), 1, "a pistol is not kicked harder")
		expect.near(Sight.kickScale(5.4, 1.35), 0.5, 1e-9, "4x the standard zoom")
	end,
	["a row's sight takes the defaults of its kind and hold"] = function()
		local irons = Sight.resolve({ Rear = RIFLE.Rear, Front = RIFLE.Front }, DEFAULTS)
		expect.equal(irons.Kind, "irons", "kind")
		expect.equal(irons.Hold, "long", "hold")
		expect.equal(irons.Zoom, DEFAULTS.Zoom, "zoom")
		expect.equal(irons.EyeRelief, DEFAULTS.EyeRelief.long, "relief")
		local pistol = Sight.resolve(
			{ Rear = RIFLE.Rear, Front = RIFLE.Front, Hold = "sidearm", Zoom = 1.1 },
			DEFAULTS
		)
		expect.equal(pistol.EyeRelief, DEFAULTS.EyeRelief.sidearm, "arm's length")
		expect.equal(pistol.Zoom, 1.1, "its own zoom")
		local scope =
			Sight.resolve({ Kind = "scope", Rear = RIFLE.Rear, Front = RIFLE.Front }, DEFAULTS)
		expect.equal(scope.Zoom, DEFAULTS.ScopeZoom, "scope zoom")
		expect.equal(scope.EyeRelief, DEFAULTS.ScopeRelief, "scope relief")
	end,
	["a sane sight has no problems; each broken one is named"] = function()
		expect.equal(#Sight.problems(RIFLE :: any, MUZZLE, 100), 0, "sane")
		local function broken(changes: { [string]: any }, label: string)
			local problems = Sight.problems(with(changes), MUZZLE, 100)
			expect.equal(#problems > 0, true, label)
		end
		broken({ Front = Vector3.new(0, 0.6, 0.2) }, "front behind the rear")
		broken({ Front = Vector3.new(0, 0.6, -3) }, "front past the muzzle")
		broken({ Front = Vector3.new(0, 0.3, -1.4) }, "line far off the bore")
		broken(
			{ Rear = Vector3.new(0, 0.2, 0), Front = Vector3.new(0, 0.2, -1.4) },
			"under the bore"
		)
		broken({ EyeRelief = 0 }, "eye in the rear sight")
		broken({ EyeRelief = 3 }, "eye far behind")
		broken({ Zoom = 0.5 }, "wider than the hip")
		broken({ Zoom = 4 }, "irons that magnify")
		broken({ Kind = "scope", Zoom = 1.2 }, "a scope that does not")
		broken({ Kind = "scope", Zoom = 4, EyeRelief = 1 }, "a scope at arm's length")
		broken({ Kind = "laser" }, "unknown kind")
		broken({ Hold = "hip" }, "unknown hold")
		broken(
			{ Rear = Vector3.new(1.5, 0.6, 0), Front = Vector3.new(1.5, 0.6, -1.4) },
			"far off to the side"
		)
	end,
	["every gun row carries a sane sight on its own mesh"] = function()
		local problems = {}
		local count = 0
		for key, row in Config.Weapons do
			count += 1
			local raw = row.Sight
			if type(raw) ~= "table" or not raw.Rear or not raw.Front then
				table.insert(problems, `{key}: no Sight with Rear and Front`)
				continue
			end
			local model = row.Model
			if type(model) ~= "string" then
				table.insert(problems, `{key}: no Model`)
				continue
			end
			local sight = Sight.resolve(raw, DEFAULTS)
			local muzzle = meshVector(model, "muzzle")
			for _, problem in Sight.problems(sight, muzzle, DEFAULTS.ZeroDistance) do
				table.insert(problems, `{key}: {problem}`)
			end
			-- Both points are on the mesh: inside its bounds (a swapped axis or a typo is not).
			local size, offset = meshVector(model, "size"), meshVector(model, "offset")
			for name, point in { Rear = sight.Rear, Front = sight.Front } do
				local from = point - offset
				local slack = 0.03
				if
					math.abs(from.X) > size.X / 2 + slack
					or math.abs(from.Y) > size.Y / 2 + slack
					or math.abs(from.Z) > size.Z / 2 + slack
				then
					table.insert(problems, `{key}: {name} is outside the {model} mesh`)
				end
			end
			if DEFAULTS.Hold[sight.Hold] == nil then
				table.insert(problems, `{key}: no hip hold "{sight.Hold}"`)
			end
		end
		expect.equal(count >= 9, true, "found the gun rows")
		if #problems > 0 then
			error("\n  " .. table.concat(problems, "\n  "))
		end
	end,
	["every gun's aimed view is narrower than the hip and its sights clear the near plane"] = function()
		local first = Config.Camera.FirstPerson
		for key, row in Config.Weapons do
			local sight = Sight.resolve(row.Sight, DEFAULTS)
			local fov = Sight.fov(70, sight.Zoom)
			expect.equal(fov <= 70 and fov >= 8, true, `{key} fov {fov}`)
			if sight.Kind == "irons" then
				-- At the usual 0.1-stud near plane the rear sight is drawn at the base scale
				-- or a little over, never near full size (where walls cut into the gun).
				local clearance = sight.EyeRelief - first.KickBack * first.AdsKick
				local scale = Sight.viewScale(first.Scale, 0.1, clearance, first.NearMargin)
				expect.equal(scale < 0.6, true, `{key} scale {scale}`)
			end
		end
	end,
}
