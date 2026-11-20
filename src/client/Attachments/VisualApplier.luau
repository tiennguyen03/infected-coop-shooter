--!strict
-- Puts a fitting's attachment parts on a gun (attachment visuals, Nova 2026-11-20). Shared by
-- every gun: nothing here names one. For each slot of `fitting` whose option has a model
-- (Shared.Attachments.VisualRegistry) and whose gun has that mount (Shared.Attachments
-- .MountPoints), a copy of the model (ReplicatedStorage.AttachmentMeshes) is turned so its long
-- axis lies the way the registry says, scaled to its length, set against the mount by its
-- anchor face and welded to the gun's Body, in the tool's AttachmentVisuals folder (whose
-- Version attribute FirstPersonView watches). Client side only: the server never renders.
-- The M16A4's optics stay its own meshes (an optic with a Fit for this gun is skipped) and the
-- suppressor stays PlayerSetup's. A missing model or mount is skipped, never an error.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MountPoints = require(ReplicatedStorage.Shared.Attachments.MountPoints)
local Optics = require(ReplicatedStorage.Shared.Attachments.Optics)
local VisualRegistry = require(ReplicatedStorage.Shared.Attachments.VisualRegistry)

local VisualApplier = {}

VisualApplier.FOLDER = "AttachmentVisuals"

local WANT: { [string]: string } = { forward = "Z", down = "Y", side = "X" }

local function longestAxis(size: Vector3): string
	if size.X >= size.Y and size.X >= size.Z then
		return "X"
	end
	return if size.Y >= size.Z then "Y" else "Z"
end

-- The quarter turn that lays local axis `from` along `to` (about the third axis), and the
-- size it then spans in the gun's axes.
local function turn(from: string, to: string, size: Vector3): (CFrame, Vector3)
	if from == to then
		return CFrame.new(), size
	end
	local pair = from .. to
	if pair == "XY" or pair == "YX" then
		return CFrame.Angles(0, 0, math.pi / 2), Vector3.new(size.Y, size.X, size.Z)
	elseif pair == "XZ" or pair == "ZX" then
		return CFrame.Angles(0, math.pi / 2, 0), Vector3.new(size.Z, size.Y, size.X)
	end
	return CFrame.Angles(math.pi / 2, 0, 0), Vector3.new(size.X, size.Z, size.Y)
end

local function offsetFor(anchor: string, spans: Vector3): Vector3
	if anchor == "bottom" then
		return Vector3.new(0, spans.Y / 2, 0)
	elseif anchor == "top" then
		return Vector3.new(0, -spans.Y / 2, 0)
	end
	return Vector3.new(0, 0, -spans.Z / 2) -- back: out along the barrel (-Z)
end

-- Gun `gunId` in `tool` (its Handle the grip, `body` the gun's mesh) wearing `fitting`
-- ([slot] = option id). Replaces whatever it wore before. The parts placed.
function VisualApplier.apply(
	tool: Instance,
	body: BasePart,
	gunId: string,
	fitting: { [string]: string }
): number
	local handle = tool:FindFirstChild("Handle")
	local templates = ReplicatedStorage:FindFirstChild("AttachmentMeshes")
	local folder = tool:FindFirstChild(VisualApplier.FOLDER)
	if not folder then
		local made = Instance.new("Folder")
		made.Name = VisualApplier.FOLDER
		made.Parent = tool
		folder = made
	end
	local into = folder :: Instance
	into:ClearAllChildren()
	local placed = 0
	if handle and handle:IsA("BasePart") and templates then
		for slot, optionId in fitting do
			local entry = VisualRegistry.get(optionId)
			local model = entry and VisualRegistry.MODELS[entry.model]
			local template = entry and templates:FindFirstChild(entry.model)
			local mount = entry and MountPoints.resolve(gunId, slot)
			local legacy = slot == Optics.SLOT and Optics.fit(optionId, gunId) ~= nil
			if
				entry
				and model
				and mount
				and not legacy
				and template
				and template:IsA("BasePart")
			then
				local part = template:Clone()
				local raw = part.Size
				local from = longestAxis(raw)
				local longest = if from == "X" then raw.X elseif from == "Y" then raw.Y else raw.Z
				local scale = model.length / math.max(longest, 1e-3)
				local rotation, spans = turn(from, WANT[model.long], raw * scale)
				part.Size = raw * scale
				local at = (mount.at :: Vector3) + offsetFor(model.anchor, spans)
				part.CFrame = handle.CFrame * CFrame.new(at) * rotation
				part:SetAttribute("Slot", slot)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = part
				weld.Parent = part
				part.Parent = into
				placed += 1
			end
		end
	end
	into:SetAttribute("Version", ((into:GetAttribute("Version") :: number?) or 0) + 1)
	return placed
end

return VisualApplier
