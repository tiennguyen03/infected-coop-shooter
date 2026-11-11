--!strict
-- The night vision goggles on the soldier's helmet (Nova, 2026-11-11: "i want the goggle to
-- visually flip down"; Config.NightVision.Goggles). The goggles are their own catalog
-- accessory, modelled lowered over the eyes; they turn about a hinge on the helmet's mount
-- (Pivot, in the head's space) by moving the attachment that holds them. The server fits them when a
-- body is dressed (AvatarLook: raised, which every client sees); client NightVision animates
-- them down and up from each character's NightVision attribute.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)

local Goggles = {}

Goggles.TAG = "NightGoggles" -- CollectionService tag on the goggles accessory

local G = Config.NightVision.Goggles

-- The goggles' attachment and the head's matching one. Roblox holds an accessory by these two
-- (Handle.HatAttachment to Head.HatAttachment): in play through a RigidConstraint it adds when the
-- body enters the world, outside play (a rig being built) through an AccessoryWeld as well.
local function anchorsOf(accessory: Instance): (Attachment?, Attachment?, BasePart?)
	local handle = accessory:FindFirstChild("Handle")
	local body = accessory.Parent
	local head = body and body:FindFirstChild("Head")
	if not handle or not handle:IsA("BasePart") or not head then
		return nil, nil, nil
	end
	for _, child in handle:GetChildren() do
		if child:IsA("Attachment") then
			local onHead = head:FindFirstChild(child.Name)
			if onHead and onHead:IsA("Attachment") then
				return child, onHead, handle
			end
		end
	end
	return nil, nil, nil
end

-- Puts the goggles at `raised` (0 lowered over the eyes, 1 folded up on the mount): moves the
-- goggles' own attachment (whatever holds them follows) and any weld to match.
function Goggles.pose(accessory: Instance, raised: number)
	local own, onHead, handle = anchorsOf(accessory)
	local base = accessory:GetAttribute(Attributes.GoggleBase)
	if not own or not onHead or not handle or typeof(base) ~= "CFrame" then
		return
	end
	local pivot = CFrame.new(G.Pivot)
	local frame = pivot
		* CFrame.Angles(math.rad(G.RaisedAngle) * raised, 0, 0)
		* pivot:Inverse()
		* base
	-- Head * onHead == Handle * own, with Handle == Head * frame.
	own.CFrame = frame:Inverse() * onHead.CFrame
	local weld = handle:FindFirstChild("AccessoryWeld")
	if weld and weld:IsA("Weld") then
		-- Part0.CFrame * C0 == Part1.CFrame * C1; the head is the other part.
		if weld.Part0 == handle then
			weld.C0 = CFrame.identity
			weld.C1 = frame
		else
			weld.C0 = frame
			weld.C1 = CFrame.identity
		end
	end
end

-- Server: finds the goggles on a dressed body (by their mesh), records how they were modelled
-- and stows them.
function Goggles.fit(model: Model)
	for _, accessory in model:GetChildren() do
		if not accessory:IsA("Accessory") then
			continue
		end
		local own, onHead, handle = anchorsOf(accessory)
		if
			not own
			or not onHead
			or not handle
			or not handle:IsA("MeshPart")
			or handle.MeshId ~= G.MeshId
		then
			continue
		end
		if accessory:GetAttribute(Attributes.GoggleBase) == nil then
			-- The handle's frame in the head's space, as modelled.
			accessory:SetAttribute(Attributes.GoggleBase, onHead.CFrame * own.CFrame:Inverse())
		end
		accessory:AddTag(Goggles.TAG)
		Goggles.pose(accessory, 1)
	end
end

return Goggles
