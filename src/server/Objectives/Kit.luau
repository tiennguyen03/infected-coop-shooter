--!strict
-- What the objective modules share: code-built props, the world marker, the hold-F prompt,
-- the hold zone, squad distance checks and marked (outlined) Infected. No new meshes: every
-- prop here is a plain Part placed from the site's coordinates (docs/LEVELS.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ObjectiveDefinitions = require(ReplicatedStorage.Shared.ObjectiveDefinitions)
local Types = require(script.Parent.Types)

local Server = script.Parent.Parent
local EnemyService = require(Server.EnemyService)
local Squad = require(Server.Squad)

local Kit = {}

Kit.Yellow = Color3.fromRGB(230, 189, 96) -- places and objectives (STYLES palette)
Kit.Red = Color3.fromRGB(232, 90, 90) -- enemies and alerts
Kit.White = Color3.fromRGB(240, 240, 240)

function Kit.v3(vec: ObjectiveDefinitions.Vec): Vector3
	return Vector3.new(vec[1], vec[2], vec[3])
end

-- An anchored block nothing collides with and no bullet stops at.
function Kit.block(
	folder: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	return part
end

-- An unseen point to hang a prompt or a marker on.
function Kit.point(folder: Instance, name: string, position: Vector3): Part
	local part = Kit.block(folder, name, Vector3.one, CFrame.new(position), Kit.White)
	part.Transparency = 1
	return part
end

-- The world marker over `part`: the context's label ("MAIN OBJECTIVE") and a second line.
-- Seen through walls from Config.Objectives.MarkerDistance.
function Kit.marker(
	part: BasePart,
	context: Types.Context,
	text: string?,
	lift: number?
): BillboardGui
	local marker = Instance.new("BillboardGui")
	marker.Name = "ObjectiveMarker"
	marker.Size = UDim2.fromOffset(240, 44)
	marker.StudsOffset = Vector3.new(0, lift or 5, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = Config.Objectives.MarkerDistance
	for index, line in { context.label, string.upper(text or context.row.Name) } do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, if index == 1 then 16 else 24)
		label.Position = UDim2.fromOffset(0, if index == 1 then 0 else 18)
		label.BackgroundTransparency = 1
		label.Text = line
		label.TextColor3 = if index == 1 then Kit.White else context.color
		label.TextStrokeTransparency = 0.5
		label.TextSize = if index == 1 then 12 else 18
		label.Font = Enum.Font.GothamBold
		label.Parent = marker
	end
	marker.Parent = part
	return marker
end

-- A hold-F prompt on `part` (F is the interact key: MULTIPLAYER_READINESS decision 8).
-- `onTriggered` runs with the living player who finished the hold; letting go starts over.
function Kit.prompt(
	part: BasePart,
	action: string,
	object: string,
	hold: number,
	onTriggered: (player: Player) -> ()
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ObjectivePrompt"
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Triggered:Connect(function(player)
		local member = Squad.fromPlayer(player)
		if member and Squad.isAlive(member) then
			onTriggered(player)
		end
	end)
	prompt.Parent = part
	return prompt
end

-- The glowing hold zone (the same look as the extraction pad's, in objective yellow).
function Kit.zone(folder: Instance, position: Vector3, size: Vector3): Part
	local part = Kit.block(
		folder,
		"ObjectiveZone",
		size,
		CFrame.new(position),
		Color3.fromRGB(255, 220, 0),
		Enum.Material.Neon
	)
	part.Transparency = 0.5
	return part
end

-- Whether a living squad member (player or bot) is within `radius` of `position`.
function Kit.squadNear(position: Vector3, radius: number): boolean
	local _, distance = Squad.nearestLiving(position)
	return distance <= radius
end

-- A flat direction from `position` toward the nearest living member (a crate's face).
function Kit.facing(position: Vector3): Vector3
	local nearest = Squad.nearestLiving(position)
	local root = nearest and nearest.root
	local toward = if root
		then Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
		else Vector3.zAxis
	return if toward.Magnitude > 0.01 then toward.Unit else Vector3.zAxis
end

-- A typed wave in a ring round `center` ({ Walker = 6, Runner = 3 }).
function Kit.wave(wave: { [string]: number }?, center: Vector3)
	local bodies: { [string]: number } = wave or {}
	for typeName, count in bodies do
		EnemyService.spawnWave(typeName, count, center)
	end
end

export type Hunt = {
	total: number,
	left: () -> number,
	-- Takes the outlines off whatever still lives (a timer ran out); they stay in the fight.
	release: () -> (),
}

-- Marked Infected: `count` of `form`, one at each of `points` in turn, each outlined so it
-- reads through walls. A body that could not spawn, or that leaves the world any other way,
-- counts as down, so a hunt can always be finished.
function Kit.hunt(form: string, points: { Vector3 }, count: number): Hunt
	local left = 0
	local marks: { Highlight } = {}
	for index = 1, count do
		local model, humanoid = EnemyService.spawnAt(form, points[((index - 1) % #points) + 1])
		if model and humanoid then
			left += 1
			local mark = Instance.new("Highlight")
			mark.Name = "ObjectiveMark"
			mark.FillTransparency = 1
			mark.OutlineColor = Kit.Red
			mark.OutlineTransparency = 0
			mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			mark.Parent = model
			table.insert(marks, mark)
			local counted = false
			local function down()
				if not counted then
					counted = true
					left -= 1
					mark:Destroy()
				end
			end
			humanoid.Died:Connect(down)
			model.AncestryChanged:Connect(function(_, parent)
				if parent == nil then
					down()
				end
			end)
		end
	end
	return {
		total = count,
		left = function()
			return left
		end,
		release = function()
			for _, mark in marks do
				mark:Destroy()
			end
		end,
	}
end

return Kit
