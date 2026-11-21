--!strict
-- Lobby place server bootstrap (lobby.project.json): the Fallow. Starts every system in BOOT
-- order, the same way the match's Main does; the first init() that fails is named in the log
-- and boot stops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating remotes first guarantees clients never wait on a system that hasn't initialized.
require(ReplicatedStorage.Shared.Remotes)

local Shared = ReplicatedStorage.Shared
local Server = script.Parent

local BOOT: { ModuleScript } = {
	Server.CarrierV2, -- registers Carrier v2's kit meshes before MeshAssets builds; places them later
	Server.TallyBoards, -- paints the counted lettering CarrierV2 registers (store + clock)
	Shared.MeshAssets, -- the Pike body's limb meshes (PikeBody)
	Shared.Showcase, -- the Loadmaster's Loadout screen's turning models (LoadoutMenu)
	Server.FallowBuilder,
	Server.PikeBody,
	Server.DeskService,
	Server.PlotService,
	Server.CrewService,
	Server.RecordService,
	Server.TabsService,
	Server.LoadmasterService,
	Server.KitModService, -- after RecordService (ranks are bought onto the record)
	Server.OpticService, -- after RecordService and LoadmasterService (buys onto one, fits through the other)
	Server.AttachmentService, -- attachment system v2 (the same two, the same way)
	Server.AttachmentMeshService, -- the attachment models the EDIT preview shows (VisualApplier)
	Server.LaunchService,
}

local started: { string } = {}
for _, module in BOOT do
	local ok, err = xpcall(function()
		(require(module) :: any).init()
	end, debug.traceback)
	if not ok then
		warn(`[Lobby] started before the failure: {table.concat(started, ", ")}`)
		error(`[Lobby] {module.Name}.init() failed, boot stopped: {err}`, 0)
	end
	table.insert(started, module.Name)
end

print(`[Lobby] The Fallow is up ({#started} systems)`)
