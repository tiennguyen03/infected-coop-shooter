--!strict
-- Breaching rounds open walls (Rules/WallBreach; Config.WallBreach; the Mossberg's breaching
-- shell, Nova 2026-11-20). ProjectileServer calls hit() where a breaching round stops on a
-- part. A light building wall takes the gun's breachPower; at Toughness a door-sized hole opens
-- from its foot at the hit: the wall is lifted out and up to three pieces of it (copies, so
-- material, colour and textures match) stand where the rest of it was. A piece is a wall too,
-- so it can be opened again. Every broken wall is put back at the next run's start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WallBreach = require(ReplicatedStorage.Shared.Rules.WallBreach)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

local WallBreachService = {}

type Broken = { original: BasePart, parent: Instance, pieces: { BasePart } }

local broken: { Broken } = {}
local pieceOf: { [BasePart]: Broken? } = {}
local damageOf: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any

local S: WallBreach.Settings = Config.WallBreach :: any

-- A breaching round of `power` stopped on `part` at `position`: whether it opened a wall.
function WallBreachService.hit(part: BasePart, power: number, position: Vector3): boolean
	if not part:IsA("Part") or not part.Anchored then
		return false
	end
	local size = part.Size
	local alongX = size.X >= size.Z
	local thickness = if alongX then size.Z else size.X
	if not WallBreach.breakable(part.Name, thickness, part.Material.Name, S) then
		return false
	end
	local damage, opened = WallBreach.struck(damageOf[part] or 0, power, S.Toughness)
	WorldSounds.at(position, "player_gear", "breach")
	if not opened then
		damageOf[part] = damage -- cracked: the next breaching hit opens it
		return false
	end
	damageOf[part] = nil
	local parent = part.Parent
	if not parent then
		return false
	end

	local hit = part.CFrame:PointToObjectSpace(position)
	local pieces = WallBreach.cut(
		if alongX then size.X else size.Z,
		size.Y,
		if alongX then hit.X else hit.Z,
		S
	)
	local frame = part.CFrame
	local template = part:Clone()
	local record: Broken
	local earlier = pieceOf[part]
	if earlier then
		-- A piece of a wall already open: it goes for good, its own pieces join the record.
		record = earlier
		pieceOf[part] = nil
		local index = table.find(record.pieces, part)
		if index then
			table.remove(record.pieces, index)
		end
		part:Destroy()
	else
		record = { original = part :: BasePart, parent = parent, pieces = {} }
		table.insert(broken, record)
		part.Parent = nil
	end
	for _, cut in pieces do
		local u, y = (cut.u0 + cut.u1) / 2, (cut.y0 + cut.y1) / 2
		local piece = template:Clone()
		piece.Size = if alongX
			then Vector3.new(cut.u1 - cut.u0, cut.y1 - cut.y0, size.Z)
			else Vector3.new(size.X, cut.y1 - cut.y0, cut.u1 - cut.u0)
		piece.CFrame = frame * (if alongX then CFrame.new(u, y, 0) else CFrame.new(0, y, u))
		-- Its textures carry on where the wall's left off (no seam at the hole).
		for _, child in piece:GetChildren() do
			if child:IsA("Texture") then
				child.OffsetStudsU += cut.u0 + (if alongX then size.X else size.Z) / 2
				child.OffsetStudsV += cut.y0 + size.Y / 2
			end
		end
		piece.Parent = parent
		table.insert(record.pieces, piece)
		pieceOf[piece] = record
	end
	template:Destroy()
	return true
end

-- Every broken wall back as it was built.
function WallBreachService.reset()
	for _, record in broken do
		for _, piece in record.pieces do
			pieceOf[piece] = nil
			piece:Destroy()
		end
		if record.parent:IsDescendantOf(game) then
			record.original.Parent = record.parent
		else
			record.original:Destroy() -- its building was rebuilt
		end
	end
	table.clear(broken)
end

function WallBreachService.init()
	Lifecycle.register("WallBreachService", { onRunStart = WallBreachService.reset })
end

return WallBreachService
