--!strict
-- Recover the Record (shared main objective): a ledger at the site; a player holds E to
-- pick it up and carries it on their back to the site's `To` point. The carrier cannot
-- sprint (the Carrying attribute, read by SprintController). Downed, dead or gone, the
-- carrier drops it where they stood and anyone can pick it up again. Carrying is for
-- players only: bots escort the carrier (they follow their leader) and never pick it up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Kit = require(script.Parent.Kit)
local Types = require(script.Parent.Types)

local Server = script.Parent.Parent
local Squad = require(Server.Squad)

local RecoverRecord = {}

local RECORD_SIZE = Vector3.new(1.4, 0.4, 1.8)
local RECORD_COLOR = Color3.fromRGB(232, 222, 196)

function RecoverRecord.new(context: Types.Context): Types.Objective
	local row, site = context.row, context.site
	local from = context.position
	local to = Kit.v3(site.To or site.Position)
	local toName = site.ToName or site.Name
	local deliverRadius = row.DeliverRadius or 9

	local record: Part = nil :: any
	local carrier: Player? = nil
	local weld: WeldConstraint? = nil
	local rest = from -- where the record lies, or where the carrier last stood
	local delivered = false

	local goal = Kit.point(context.folder, "RecordGoal", to)
	local goalMarker = Kit.marker(goal, context, "Bring the record here", 6)
	goalMarker.Enabled = false

	local function release()
		local player = carrier
		carrier = nil
		if weld then
			weld:Destroy()
			weld = nil
		end
		if player then
			player:SetAttribute(Attributes.Carrying, nil)
		end
	end

	-- The floor under where the carrier stood (a short cast from the body, so a record
	-- dropped indoors or under the bridge stays on that floor, not on the roof above).
	local function floorUnder(position: Vector3, player: Player?): Vector3
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { context.folder }
		for _, member in Squad.members() do
			if member.character then
				table.insert(ignore, member.character)
			end
		end
		if player and player.Character then
			table.insert(ignore, player.Character)
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(position, Vector3.new(0, -12, 0), params)
		local floor = if hit then hit.Position.Y else position.Y - 3
		return Vector3.new(position.X, floor + RECORD_SIZE.Y / 2 + 0.05, position.Z)
	end

	local take: (player: Player) -> ()

	-- Lays the record at `position` with its prompt and marker (a fresh one if it was lost).
	local function lay(position: Vector3)
		release()
		if record and record.Parent then
			record:Destroy()
		end
		rest = position
		record = Kit.block(
			context.folder,
			"ScreeningRecord",
			RECORD_SIZE,
			CFrame.new(position),
			RECORD_COLOR,
			Enum.Material.SmoothPlastic
		)
		Kit.marker(record, context, "The screening record", 4)
		Kit.prompt(record, "Pick up", "Screening record", row.Hold or 1, function(player)
			take(player)
		end)
		goalMarker.Enabled = false
	end

	take = function(player: Player)
		local character = player.Character
		local torso = character
			and (
				character:FindFirstChild("UpperTorso")
				or character:FindFirstChild("Torso")
				or character:FindFirstChild("HumanoidRootPart")
			)
		if carrier or delivered or not torso or not torso:IsA("BasePart") then
			return
		end
		carrier = player
		for _, child in record:GetChildren() do
			child:Destroy() -- its prompt and its marker: the goal's marker takes over
		end
		record.Anchored = false
		record.Massless = true
		record.CFrame = torso.CFrame * CFrame.new(0, 0, 0.9) * CFrame.Angles(math.rad(90), 0, 0)
		local joint = Instance.new("WeldConstraint")
		joint.Part0 = torso
		joint.Part1 = record
		joint.Parent = record
		weld = joint
		player:SetAttribute(Attributes.Carrying, true)
		goalMarker.Enabled = true
	end

	lay(from)

	return {
		begin = function() end,
		step = function()
			if delivered then
				return
			end
			local player = carrier
			if not player then
				-- On the ground. Lost (fell out of the world, destroyed): back where it lay.
				if not record.Parent or record.Position.Y < -40 then
					lay(rest)
				end
				return
			end
			local member = Squad.fromPlayer(player)
			local root = member and member.root
			if not member or not root or not Squad.isAlive(member) or not player.Parent then
				lay(floorUnder(rest, player))
				return
			end
			rest = root.Position
			if not record.Parent then
				lay(floorUnder(rest, player))
				return
			end
			if (root.Position - to).Magnitude <= deliverRadius then
				delivered = true
				release()
				record:Destroy()
				goalMarker:Destroy()
				context.complete()
			end
		end,
		progress = function(): Types.Progress
			local player = carrier
			local step = if player
				then `{Squad.callsign(player)} has the record: carry it to {toName} (no sprint)`
				else `Hold {Kit.InteractLabel} to pick up the screening record`
			return { step = step, done = 0, total = 0, unit = "" }
		end,
		position = function()
			if carrier then
				return to
			end
			return rest
		end,
		cleanup = function()
			release()
		end,
	}
end

return RecoverRecord
