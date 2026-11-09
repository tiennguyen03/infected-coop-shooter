--!strict
-- The sky for Stage 1: the first days of the outbreak. Late afternoon under a smoke-stained
-- overcast, orange haze on the horizon, the city beyond the perimeter wall burning. Built
-- from Lighting/Atmosphere/Clouds settings plus a ring of skyline towers outside the arena
-- (assets/3d/build/city.py meshes) with slow smoke columns and fire glow (docs/STYLES.md >
-- Stage 1 sky). Everything here is static: 46 meshes, a handful of low-rate emitters.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MeshAssets"))

local SkyService = {}

local SILHOUETTE_COLOR = Color3.fromRGB(30, 27, 30)
local SMOKE_COLOR = Color3.fromRGB(92, 80, 74)
local FIRE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 90)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(232, 120, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 30, 10)),
})

-- The distant city: { angle degrees from +X around the arena, distance, tower kind (an
-- `env_city_<kind>` mesh and its `_lit` twin), uniform scale, yaw jitter, burning }.
-- Clustered north and east (the city the checkpoint was guarding), thinner and lower
-- elsewhere. Scales stay 0.8-1.2 so a storey reads 8-12 studs.
type Tower = { a: number, d: number, kind: string, s: number, yaw: number?, smoke: boolean? }
local SKYLINE: { Tower } = {
	{ a = 5, d = 480, kind = "midrise", s = 1.0, yaw = 8 },
	{ a = 20, d = 520, kind = "office", s = 0.95 },
	{ a = 28, d = 480, kind = "ruined", s = 0.85, yaw = -10, smoke = true },
	{ a = 36, d = 560, kind = "deco", s = 0.9 },
	{ a = 44, d = 500, kind = "residential", s = 1.0, yaw = 15 },
	{ a = 52, d = 540, kind = "glass", s = 0.95, smoke = true },
	{ a = 60, d = 470, kind = "midrise", s = 0.9, yaw = -12 },
	{ a = 68, d = 530, kind = "office", s = 0.85, yaw = 180 },
	{ a = 76, d = 500, kind = "ruined", s = 0.9, yaw = 12, smoke = true },
	{ a = 84, d = 560, kind = "deco", s = 1.05, yaw = 45 },
	{ a = 92, d = 490, kind = "residential", s = 0.85 },
	{ a = 100, d = 540, kind = "glass", s = 0.85, yaw = 20 },
	{ a = 110, d = 510, kind = "residential", s = 0.9, yaw = -8, smoke = true },
	{ a = 122, d = 560, kind = "office", s = 0.8 },
	{ a = 136, d = 500, kind = "midrise", s = 0.85, yaw = 10 },
	{ a = 152, d = 540, kind = "residential", s = 0.8, yaw = 180 },
	{ a = 175, d = 520, kind = "midrise", s = 0.8, yaw = -15 },
	{ a = 205, d = 540, kind = "ruined", s = 0.75, smoke = true },
	{ a = 240, d = 520, kind = "residential", s = 0.75, yaw = 12 },
	{ a = 275, d = 560, kind = "office", s = 0.8, yaw = -10 },
	{ a = 300, d = 530, kind = "midrise", s = 0.8 },
	{ a = 330, d = 500, kind = "glass", s = 0.8, yaw = 30, smoke = true },
	{ a = 350, d = 550, kind = "office", s = 0.9, yaw = 6 },
}

local function smokeColumn(parent: BasePart, size: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(SMOKE_COLOR)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, size * 3.2),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(14, 22)
	emitter.Rate = 5
	emitter.Speed = NumberRange.new(size * 0.5, size * 0.7)
	emitter.SpreadAngle = Vector2.new(6, 6)
	emitter.Acceleration = Vector3.new(size * 0.12, 0, 0) -- a light westerly wind
	emitter.Rotation = NumberRange.new(-30, 30)
	emitter.RotSpeed = NumberRange.new(-4, 4)
	emitter.LightInfluence = 0.8
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
end

local function fire(parent: BasePart, size: number, rate: number, withLight: boolean?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Fire"
	emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
	emitter.Color = FIRE_COLOR
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.6),
		NumberSequenceKeypoint.new(0.3, size),
		NumberSequenceKeypoint.new(1, size * 0.3),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.9, 1.6)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(size * 0.8, size * 1.4)
	emitter.SpreadAngle = Vector2.new(14, 14)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
	-- Only fires inside the arena light anything; the skyline's glow is the particles'
	-- LightEmission (a PointLight 470+ studs out lights nothing: STYLES §6).
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 130, 55)
		light.Brightness = 1.6
		light.Range = 36
		light.Shadows = false
		light.Parent = parent
	end
end

-- Marks a placed piece as burning: smoke and fire from an invisible emitter part on its top.
function SkyService.burn(piece: BasePart)
	local top = Instance.new("Part")
	top.Name = "Burning"
	top.Size = Vector3.new(piece.Size.X * 0.5, 1, piece.Size.Z * 0.5)
	top.CFrame = piece.CFrame * CFrame.new(0, piece.Size.Y / 2 - 1, 0)
	top.Transparency = 1
	top.Anchored = true
	top.CanCollide = false
	top.CanQuery = false
	top.CanTouch = false
	top.CastShadow = false
	fire(top, 7, 20, true)
	smokeColumn(top, 12)
	top.Parent = piece
