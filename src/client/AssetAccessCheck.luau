--!strict
-- Studio only: checks that every uploaded sound and animation the game uses can load in this
-- place, then prints one summary line. Roblox loads audio and animations only in games owned
-- by the account that uploaded them, or in games that were granted access, so a collaborator
-- working in a place of their own hears no sounds and sees no clips, with nothing in the game
-- saying why. This check says why. The setup that fixes it: docs/COLLABORATING.md.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SoundBanks = require(Shared:WaitForChild("SoundBanks"))
local SoundFX = require(script.Parent.SoundFX)

local AssetAccessCheck = {}

-- Seconds after boot before the check runs, so it does not compete with the first spawn.
local DELAY = 3
-- How many failed names the summary lists before "and N more".
local LIST_LIMIT = 6

type Entry = { kind: string, name: string, id: string } -- kind: "sound" | "animation"

local function entries(): { Entry }
	local list: { Entry } = {}
	for bank, id in SoundBanks.ids() do
		table.insert(list, { kind = "sound", name = `{bank} bank`, id = id })
	end
	for name, id in SoundFX.uploadedIds() do
		table.insert(list, { kind = "sound", name = name, id = id })
	end
	-- Config.Animations.Ids is a sealed table, which iterates as unknown; read it as a map.
	local ids: { [string]: string } = Config.Animations.Ids :: any
	for clip, id in ids do
		if string.sub(id, 1, 13) == "rbxassetid://" then
			table.insert(list, { kind = "animation", name = clip, id = id })
		end
	end
	return list
end

local function run()
	local list = entries()
	local byId: { [string]: Entry } = {}
	local instances: { Instance } = {}
	for _, entry in list do
		byId[entry.id] = entry
		if entry.kind == "sound" then
			local sound = Instance.new("Sound")
			sound.SoundId = entry.id
			table.insert(instances, sound)
		else
			local animation = Instance.new("Animation")
			animation.AnimationId = entry.id
			table.insert(instances, animation)
		end
	end

	local failed: { Entry } = {}
	local totals: { [string]: number } = { sound = 0, animation = 0 }
	local misses: { [string]: number } = { sound = 0, animation = 0 }
	for _, entry in list do
		totals[entry.kind] += 1
	end
	local function onFetched(contentId: string, status: Enum.AssetFetchStatus)
		local entry = byId[contentId]
		if not entry then
			return
		end
		if status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut then
			misses[entry.kind] += 1
			table.insert(failed, entry)
		end
	end
	ContentProvider:PreloadAsync(instances, onFetched)
	for _, instance in instances do
		instance:Destroy()
	end

	if #failed == 0 then
		print(`[AssetAccess] all {#list} uploaded sounds and animations load in this place`)
		return
	end
	local names = {}
	for index, entry in failed do
		if index > LIST_LIMIT then
			table.insert(names, `and {#failed - LIST_LIMIT} more`)
			break
		end
		table.insert(names, entry.name)
	end
	local sounds = `{misses.sound} of {totals.sound} sounds`
	local clips = `{misses.animation} of {totals.animation} animations`
	local missing = table.concat(names, ", ")
	warn(`[AssetAccess] {sounds} and {clips} cannot load in this place ({missing}).`)
	warn("[AssetAccess] Roblox loads audio and animations only in the uploader's games or in")
	warn("[AssetAccess] games granted access. Setup without a group: docs/COLLABORATING.md")
end

function AssetAccessCheck.init()
	if not RunService:IsStudio() then
		return
	end
	task.delay(DELAY, function()
		local ok, err = pcall(run)
		if not ok then
			warn(`[AssetAccess] check failed to run: {err}`)
		end
	end)
end

return AssetAccessCheck
