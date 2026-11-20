--!strict
-- The attachment options as typed records (attachment system v2, Nova 2026-11-20): one per
-- row of Config.AttachmentsV2.Options, and the Optic slot's from Config.Optics (each optic's
-- ZoomMultiplier and AdsTimeMultiplier as its deltas). No list of option names lives anywhere:
-- a new option appears by having a row. Rules/AttachmentMerge merges their deltas;
-- Rules/AttachmentUnlock checks unlocks and fits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AttachmentMerge = require(ReplicatedStorage.Shared.Rules.AttachmentMerge)
local Optics = require(script.Parent.Optics)

local Options = {}

export type Option = AttachmentMerge.Option & {
	displayName: string,
	description: string,
	meritCost: number, -- 0: the issued part, always owned
	base: boolean, -- what the slot holds when nothing else is fitted
}

local ROWS: { [string]: Option } = {}

for id, row in Config.AttachmentsV2.Options :: { [string]: any } do
	local deltas: { AttachmentMerge.Delta } = {}
	for _, delta in row.Deltas do
		table.insert(
			deltas,
			{ field = delta.Field, op = delta.Op :: AttachmentMerge.Op, value = delta.Value }
		)
	end
	ROWS[id] = {
		id = id,
		displayName = row.Name,
		description = row.Description,
		slot = row.Slot,
		compatibleGuns = table.clone(row.Guns),
		incompatibleWith = table.clone(row.IncompatibleWith or {}),
		deltas = deltas,
		meritCost = row.Price,
		base = row.Base == true,
	}
end

for id, optic in Optics.Rows :: { [string]: any } do
	local deltas: { AttachmentMerge.Delta } = {
		{ field = "zoom", op = "multiply", value = optic.zoomMultiplier },
		{ field = "adsTime", op = "multiply", value = optic.adsTimeMultiplier },
	}
	ROWS[id] = {
		id = id,
		displayName = optic.displayName,
		description = optic.description,
		slot = Optics.SLOT,
		compatibleGuns = table.clone(optic.compatibleGuns),
		incompatibleWith = {},
		deltas = deltas,
		meritCost = optic.meritCost,
		base = false,
	}
end

Options.Rows = ROWS

function Options.get(id: string?): Option?
	return if id then ROWS[id] else nil
end

-- The delta summary the menu shows ("+15% range, +10% recoil").
local LABELS: { [string]: string } = {
	damage = "damage",
	projectileCount = "rounds per shot",
	headshotMultiplier = "headshot",
	armorPenetration = "armour pen",
	alertRadius = "alert",
	range = "range",
	recoil = "recoil",
	recoilRecovery = "recoil recovery",
	moveSpeed = "move",
	adsTime = "ADS time",
	zoom = "zoom",
	magazineSize = "rounds",
	reloadTime = "reload time",
	hipSpread = "hip spread",
}

function Options.summary(option: Option): string
	local parts: { string } = {}
	for _, delta in option.deltas do
		local label = LABELS[delta.field] or delta.field
		if delta.op == "add" then
			table.insert(parts, string.format("%+d %s", delta.value, label))
		elseif delta.field == "zoom" then
			table.insert(parts, string.format("x%.1f %s", delta.value, label))
		else
			local percent = math.floor((delta.value - 1) * 100 + 0.5)
			if percent ~= 0 then
				table.insert(parts, string.format("%+d%% %s", percent, label))
			end
		end
	end
	return if #parts > 0 then table.concat(parts, ", ") else "As issued"
end

return Options
