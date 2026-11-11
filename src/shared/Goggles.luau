--!strict
-- The night vision goggles on the soldier's helmet (Nova, 2026-11-11: "i want the goggle to
-- visually flip down"; Config.NightVision.Goggles). The goggles are their own catalog
-- accessory, modelled lowered over the eyes; they turn about a hinge on the helmet's mount
-- (Pivot, in the head's space) by driving the accessory's weld. The server fits them when a
-- body is dressed (AvatarLook: raised, which every client sees); client NightVision animates
-- them down and up from each character's NightVision attribute.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)

local Goggles = {}

Goggles.TAG = "NightGoggles" -- CollectionService tag on the goggles accessory

local G = Config.NightVision.Goggles

local function weldOf(accessory: Instance): (Weld?, BasePart?)
	local handle = accessory:FindFirstChild("Handle")
	local weld = handle and handle:FindFirstChild("AccessoryWeld")
	if handle and handle:IsA("BasePart") and weld and weld:IsA("Weld") then
		return weld, handle
	end
	return nil, nil
end

-- Puts the goggles at `raised` (0 lowered over the eyes, 1 folded up on the mount).
function Goggles.pose(accessory: Instance, raised: number)
	local weld, handle = weldOf(accessory)
	local base = accessory:GetAttribute(Attributes.GoggleBase)
	if not weld or typeof(base) ~= "CFrame" then
		return
	end
	local pivot = CFrame.new(G.Pivot)
	local frame = pivot
		* CFrame.Angles(math.rad(G.RaisedAngle) * raised, 0, 0)
		* pivot:Inverse()
		* base
	-- Part0.CFrame * C0 == Part1.CFrame * C1; the head is the other part.
	if weld.Part0 == handle then
		weld.C0 = CFrame.identity
		weld.C1 = frame
	else
		weld.C0 = frame
		weld.C1 = CFrame.identity
	end
end

-- Server: finds the goggles on a dressed body (by their mesh), hinges them and stows them.
function Goggles.fit(model: Model)
	for _, accessory in model:GetChildren() do
		if not accessory:IsA("Accessory") then
			continue
		end
		local weld, handle = weldOf(accessory)
		if not weld or not handle or not handle:IsA("MeshPart") or handle.MeshId ~= G.MeshId then
			continue
		end
		-- The handle's frame in the head's space, as modelled.
		local base = if weld.Part0 == handle
			then weld.C1 * weld.C0:Inverse()
			else weld.C0 * weld.C1:Inverse()
		accessory:SetAttribute(Attributes.GoggleBase, base)
		-- The weld alone holds the goggles, so moving it moves them.
		local rigid = handle:FindFirstChild("AccessoryRigidConstraint")
		if rigid and rigid:IsA("RigidConstraint") then
			rigid.Enabled = false
		end
		weld.Enabled = true
		accessory:AddTag(Goggles.TAG)
		Goggles.pose(accessory, 1)
	end
end

return Goggles
