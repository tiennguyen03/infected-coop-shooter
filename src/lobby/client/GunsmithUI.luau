--!strict
-- The Loadmaster's EDIT (Nova, 2026-11-11: "a button next to each gun that says edit and then
-- pulls up a screen of the gun model and several differnt options for accessories ie. the
-- suppressor being for the barrel"). Opened from a gun's row in the Loadout (LoadoutMenu's
-- `edit` option, LoadmasterUI): the gun turning slowly in a viewport (the rack's own copy,
-- ArmsRack), and one list per slot it takes (Config.Attachments.Slots: the Barrel, NONE or the
-- suppressor). The suppressor shows on the gun as it is picked. DONE hands the fitting back
-- to the Loadout (signed with SIGN FOR IT); BACK leaves it as it was.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local HudTheme = require(script.Parent.HudTheme)

local GunsmithUI = {}

export type Fitted = { [string]: string } -- [slot] = option

local C = HudTheme.Color
local WIDTH, HEIGHT = 780, 460
local VIEW = Vector2.new(440, 300)
local ROW = 30
local FOV = 34
local ACTION_BACK = "GunsmithBack"

-- The rack's copy of the gun (ArmsRack: a Model named by the gun's id), or nil.
local function rackPiece(id: string): Model?
	for _, model in Workspace:GetDescendants() do
		if
			model:IsA("Model")
			and model.Name == id
			and model:GetAttribute(Attributes.RackDisplay)
		then
			return model
		end
	end
	return nil
end

local function textButton(parent: Instance, text: string, size: Vector2): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(size.X, size.Y)
	button.BackgroundColor3 = C.Track
	button.BackgroundTransparency = 0.35
	button.BorderSizePixel = 0
	button.Font = HudTheme.Font.Line
	button.TextSize = 14
	button.TextColor3 = C.Text
	button.Text = text
	button.Parent = parent
	return button
end

