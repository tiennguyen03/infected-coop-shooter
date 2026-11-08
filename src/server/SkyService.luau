--!strict
-- The sky for Stage 1: the first days of the outbreak. Late afternoon under a smoke-stained
-- overcast, orange haze on the horizon, the city beyond the perimeter wall burning. Built
-- from Lighting/Atmosphere/Clouds settings plus a ring of flat skyline silhouettes outside
-- the arena with slow smoke columns and fire glow (docs/STYLES.md > Stage 1 sky).
-- Everything here is static and cheap: ~30 boxes, a handful of low-rate particle emitters.

local Lighting = game:GetService("Lighting")

local SkyService = {}

local SILHOUETTE_COLOR = Color3.fromRGB(30, 27, 30)
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

-- Skyline detail (docs/STYLES.md §7, art direction 2026-11-08): the face toward the arena
-- (local -X) carries a window-grid Texture (WINDOW_TEXTURE, "" = none) and a few lit
-- windows as Neon strips; tall blocks get a setback crown and a tank or an antenna (the
-- three tallest a red tip). Seeded per block, so the city is the same every run.
local WINDOW_TEXTURE = "rbxassetid://75759991359237" -- assets/3d/build/city_windows.py
local WINDOW_CELL = 10 -- studs per window (one storey)
local SODIUM = Color3.fromRGB(255, 170, 90)
local FLUORESCENT = Color3.fromRGB(210, 220, 214)
local FIRE_WINDOW = Color3.fromRGB(255, 110, 40)

local function decorPart(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	neon: boolean?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = color
	part.Parent = model
	return part
end

-- 70% sodium, 20% fluorescent, 10% fire (fire only high up on a burning block).
local function litColor(rng: Random, high: boolean, smoke: boolean?): Color3
	local roll = rng:NextNumber()
	if roll < 0.1 and smoke and high then
		return FIRE_WINDOW
	elseif roll < 0.8 then
		return SODIUM
	end
	return FLUORESCENT
end

local function detailBlock(
	model: Model,
	part: BasePart,
	block: Block,
	index: number,
	tallest: { [number]: boolean }
)
	local rng = Random.new(index * 7919)
	local depth, height, faceWidth = part.Size.X, part.Size.Y, part.Size.Z
	if WINDOW_TEXTURE ~= "" then
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Front, Enum.NormalId.Back } do
			local texture = Instance.new("Texture")
			texture.Texture = WINDOW_TEXTURE
			texture.Face = face
			texture.StudsPerTileU = WINDOW_CELL * 2
			texture.StudsPerTileV = WINDOW_CELL * 2
			texture.Parent = part
		end
	end
	-- Lit windows: 1-3 cells wide, on the cell grid of the arena-facing face.
	local columns = math.max(math.floor(faceWidth / WINDOW_CELL), 1)
	local rows = math.max(math.floor(height / WINDOW_CELL) - 1, 1)
	for _ = 1, math.floor(height / 45) + 1 do
		local span = math.min(rng:NextInteger(1, 3), columns)
		local column = rng:NextInteger(0, columns - span)
		local row = rng:NextInteger(1, rows)
		local z = -faceWidth / 2 + (column + span / 2) * WINDOW_CELL
		local y = -height / 2 + (row + 0.5) * WINDOW_CELL
		decorPart(
			model,
			"LitWindow",
			Vector3.new(0.4, WINDOW_CELL * 0.6, span * WINDOW_CELL - 3),
			part.CFrame * CFrame.new(-depth / 2 - 0.1, y, z),
			litColor(rng, row > rows * 2 / 3, block.smoke),
			true
		)
	end
	if block.h >= 100 then
		local crown = Vector3.new(depth * 0.7, height * 0.15, faceWidth * 0.7)
		local crownPart = decorPart(
			model,
			"Crown",
			crown,
			part.CFrame * CFrame.new(0, height / 2 + crown.Y / 2, 0),
			SILHOUETTE_COLOR
		)
		local top = crownPart.CFrame * CFrame.new(0, crown.Y / 2, 0)
		if tallest[index] then
			local mast = decorPart(
				model,
				"Antenna",
				Vector3.new(1.5, 40, 1.5),
				top * CFrame.new(0, 20, 0),
				SILHOUETTE_COLOR
			)
			decorPart(
				model,
				"AntennaTip",
				Vector3.new(3, 3, 3),
				mast.CFrame * CFrame.new(0, 21, 0),
				Color3.fromRGB(220, 40, 30),
				true
			)
		elseif rng:NextNumber() < 0.6 then
			decorPart(
				model,
				"Tank",
				Vector3.new(12, 10, 12),
				top * CFrame.new(rng:NextNumber(-8, 8), 5, rng:NextNumber(-6, 6)),
				SILHOUETTE_COLOR
			)
		end
	end
end

local function buildSkyline()
	local model = Instance.new("Model")
	model.Name = "DistantCity"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the skyline never streams out
	local byHeight = {}
	for index in SKYLINE do
		table.insert(byHeight, index)
	end
	table.sort(byHeight, function(a, b)
		return SKYLINE[a].h > SKYLINE[b].h
	end)
	local tallest = { [byHeight[1]] = true, [byHeight[2]] = true, [byHeight[3]] = true }
	for index, block in SKYLINE do
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
		detailBlock(model, part, block, index, tallest)
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
