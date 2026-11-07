--!strict
-- The sky for Stage 1: the first days of the outbreak. Late afternoon under a smoke-stained
-- overcast, orange haze on the horizon, the city beyond the perimeter wall burning. Built
-- from Lighting/Atmosphere/Clouds settings plus a ring of flat skyline silhouettes outside
-- the arena with slow smoke columns and fire glow (docs/STYLES.md > Stage 1 sky).
-- Everything here is static and cheap: ~30 boxes, a handful of low-rate particle emitters.

local Lighting = game:GetService("Lighting")

local SkyService = {}

local SILHOUETTE_COLOR = Color3.fromRGB(44, 40, 42)
local SMOKE_COLOR = Color3.fromRGB(92, 80, 74)
local FIRE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 90)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(232, 120, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 30, 10)),
})

-- Distant city blocks: { angle degrees from +X around the arena, distance, width, height }.
-- Clustered north and east (the city the checkpoint was guarding), thinner elsewhere.
type Block = { a: number, d: number, w: number, h: number, smoke: boolean? }
local SKYLINE: { Block } = {
	{ a = 20, d = 520, w = 70, h = 150 },
	{ a = 28, d = 480, w = 50, h = 95, smoke = true },
	{ a = 36, d = 560, w = 90, h = 200 },
	{ a = 44, d = 500, w = 60, h = 120 },
	{ a = 52, d = 540, w = 80, h = 170, smoke = true },
	{ a = 60, d = 470, w = 45, h = 80 },
	{ a = 68, d = 530, w = 75, h = 140 },
	{ a = 76, d = 500, w = 55, h = 110, smoke = true },
	{ a = 84, d = 560, w = 95, h = 220 },
	{ a = 92, d = 490, w = 50, h = 90 },
	{ a = 100, d = 540, w = 70, h = 160 },
	{ a = 110, d = 510, w = 60, h = 100, smoke = true },
	{ a = 122, d = 560, w = 85, h = 130 },
	{ a = 136, d = 500, w = 50, h = 70 },
	{ a = 152, d = 540, w = 65, h = 90 },
	{ a = 175, d = 520, w = 55, h = 60 },
	{ a = 205, d = 540, w = 60, h = 75, smoke = true },
	{ a = 240, d = 520, w = 70, h = 85 },
	{ a = 275, d = 560, w = 80, h = 110 },
	{ a = 300, d = 530, w = 55, h = 70 },
	{ a = 330, d = 500, w = 65, h = 95, smoke = true },
	{ a = 350, d = 550, w = 75, h = 130 },
	{ a = 5, d = 480, w = 45, h = 85 },
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

local function fire(parent: BasePart, size: number, rate: number)
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
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Brightness = 1
	light.Range = size * 6
	light.Parent = parent
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
	fire(top, 7, 20)
	smokeColumn(top, 12)
	top.Parent = piece
end

local function buildSkyline()
	local model = Instance.new("Model")
	model.Name = "DistantCity"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the skyline never streams out
	for _, block in SKYLINE do
		local a = math.rad(block.a)
		local part = Instance.new("Part")
		part.Name = "Block"
		part.Size = Vector3.new(block.w, block.h, block.w * 0.7)
		part.CFrame = CFrame.new(math.cos(a) * block.d, block.h / 2 - 2, math.sin(a) * block.d)
			* CFrame.Angles(0, -a, 0)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = SILHOUETTE_COLOR
		part.Parent = model
		if block.smoke then
			local top = Instance.new("Part")
			top.Name = "Burning"
			top.Size = Vector3.new(block.w * 0.5, 1, block.w * 0.4)
			top.CFrame = part.CFrame * CFrame.new(0, block.h / 2 - 1, 0)
			top.Transparency = 1
			top.Anchored = true
			top.CanCollide = false
			top.CanQuery = false
			top.CanTouch = false
			top.CastShadow = false
			smokeColumn(top, 28)
			fire(top, 18, 6)
			top.Parent = model
		end
	end
	model.Parent = workspace
end

function SkyService.init()
	-- Late afternoon, low sun through a smoke-stained sky: burnt orange, dark rust clouds.
	Lighting.ClockTime = 17.6
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 1.8
	Lighting.Ambient = Color3.fromRGB(70, 56, 52)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 96, 80)
	Lighting.ColorShift_Top = Color3.fromRGB(230, 140, 70)
	Lighting.ColorShift_Bottom = Color3.fromRGB(110, 60, 40)
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.FogColor = Color3.fromRGB(176, 104, 66)
	Lighting.FogStart = 260
	Lighting.FogEnd = 1500

	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") then
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
	atmosphere.Density = 0.36
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(214, 112, 58)
	atmosphere.Decay = Color3.fromRGB(92, 38, 28)
	atmosphere.Glare = 0.7
	atmosphere.Haze = 6
	atmosphere.Parent = Lighting

	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.72
		clouds.Density = 0.6
		clouds.Color = Color3.fromRGB(104, 66, 48)
		clouds.Enabled = true
		clouds.Parent = terrain
	end

	buildSkyline()
end

return SkyService