-- Opens the screen over `parent` for gun `gunId` with `current` fitted; `done` gets the new
-- fitting on DONE. Returns a function that closes it.
function GunsmithUI.open(
	parent: Instance,
	gunId: string,
	current: Fitted,
	done: (fitted: Fitted) -> ()
): () -> ()
	local weapon = WeaponDefinitions.get(gunId)
	local offers = WeaponDefinitions.options(gunId)
	local fitted: Fitted = table.clone(current)

	-- A dark cover over the Loadout that takes its clicks while this is open.
	local cover = Instance.new("TextButton")
	cover.Name = "Gunsmith"
	cover.AutoButtonColor = false
	cover.Text = ""
	cover.BackgroundColor3 = Color3.new()
	cover.BackgroundTransparency = 0.6
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.ZIndex = 20
	cover.Modal = true -- the mouse is free while it is open, whoever opened it
	cover.Parent = parent

	local frame = HudTheme.rect(cover, UDim2.fromOffset(WIDTH, HEIGHT), C.MenuBack, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Red
	stroke.Parent = frame

	local header = HudTheme.label(frame, {
		text = `//EDIT  ·  {string.upper(weapon.Name)}`,
		font = HudTheme.Font.Headline,
		size = 28,
	})
	header.Position = UDim2.fromOffset(24, 16)
	local sub = HudTheme.label(frame, { text = weapon.Designation, size = 13, color = C.TextDim })
	sub.Position = UDim2.fromOffset(26, 52)

	-- The gun.
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromOffset(VIEW.X, VIEW.Y)
	viewport.Position = UDim2.fromOffset(24, 82)
	viewport.BackgroundColor3 = C.Track
	viewport.BackgroundTransparency = 0.2
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(205, 205, 210)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-1, -1.5, -0.6)
	viewport.Parent = frame
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local shown = Instance.new("Model")
	shown.Parent = viewport

	-- Built in the held gun's frame (the grip at the origin, the barrel along -Z), so the
	-- muzzle (MeshAssets.getMuzzle) is where PlayerSetup puts the suppressor in a hand.
	local piece = rackPiece(gunId)
	local mesh = piece and piece.PrimaryPart
	local muzzleAt: Vector3? = nil
	local centre = Vector3.zero
	local length = 3
	if mesh and mesh:IsA("MeshPart") then
		local copy = mesh:Clone()
		copy:ClearAllChildren()
		copy.Anchored = true
		copy.CFrame = CFrame.new(MeshAssets.getOffset(weapon.Model))
		copy.Parent = shown
		centre = copy.Position
		length = copy.Size.Z
		muzzleAt = MeshAssets.getMuzzle(weapon.Model) or Vector3.new(0, 0, -copy.Size.Z)
	elseif piece then
		-- Not uploaded yet: the rack's stand-in, laid along -Z (the rack turns it to +X).
		local copy = piece:Clone()
		for _, child in copy:GetDescendants() do
			if child:IsA("BasePart") then
				child.Anchored = true
			end
		end
		local _, size = copy:GetBoundingBox()
		copy:PivotTo(CFrame.Angles(0, math.pi / 2, 0))
		copy.Parent = shown
		length = math.max(size.X, size.Z)
	else
		local missing =
			HudTheme.label(viewport, { text = "SEE IT ON THE RACK", size = 14, color = C.TextDim })
		missing.AnchorPoint = Vector2.new(0.5, 0.5)
		missing.Position = UDim2.fromScale(0.5, 0.5)
	end

	-- The suppressor as it would sit (PlayerSetup's Suppressor part).
	local can: Part? = nil
	local function showFitting()
		if can then
			can:Destroy()
			can = nil
		end
		local spec = weapon.Suppressor
		local option = Config.Attachments.Options[fitted.Barrel or ""]
		local tip = muzzleAt
		if spec and option and tip then
			local part = Instance.new("Part")
			part.Shape = Enum.PartType.Cylinder
			part.Anchored = true
			part.Size = Vector3.new(spec.Length, spec.Width, spec.Width)
			part.CFrame = CFrame.new(tip + Vector3.new(0, 0, -spec.Length / 2))
				* CFrame.Angles(0, math.pi / 2, 0)
			part.Color = option.Color
			part.Material = Enum.Material.Metal
			part.Parent = shown
			can = part
		end
	end
	showFitting()

	-- The camera stands off the gun's right side, close enough that the gun (with room for a
	-- suppressor) spans most of the view's width: FieldOfView is vertical, so widen it by the
	-- view's aspect first.
	local across = math.atan(math.tan(math.rad(FOV / 2)) * VIEW.X / VIEW.Y)
	local reach = (length + 1) / 2 / math.tan(across) * 1.08
	local started = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		local turn = math.sin((os.clock() - started) * 0.5) * 0.45
		local eye = centre
			+ CFrame.Angles(0, turn, 0):VectorToWorldSpace(Vector3.new(reach, reach * 0.18, 0))
		camera.CFrame = CFrame.lookAt(eye, centre + Vector3.new(0, 0, -0.4))
	end)

	-- The slots it takes, each a list: NONE and its options.
	local describe = HudTheme.label(frame, { text = "", size = 13, color = C.Text })
	describe.TextWrapped = true
	describe.AutomaticSize = Enum.AutomaticSize.Y
	describe.Size = UDim2.fromOffset(VIEW.X, 0)
	describe.Position = UDim2.fromOffset(24, 82 + VIEW.Y + 14)

	local painters: { () -> () } = {}
	local function repaint()
		for _, paint in painters do
			paint()
		end
	end
	local x = 24 + VIEW.X + 24
	local y = 82
	local columnWidth = WIDTH - x - 24
	for _, slot in Config.Attachments.Slots do
		local choices = offers[slot]
		if not choices then
			continue
		end
		local title =
			HudTheme.label(frame, { text = string.upper(slot), size = 13, color = C.TextDim })
		title.Position = UDim2.fromOffset(x, y)
		y += 22
		local list: { string } = { "" }
		for _, id in choices do
			table.insert(list, id)
		end
		for _, id in list do
			local option = Config.Attachments.Options[id]
			local button = textButton(
				frame,
				if option then string.upper(option.Name) else "NONE",
				Vector2.new(columnWidth, ROW - 4)
			)
			button.Position = UDim2.fromOffset(x, y)
			button.TextXAlignment = Enum.TextXAlignment.Left
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 10)
			pad.Parent = button
			y += ROW
			button.MouseEnter:Connect(function()
				describe.Text = if option
					then option.Description
					else "Nothing on the " .. string.lower(slot) .. "."
			end)
			button.Activated:Connect(function()
				if id ~= "" then
					fitted[slot] = id
				else
					fitted[slot] = nil
				end
				showFitting()
				repaint()
			end)
			table.insert(painters, function()
				local selected = (fitted[slot] or "") == id
				button.BackgroundColor3 = if selected then C.MenuSelect else C.Track
				button.BackgroundTransparency = if selected then 0 else 0.35
				button.TextColor3 = if selected then C.MenuSelectText else C.Text
			end)
		end
		y += 12
	end
	repaint()

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		spin:Disconnect()
		ContextActionService:UnbindAction(ACTION_BACK)
		cover:Destroy()
	end
	-- Backspace or Escape closes this screen only (bound over the Loadmaster's own Backspace).
	ContextActionService:BindActionAtPriority(
		ACTION_BACK,
		function(_, state)
			if state == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.Backspace,
		Enum.KeyCode.Escape
	)

	local back = textButton(frame, "BACK", Vector2.new(120, 36))
	back.AnchorPoint = Vector2.new(1, 0)
	back.Position = UDim2.new(1, -24, 0, 16)
	back.Activated:Connect(close)

	local confirm = textButton(frame, "DONE", Vector2.new(200, 44))
	confirm.AnchorPoint = Vector2.new(1, 1)
	confirm.Position = UDim2.new(1, -24, 1, -20)
	confirm.BackgroundColor3 = C.MenuSelect
	confirm.BackgroundTransparency = 0
	confirm.TextColor3 = C.MenuSelectText
	confirm.Font = HudTheme.Font.Headline
	confirm.TextSize = 18
	confirm.Activated:Connect(function()
		done(table.clone(fitted))
		close()
	end)

	-- Above the cover: a host whose ScreenGui sorts by Global ZIndex (the Loadmaster's) would
	-- otherwise draw the cover over the panel and give it every click (Nova: "really dark and
	-- none of the buttons worked").
	for _, child in cover:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex += cover.ZIndex
		end
	end

	return close
end

return GunsmithUI
