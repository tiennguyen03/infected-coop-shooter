--!strict
-- Misdrop (shared side objective): a supply pallet lies in an outer area. A living squad
-- member (player or bot) who gets within row.ReachRadius before row.Seconds run out opens
-- it: a supply crate with each player's cards (RequisitionService.dropCrate), which is the
-- reward. Too late and the pallet is gone; nothing else is lost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Rules = require(ReplicatedStorage.Shared.Rules.Objectives)
local Kit = require(script.Parent.Kit)
local Types = require(script.Parent.Types)

local Server = script.Parent.Parent
local RequisitionService = require(Server.RequisitionService)

local Misdrop = {}

function Misdrop.new(context: Types.Context): Types.Objective
	local row = context.row
	local ground = GroundUtil.GetGroundPosition(context.position, 0)
	local timeLeft = row.Seconds or 240
	local open = true

	local pallet: BasePart = MeshAssets.clone("prop_ammo_crate") or Instance.new("Part")
	pallet.Name = "MisdropPallet"
	if pallet:IsA("Part") then
		pallet.Size = Vector3.new(3.2, 2, 2.4)
		pallet.Material = Enum.Material.Metal
		pallet.Color = Color3.fromRGB(107, 122, 74)
	end
	pallet.CFrame = CFrame.new(ground + Vector3.new(0, pallet.Size.Y / 2, 0))
	pallet.Anchored = true
	pallet.CanCollide = false
	pallet.CanQuery = false
	pallet.CanTouch = false
	pallet.Parent = context.folder
	Kit.marker(pallet, context, nil, 5)

	return {
		begin = function() end,
		step = function(deltaTime: number)
			if not open then
				return
			end
			if Kit.squadNear(ground, row.ReachRadius or 10) then
				open = false
				pallet:Destroy()
				task.spawn(
					RequisitionService.dropCrate,
					ground,
					Kit.facing(ground),
					"supply" :: RequisitionService.CrateKind,
					false,
					true
				)
				context.complete()
				return
			end
			timeLeft = Rules.countdown(timeLeft, deltaTime)
			if timeLeft <= 0 then
				open = false
				pallet:Destroy()
				context.fail()
			end
		end,
		progress = function(): Types.Progress
			return {
				step = "Reach the pallet before the Infected do",
				done = 0,
				total = 0,
				unit = "",
				timeLeft = timeLeft,
			}
		end,
		position = function()
			return ground
		end,
		cleanup = function() end,
	}
end

return Misdrop
