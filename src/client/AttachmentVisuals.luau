--!strict
-- Every soldier's gun wears its attachments on this screen (attachment visuals, Nova
-- 2026-11-20): for each player's character, the Rifle tool's gun (PlayerSetup's Body, rebuilt
-- on every swap) gets VisualApplier's parts for the gun in hand (the Weapon attribute) and that
-- player's fitting (the Fitted attribute: the server-signed option ids, already replicated, so
-- no new remote). Redone when the Body, the gun, the fitting or a model arrives. Bots carry no
-- fitting. FirstPersonView copies the parts for this player's own view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local VisualApplier = require(script.Parent.Attachments.VisualApplier)

local AttachmentVisuals = {}

local pending: { [Player]: boolean } = {}

local function refresh(player: Player)
	pending[player] = nil
	local character = player.Character
	local tool = character and character:FindFirstChild("Rifle")
	local body = tool and tool:FindFirstChild("Body")
	if not (tool and body and body:IsA("BasePart")) then
		return
	end
	local gunId = WeaponDefinitions.get(player:GetAttribute(Attributes.Weapon) :: string?).Id
	local text = player:GetAttribute(Attributes.Fitted)
	local fitted = Loadout.decodeFitted(if typeof(text) == "string" then text else "")
	VisualApplier.apply(tool, body, gunId, fitted[gunId] or {})
end

-- Batches the bursts of changes a swap makes (the Body goes and comes back) into one redo.
local function soon(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(refresh, player)
end

local function watchCharacter(player: Player, character: Model)
	local function watchTool(tool: Instance)
		if tool.Name ~= "Rifle" then
			return
		end
		tool.ChildAdded:Connect(function(child)
			if child.Name == "Body" then
				soon(player)
			end
		end)
		soon(player)
	end
	character.ChildAdded:Connect(watchTool)
	for _, child in character:GetChildren() do
		watchTool(child)
	end
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal(Attributes.Weapon):Connect(function()
		soon(player)
	end)
	player:GetAttributeChangedSignal(Attributes.Fitted):Connect(function()
		soon(player)
	end)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		watchCharacter(player, player.Character)
	end
end

function AttachmentVisuals.init()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
	-- A model that arrives late (built on the server after this client joined) redoes everyone.
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("AttachmentMeshes", 30)
		if folder then
			folder.ChildAdded:Connect(function()
				for _, player in Players:GetPlayers() do
					soon(player)
				end
			end)
		end
	end)
end

return AttachmentVisuals
