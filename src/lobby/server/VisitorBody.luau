--!strict
-- The Visitor's look on his lobby R15 figure (NpcBody; the lore developer, docs/lore/desk_crew.md
-- > The Visitor): a long dark raincoat over civilian clothes, a sweater and a collared shirt
-- showing at the open front, no rank, no name tape, no patch, and a red lanyard with a badge that
-- reads ESCORT REQUIRED. No screening band on his left wrist (only the Pike wear one).
--
-- Built from plain parts welded to the rig once its look is on (Attributes.CrewReady): the coat
-- is the body colour on the torso and arms, plus a skirt to the knees; no catalog items yet (a
-- catalog raincoat could replace the skirt later, through DeskService's DRESS).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)

local VisitorBody = {}

VisitorBody.Coat = Color3.fromRGB(46, 48, 50)
VisitorBody.Trousers = Color3.fromRGB(36, 36, 40)
local SWEATER = Color3.fromRGB(72, 52, 50)
local SHIRT = Color3.fromRGB(214, 210, 196)
local LANYARD = Color3.fromRGB(176, 30, 30)
local CARD = Color3.fromRGB(232, 230, 222)

local function wear(
	model: Model,
	limbName: string,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3
): BasePart?
	local limb = model:FindFirstChild(limbName)
	if not (limb and limb:IsA("BasePart")) then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = limb.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- The badge's words, on the card's front (R15 front is -Z).
local function letter(card: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(120, 160)
	gui.LightInfluence = 1
	local band = Instance.new("Frame")
	band.Size = UDim2.fromScale(1, 0.3)
	band.BackgroundColor3 = LANYARD
	band.BorderSizePixel = 0
	band.Parent = gui
	local words = Instance.new("TextLabel")
	words.Size = UDim2.fromScale(1, 0.6)
	words.Position = UDim2.fromScale(0, 0.35)
	words.BackgroundTransparency = 1
	words.Font = Enum.Font.GothamBold
	words.TextScaled = true
	words.TextWrapped = true
	words.TextColor3 = LANYARD
	words.Text = "ESCORT\nREQUIRED"
	words.Parent = gui
	gui.Parent = card
end

-- Dresses `body` once its look is on (gives up after 30 s: a stand-in with no rig stays bare).
function VisitorBody.dress(body: Model)
	task.spawn(function()
		local deadline = os.clock() + 30
		while not body:GetAttribute(Attributes.CrewReady) and os.clock() < deadline do
			task.wait(0.25)
		end
		local torso = body:FindFirstChild("UpperTorso")
		local lower = body:FindFirstChild("LowerTorso")
		if not (torso and torso:IsA("BasePart") and lower and lower:IsA("BasePart")) then
			return
		end
		-- The coat's sleeves: the arms in the coat's colour, the hands left bare.
		for _, name in { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" } do
			local arm = body:FindFirstChild(name)
			if arm and arm:IsA("BasePart") then
				arm.Color = VisitorBody.Coat
			end
		end
		local t, l = torso.Size, lower.Size
		-- The open front: a strip of sweater, the shirt's collar over it.
		wear(
			body,
			"UpperTorso",
			"Sweater",
			Vector3.new(0.7, t.Y * 0.8, 0.06),
			CFrame.new(0, -t.Y * 0.08, -t.Z / 2 - 0.02),
			SWEATER
		)
		wear(
			body,
			"UpperTorso",
			"Collar",
			Vector3.new(0.9, 0.18, t.Z * 0.7),
			CFrame.new(0, t.Y / 2 - 0.06, -t.Z * 0.1),
			SHIRT
		)
		-- The coat's collar, turned up a little.
		wear(
			body,
			"UpperTorso",
			"CoatCollar",
			Vector3.new(t.X * 0.75, 0.3, t.Z + 0.1),
			CFrame.new(0, t.Y / 2 + 0.02, 0.05),
			VisitorBody.Coat
		)
		-- The skirt to the knees, hung from the waist.
		wear(
			body,
			"LowerTorso",
			"CoatSkirt",
			Vector3.new(l.X + 0.25, 2.2, t.Z + 0.2),
			CFrame.new(0, -1.0, 0),
			VisitorBody.Coat
		)
		-- The red lanyard (two cords from the collar) and its badge on the chest.
		for _, side in { -1, 1 } do
			local cord = wear(
				body,
				"UpperTorso",
				"Lanyard",
				Vector3.new(0.06, t.Y * 0.5, 0.06),
				CFrame.new(side * 0.22, t.Y * 0.18, -t.Z / 2 - 0.07)
					* CFrame.Angles(0, 0, math.rad(side * -12)),
				LANYARD
			)
			if cord then
				cord.Material = Enum.Material.Fabric
			end
		end
		local card = wear(
			body,
			"UpperTorso",
			"Badge",
			Vector3.new(0.42, 0.56, 0.04),
			CFrame.new(0, -t.Y * 0.12, -t.Z / 2 - 0.08),
			CARD
		)
		if card then
			letter(card)
		end
	end)
end

return VisitorBody