end

-- Skyline towers (docs/STYLES.md §7; owner 2026-11-08: the flat slabs looked "goofy").
-- Each tower is a palette mesh plus its lit-window twin painted Neon: sodium in most, a
-- cold fluorescent in some, fire-orange in the burning ones. Seeded per tower, so the city
-- is the same every run. A tower whose mesh never loads becomes a plain dark block.
local SODIUM = Color3.fromRGB(255, 170, 90)
local FLUORESCENT = Color3.fromRGB(210, 220, 214)
local FIRE_WINDOW = Color3.fromRGB(255, 110, 40)

local function quiet(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function emitterTop(model: Model, cframe: CFrame, width: number)
	local top = Instance.new("Part")
	top.Name = "Burning"
	top.Size = Vector3.new(width * 0.5, 1, width * 0.4)
	top.CFrame = cframe
	top.Transparency = 1
	quiet(top)
	smokeColumn(top, 28)
	fire(top, 18, 6)
	top.Parent = model
end

local function placeTower(model: Model, tower: Tower, index: number)
	local a = math.rad(tower.a)
	local ground = Vector3.new(math.cos(a) * tower.d, -2, math.sin(a) * tower.d)
	-- The long face toward the arena (a mesh's -Z), then the per-tower jitter.
	local base = CFrame.lookAt(ground, Vector3.new(0, -2, 0))
		* CFrame.Angles(0, math.rad(tower.yaw or 0), 0)
	local name = "env_city_" .. tower.kind
	local body = MeshAssets.waitFor(name, 30)
	local size = MeshAssets.getSize(name) or Vector3.new(60, 150, 40)
	local height = size.Y * tower.s
	if body then
		body.Size = size * tower.s
		body.CFrame = base * CFrame.new(MeshAssets.getOffset(name) * tower.s)
		quiet(body)
		body.Parent = model
		local lit = MeshAssets.waitFor(name .. "_lit", 30)
		local litSize = MeshAssets.getSize(name .. "_lit")
		if lit and litSize then
			local rng = Random.new(index * 7919)
			lit.Size = litSize * tower.s
			lit.CFrame = base * CFrame.new(MeshAssets.getOffset(name .. "_lit") * tower.s)
			lit.Color = if tower.smoke
				then FIRE_WINDOW
				elseif rng:NextNumber() < 0.25 then FLUORESCENT
				else SODIUM
			quiet(lit)
			lit.Parent = model
		end
	else
		local block = Instance.new("Part")
		block.Name = "Block"
		block.Size = Vector3.new(size.X, size.Y, size.Z) * tower.s
		block.CFrame = base * CFrame.new(0, height / 2, 0)
		block.Material = Enum.Material.SmoothPlastic
		block.Color = SILHOUETTE_COLOR
		quiet(block)
		block.Parent = model
	end
	if tower.smoke then
		emitterTop(model, base * CFrame.new(0, height * 0.6, 0), size.X * tower.s)
	end
end

local function buildSkyline()
	local model = Instance.new("Model")
	model.Name = "DistantCity"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the skyline never streams out
	model.Parent = workspace
	-- Mesh templates build asynchronously at boot: place without holding up the boot.
	for index, tower in SKYLINE do
		task.spawn(placeTower, model, tower, index)
	end
end

function SkyService.init()
	-- Late afternoon through a smoke-stained sky: burnt orange, dark rust clouds. Gloomy but
	-- readable: an Infected reads as a shape at 90 studs (STYLES §7, 2026-11-08 pass). No
	-- Fog settings: an Atmosphere overrides them.
	Lighting.ClockTime = 16.9
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.3
	Lighting.Ambient = Color3.fromRGB(96, 84, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 126, 112)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 176, 110)
	Lighting.ColorShift_Bottom = Color3.fromRGB(96, 72, 62)
	Lighting.ExposureCompensation = 0.15
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.25

	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Sky")
			or child:IsA("Atmosphere")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("BloomEffect")
		then
			child:Destroy()
		end
	end
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 24
	sky.MoonAngularSize = 0
	sky.StarCount = 0
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(205, 104, 58)
	atmosphere.Decay = Color3.fromRGB(110, 44, 32)
	atmosphere.Glare = 0.5
	atmosphere.Haze = 5.2
	atmosphere.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Brightness = 0.03
	grade.Contrast = 0.14
	grade.Saturation = 0
	grade.TintColor = Color3.fromRGB(255, 240, 228)
	grade.Parent = Lighting

	-- Neon, fire and the sun bloom; plain geometry does not (threshold 1.7).
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 1.7
	bloom.Parent = Lighting

	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.65
		clouds.Density = 0.5
		clouds.Color = Color3.fromRGB(128, 86, 64)
		clouds.Enabled = true
		clouds.Parent = terrain
	end

	buildSkyline()
end

return SkyService
