--!strict
-- Part helpers for the Fallow: every piece of the ship is a plain anchored Part built from
-- code (no meshes yet; the art director's build sheet replaces the blocks later), so disk
-- stays the single source of truth.

local Build = {}

export type PartOptions = {
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?,
	shape: Enum.PartType?,
	wedge: boolean?,
}

function Build.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	options: PartOptions?
): BasePart
	local opts: PartOptions = options or {}
	local part: BasePart
	if opts.wedge then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		block.Shape = opts.shape or Enum.PartType.Block
		part = block
	end
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = opts.material or Enum.Material.Metal
	part.Transparency = opts.transparency or 0
	part.CanCollide = if opts.collide == nil then true else opts.collide
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A box from two opposite corners (min, max), handy for walls laid out on a plan.
function Build.box(
	parent: Instance,
	name: string,
	min: Vector3,
	max: Vector3,
	color: Color3,
	options: PartOptions?
): BasePart
	return Build.part(parent, name, max - min, CFrame.new((min + max) / 2), color, options)
end

-- An invisible wall that keeps soldiers on the ship.
function Build.barrier(parent: Instance, min: Vector3, max: Vector3): BasePart
	return Build.box(parent, "Barrier", min, max, Color3.new(), { transparency = 1 })
end

export type TextOptions = {
	size: number?, -- TextSize
	color: Color3?,
	font: Enum.Font?,
	pixelsPerStud: number?,
}

-- Lettering painted or stencilled on one face of a part.
function Build.text(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	options: TextOptions?
): TextLabel
	local opts: TextOptions = options or {}
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.pixelsPerStud or 20
	gui.LightInfluence = 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = opts.color or Color3.fromRGB(214, 214, 208)
	label.Font = opts.font or Enum.Font.GothamBlack
	-- World lettering shrinks to fit its face (a HUD label never scales; paint on a hull can).
	label.TextScaled = true
	label.TextWrapped = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = opts.size or 100
	limit.Parent = label
	label.Parent = gui
	return label
end

-- A short label floating over something (desk titles, spot numbers).
function Build.sign(adornee: BasePart, text: string, sub: string?, offsetY: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = adornee
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.6)
	title.Text = text
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(230, 189, 96)
	title.TextStrokeTransparency = 0.5
	title.Parent = gui
	if sub then
		local line = Instance.new("TextLabel")
		line.BackgroundTransparency = 1
		line.Position = UDim2.fromScale(0, 0.6)
		line.Size = UDim2.fromScale(1, 0.4)
		line.Text = sub
		line.Font = Enum.Font.GothamBold
		line.TextSize = 15
		line.TextColor3 = Color3.fromRGB(240, 240, 240)
		line.TextStrokeTransparency = 0.5
		line.Parent = gui
	end
	return gui
end

function Build.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

return Build
