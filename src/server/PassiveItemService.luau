--!strict
-- Common Item Pack 1 (Sprint 15): recomputes passive bonuses from owned
-- items whenever the inventory changes. Stat items go through
-- PlayerStatsService; the rest publish player attributes that the relevant
-- systems read (XPGainMult, OrbMagnetMult, IncomingDamageMult,
-- DroneRangeMult, DroneDurationMult, HunterMarkRangeMult). MaxHP and
-- level-up healing are applied directly. Also owns automatic level growth
-- (Config.Progression): each level adds max HP and bullet damage, no draft.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemService = require(script.Parent.ItemService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local XPService = require(script.Parent.XPService)

local PassiveItemService = {}

-- Tracks the max-HP bonus we've applied so we adjust by delta (coexists with
-- Kevlar / AmmoCache shields that also touch MaxHealth).
local rationsApplied: { [Player]: number } = {}

local function stacks(player: Player, id: string): number
	return ItemService.getStacks(player, id)
end

function PassiveItemService.recompute(player: Player)
	local p = Config.Items.Passives

	PlayerStatsService.setBonus(player, "passives", {
		Damage = stacks(player, "high_grain_powder") * p.HighGrainPowder,
		FireRate = stacks(player, "combat_stimulants") * p.CombatStimulants,
		MoveSpeed = stacks(player, "lightweight_boots") * p.LightweightBoots,
	})

	player:SetAttribute("XPGainMult", stacks(player, "field_manual") * p.FieldManual)
	player:SetAttribute("OrbMagnetMult", stacks(player, "scavenger_pouch") * p.ScavengerPouch)
	player:SetAttribute(
		"IncomingDamageMult",
		1 - math.min(stacks(player, "ballistic_weave") * p.BallisticWeave, p.BallisticWeaveCap)
	)
	player:SetAttribute("DroneRangeMult", stacks(player, "signal_antenna") * p.SignalAntenna)
	player:SetAttribute("HunterMarkRangeMult", stacks(player, "signal_antenna") * p.SignalAntenna)
	player:SetAttribute(
		"DroneDurationMult",
		stacks(player, "cheap_drone_parts") * p.CheapDroneParts
	)

	-- Max HP: apply only the delta so shields aren't clobbered.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local target = stacks(player, "military_rations") * p.MilitaryRations
		local delta = target - (rationsApplied[player] or 0)
		if delta ~= 0 then
			humanoid.MaxHealth = math.max(humanoid.MaxHealth + delta, 1)
			if delta > 0 then
				humanoid.Health += delta
			else
				humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
			end
			rationsApplied[player] = target
		end
	end
end

-- Level growth (up to MaxLevel) and Field Dressing's heal on each level gained.
local function onLevelUp(player: Player, newLevel: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local growth = Config.Progression
	if newLevel <= growth.MaxLevel then
		PlayerStatsService.setBonus(player, "level", {
			Damage = (newLevel - 1) * growth.DamagePerLevel,
		})
		if humanoid and humanoid.Health > 0 then
			humanoid.MaxHealth += growth.HealthPerLevel
			humanoid.Health += growth.HealthPerLevel
		end
	end

	local count = stacks(player, "field_dressing")
	if count > 0 and humanoid and humanoid.Health > 0 then
		local heal = count * Config.Items.Passives.FieldDressing
		humanoid.Health = math.min(humanoid.Health + heal, humanoid.MaxHealth)
	end
end

function PassiveItemService.resetPlayer(player: Player)
	rationsApplied[player] = nil
	player:SetAttribute("XPGainMult", 0)
	player:SetAttribute("OrbMagnetMult", 0)
	player:SetAttribute("IncomingDamageMult", 1)
	player:SetAttribute("DroneRangeMult", 0)
	player:SetAttribute("HunterMarkRangeMult", 0)
	player:SetAttribute("DroneDurationMult", 0)
end

function PassiveItemService.init()
	ItemService.setInventoryChangedHandler(function(player: Player)
		PassiveItemService.recompute(player)
	end)
	XPService.addLevelUpListener(onLevelUp)

	Players.PlayerRemoving:Connect(function(player)
		rationsApplied[player] = nil
	end)
end

return PassiveItemService
