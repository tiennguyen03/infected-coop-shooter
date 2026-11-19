--!strict
-- Carrier v2 in the lobby (docs/sprints/CARRIER_V2.md, owner-approved 2026-11-17): the revamped
-- ship's dressing, placed from the generated table CarrierV2Data (assets/3d/build/carrier_v2.py
-- export_luau): hull frames and deckhead beams, pipes, doors, fire stations, lamp fittings, floor
-- paint and stencils, the deck gear, the vendor corners' props, the Easter eggs, the hidden nook
-- under the ramp, and the burning city straight ahead. Everything the ship had before stays
-- where FallowBuilder, FallowArt, DeskService, ArmsRack, CallInDisplay and MotorPool build it;
-- this only adds. Off with Config.Lobby.CarrierV2.Enabled = false. Lettering rows with a `count`
-- tag (the call-in numbers, MISSIONS HOME, the days tiles) are painted by TallyBoards.
--
-- The kit meshes (CarrierKitMeshes, uploaded as models to the group) are registered with
-- MeshAssets before its init(), so CarrierV2 boots first; the build itself waits for the
-- templates and never blocks boot. A mesh that does not load is skipped with one warning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CarrierKitMeshes = require(ReplicatedStorage.Shared.CarrierKitMeshes)
local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Build = require(script.Parent.Build)
local Data = require(script.Parent.CarrierV2Data)
local TallyBoards = require(script.Parent.TallyBoards)

local CarrierV2 = {}

