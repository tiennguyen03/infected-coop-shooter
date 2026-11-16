--!strict
-- The helicopter for the insertion cutscene (Config.Insertion; client InsertionCutscene flies
-- it). A mesh's id cannot be set at run time on a client, so the server assembles the Lantern
-- once from the uploaded meshes (MeshAssets templates: body, trim, main and tail rotor, the
-- same four the lobby's LanternBird wears) into ReplicatedStorage.InsertLantern, built around
-- its own frame (origin on the deck at the mast foot, nose toward -Z). Every client clones it
-- and moves its own copy, so the flight is smooth for everyone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)

local InsertionService = {}

local WAIT = 30 -- seconds to wait for the mesh templates at boot
local ROTOR_REST = math.rad(20) -- the blades sit off the boom's line (LanternBird)

local function build()
	local settings = Config.Insertion
	local model = Instance.new("Model")
	model.Name = "InsertLantern"
	local function place(meshName: string, partName: string, frame: CFrame): MeshPart?
		local part = MeshAssets.waitFor(meshName, WAIT)
		if not part then
			warn(`[InsertionService] {meshName} did not load; the cutscene flies without it`)
			return nil
		end
		part.Name = partName
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = frame * CFrame.new(MeshAssets.getOffset(meshName))
		part.Parent = model
		return part
	end
	local body = place("veh_lantern_body", "Body", CFrame.identity)
	place("veh_lantern_trim", "Trim", CFrame.identity)
	place("veh_lantern_rotor", "Rotor", CFrame.new(settings.Hub) * CFrame.Angles(0, ROTOR_REST, 0))
	place("veh_lantern_tail_rotor", "TailRotor", CFrame.new(settings.TailHub))
	if not body then
		model:Destroy()
		return
	end
	model.PrimaryPart = body
	model.Parent = ReplicatedStorage
end

function InsertionService.init()
	if Config.Insertion.Enabled then
		task.spawn(build)
	end
end

return InsertionService
