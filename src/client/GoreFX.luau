--!strict
-- Flesh chunks thrown from a hit on an Infected (dismemberment's small half; GoreService
-- does the limbs on the server). Local only: the hit report goes to the player who landed
-- it (MULTIPLAYER_READINESS #9), so each player sees chunks from their own rounds. The
-- three chunk meshes come from ReplicatedStorage.GorePieces (GoreService copies the
-- server templates there). Numbers: Config.Enemies.Dismember.Chunks.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GoreFX = {}

local alive: { BasePart } = {}
local pieces: Folder? = nil

local function templates(): { BasePart }
	if not pieces then
		local found = ReplicatedStorage:FindFirstChild("GorePieces")
		if found and found:IsA("Folder") then
			pieces = found
		end
	end
	local list = {}
	if pieces then
		for _, child in pieces:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(list, child)
			end
		end
	end
	return list
end

-- `count` chunks from `position`, flung outward and up.
function GoreFX.spray(position: Vector3, count: number)
	local settings = Config.Enemies.Dismember
	if not settings.Enabled or count <= 0 then
		return
	end
	local list = templates()
	if #list == 0 then
		return
	end
	local chunks = settings.Chunks
	local folder = workspace:FindFirstChild("Gore") or workspace
	for _ = 1, count do
		while #alive >= chunks.MaxAlive do
			local oldest = table.remove(alive, 1)
			if oldest then
				oldest:Destroy()
			end
		end
		local chunk = list[math.random(1, #list)]:Clone()
		local spread = Vector3.new(
			math.random() * 2 - 1,
			math.random() * 0.8 + 0.4,
			math.random() * 2 - 1
		).Unit
		chunk.CFrame = CFrame.new(position)
			* CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
		chunk.Parent = folder
		chunk.AssemblyLinearVelocity = spread * chunks.Speed * (0.6 + math.random() * 0.6)
		chunk.AssemblyAngularVelocity =
			Vector3.new(math.random() * 20 - 10, math.random() * 20 - 10, math.random() * 20 - 10)
		table.insert(alive, chunk)
		Debris:AddItem(chunk, chunks.Lifetime)
	end
end

return GoreFX
