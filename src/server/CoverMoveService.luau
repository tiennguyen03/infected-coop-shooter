--!strict
-- CoverMoveService: the client runs the vault/climb/roll (MovementController) and reports it
-- with the CoverMove remote. The server opens a short window, stored on the character as
-- the "CoverMoveUntil" attribute (server os.clock), in which Infected melee skips that body
-- (EnemyService.attackIfTouching). Ranged attacks still land. Windows are capped at the
-- configured move duration and can't be chained without a gap, so the remote can't buy
-- standing immunity. State is per player and dropped on PlayerRemoving. Every move (and a
-- slide, which buys no window) drops a reload in progress (LoadoutService.cancelReload).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local LoadoutService = require(script.Parent.LoadoutService)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

local CoverMoveService = {}

local windowEnds: { [Player]: number } = {}

local function onCoverMove(player: Player, kind: unknown)
	if
		kind ~= Messages.CoverMove.Vault
		and kind ~= Messages.CoverMove.Climb
		and kind ~= Messages.CoverMove.Roll
		and kind ~= Messages.CoverMove.Slide
	then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	LoadoutService.cancelReload(player)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local group = if kind == Messages.CoverMove.Vault
				or kind == Messages.CoverMove.Climb
			then "vault"
			else "roll"
		WorldSounds.on(root, "player_gear", group, "Move")
	end
	if kind == Messages.CoverMove.Slide then
		return
	end
	local settings = Config.Movement
	local now = os.clock()
	local lastEnd = windowEnds[player]
	if lastEnd and now < lastEnd + settings.CoverImmunity.Cooldown then
		return
	end
	local duration = if kind == Messages.CoverMove.Vault
		then settings.VaultDuration
		elseif kind == Messages.CoverMove.Roll then settings.Roll.Duration
		else settings.ClimbDuration
	local ends = now + duration + settings.CoverImmunity.Grace
	windowEnds[player] = ends
	character:SetAttribute(Attributes.CoverMoveUntil, ends)
end

function CoverMoveService.init()
	Lifecycle.register("CoverMoveService", {
		onPlayerRemoving = function(player: Player)
			windowEnds[player] = nil
		end,
	})
	Remotes.get("CoverMove").OnServerEvent:Connect(onCoverMove)
end

return CoverMoveService