-- Kinds a soldier can walk into (the nook's walls, the tarp); the rest is paint, fittings
-- overhead and the city, with no collision.
local SOLID_KINDS = { wall_lo = true, crate = true }
local FACES: { [string]: Vector3 } = {
	up = Vector3.yAxis,
	["-z"] = -Vector3.zAxis,
	["+z"] = Vector3.zAxis,
	["+x"] = Vector3.xAxis,
	["-x"] = -Vector3.xAxis,
}
local MESH_WAIT = 60 -- seconds the build waits for a kit mesh to load

type Kind = { color: Color3, neon: boolean, transparency: number }
local KINDS: { [string]: Kind } = Data.kinds
local GREY: Kind = { color = Color3.fromRGB(128, 128, 128), neon = false, transparency = 0 }

local function buildParts(folder: Folder)
	for _, row in Data.parts do
		local kind = KINDS[row.kind] or GREY
		local b = row.box
		local x0, x1, y0, y1, z0, z1 = b[1], b[2], b[3], b[4], b[5], b[6]
		local options: Build.PartOptions = {
			material = if kind.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			transparency = kind.transparency,
			collide = SOLID_KINDS[row.kind] == true,
			shadow = false,
		}
		local name = "V2_" .. row.kind
		if row.shape == "wedge" then
			-- Full height at z0, nothing at z1; a WedgePart rises toward +Z, so turn it round.
			options.wedge = true
			Build.part(
				folder,
				name,
				Vector3.new(x1 - x0, y1 - y0, z1 - z0),
				CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
					* CFrame.Angles(0, math.pi, 0),
				kind.color,
				options
			)
		else
			Build.box(
				folder,
				name,
				Vector3.new(x0, y0, z0),
				Vector3.new(x1, y1, z1),
				kind.color,
				options
			)
		end
	end
end

-- A kit mesh at its placement: yaw and tilt in the Blender sense (Blender's frame is the game's
-- mirrored), scale per game axis. A mirrored copy (negative scale) turns half round instead.
local function placeMesh(folder: Folder, name: string, at: { number })
	local part = MeshAssets.waitFor(name, MESH_WAIT)
	if not part then
		return
	end
	local yaw, tilt = at[4], at[5]
	if at[6] < 0 or at[8] < 0 then
		yaw += 180
	end
	local scale = Vector3.new(math.abs(at[6]), math.abs(at[7]), math.abs(at[8]))
	local placed = CFrame.new(at[1], at[2], at[3])
		* CFrame.Angles(0, math.rad(-yaw), 0)
		* CFrame.Angles(math.rad(-tilt), 0, 0)
	part.Size = part.Size * scale
	part.CFrame = placed * CFrame.new(MeshAssets.getOffset(name) * scale)
	part.Parent = folder
end

-- Lettering: an invisible card carrying one SurfaceGui, its front on the face it is painted on.
local function buildText(
	folder: Folder,
	text: string,
	face: string,
	kindName: string,
	at: { number }
): TextLabel
	local point = Vector3.new(at[1], at[2], at[3])
	local height = at[4]
	local normal = FACES[face] or Vector3.yAxis
	local up = Vector3.yAxis
	if face == "up" then
		-- Floor paint: the lettering's up is the Blender text's up, turned by its yaw.
		local a = math.rad(at[5])
		up = Vector3.new(-math.sin(a), 0, math.cos(a))
	end
	local card = Build.part(
		folder,
		"V2_Text",
		Vector3.new(#text * height * 0.72 + height * 0.4, height * 1.3, 0.05),
		CFrame.lookAt(point, point + normal, up),
		Color3.new(1, 1, 1),
		{ transparency = 1, collide = false, shadow = false }
	)
	card.CanQuery = false
	local kind = KINDS[kindName] or GREY
	return Build.text(
		card,
		Enum.NormalId.Front,
		text,
		{ color = kind.color, font = Enum.Font.GothamBold }
	)
end

local function holder(folder: Folder, name: string, size: Vector3, at: Vector3): BasePart
	local part = Build.part(
		folder,
		name,
		size,
		CFrame.new(at),
		Color3.new(1, 1, 1),
		{ transparency = 1, collide = false, shadow = false }
	)
	part.CanQuery = false
	return part
end

-- Each corner's own small light (and the net's chemlights); no shadows.
local function buildLights(folder: Folder)
	for _, row in Data.lights do
		local at = row.at
		local light = Instance.new("PointLight")
		light.Color = row.color
		light.Range = at[4]
		light.Brightness = 1.6
		light.Shadows = false
		light.Parent =
			holder(folder, "V2_Light", Vector3.new(0.2, 0.2, 0.2), Vector3.new(at[1], at[2], at[3]))
	end
end

-- The city's fires and smoke (Blender stand-ins in the pictures): one emitter each.
local function buildFx(folder: Folder)
	local rate = Config.Lobby.CarrierV2.FireRate
	for _, row in Data.fx do
		local at = row.at
		local scale = at[4]
		local emitter = Instance.new("ParticleEmitter")
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(12, 12)
		if row.kind == "fire" then
			emitter.Color =
				ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(220, 60, 20))
			emitter.LightEmission = 1
			emitter.Size = NumberSequence.new(10 * scale, 2 * scale)
			emitter.Transparency = NumberSequence.new(0.2, 1)
			emitter.Lifetime = NumberRange.new(1.5, 3)
			emitter.Speed = NumberRange.new(8 * scale, 14 * scale)
			emitter.Rate = rate
		else
			emitter.Color =
				ColorSequence.new(Color3.fromRGB(40, 36, 36), Color3.fromRGB(70, 66, 66))
			emitter.Size = NumberSequence.new(20 * scale, 60 * scale)
			emitter.Transparency = NumberSequence.new(0.3, 1)
			emitter.Lifetime = NumberRange.new(8, 14)
			emitter.Speed = NumberRange.new(6, 10)
			emitter.Rate = math.max(1, rate // 3)
		end
		emitter.Parent = holder(
			folder,
			"V2_" .. row.kind,
			Vector3.new(8 * scale, 2, 8 * scale),
			Vector3.new(at[1], at[2], at[3])
		)
	end
end

local function build()
	local folder = Build.folder(Workspace, "CarrierV2")
	buildParts(folder)
	for _, row in Data.texts do
		local label = buildText(folder, row.text, row.face, row.kind, row.at)
		-- A count painted from the store and the clock (TallyBoards): call-ins, missions, days.
		local count = (row :: any).count
		if typeof(count) == "string" then
			TallyBoards.register(count, label)
		end
	end
	buildLights(folder)
	buildFx(folder)
	for _, row in Data.meshes do
		task.spawn(placeMesh, folder, row.name, row.at)
	end
end

function CarrierV2.init()
	if not Config.Lobby.CarrierV2.Enabled then
		return
	end
	MeshAssets.register(CarrierKitMeshes :: any) -- a generated literal; its rows match register's type
	task.defer(build)
end

return CarrierV2
