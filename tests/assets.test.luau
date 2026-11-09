-- Names that tie the animation and sound tables together. A typo in any of them leaves a clip
-- or a sound silently missing in game, and no type checker sees it.

local Shared = require("./lib/shared")
local Source = require("./lib/source")

local function isAssetId(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	return value == "" or string.match(value, "^rbxassetid://%d+$") ~= nil
end

-- Every string under `node` must be a clip name in Config.Animations.Ids.
local function checkClipNames(t, node: any, path: string, ids: { [string]: string })
	if type(node) == "string" then
		t.check(ids[node] ~= nil, `{path} names unknown clip "{node}"`)
	elseif type(node) == "table" then
		for key, value in node do
			checkClipNames(t, value, `{path}.{tostring(key)}`, ids)
		end
	end
end

local function checkAnimations(t, Config, EnemyDefinitions)
	local animations = Config.Animations
	local ids = animations.Ids
	for clip, id in ids do
		t.check(isAssetId(id), `Config.Animations.Ids.{clip} is not an rbxassetid:// id or ""`)
	end
	checkClipNames(t, animations.Assault, "Config.Animations.Assault", ids)
	for form, clips in animations.Infected do
		local at = `Config.Animations.Infected.{form}`
		t.check(EnemyDefinitions[form] ~= nil, `{at} is not an Infected form`)
		checkClipNames(t, clips, at, ids)
	end
	for clip in animations.MoveClipSpeed do
		t.check(ids[clip] ~= nil, `Config.Animations.MoveClipSpeed.{clip} is not a clip`)
	end
end

local function checkSounds(t, Config, SoundBankData)
	-- A group is a clip name without its _<n> suffix (SoundBanks.groupOf).
	local groups = {}
	for _, clips in SoundBankData do
		for clip in clips do
			groups[string.match(clip, "^(.-)_%d+$") or clip] = true
		end
	end
	for group in Config.Audio.Volumes do
		t.check(groups[group] == true, `Config.Audio.Volumes.{group} is not a sound group`)
	end

	-- Every generated bank has an uploaded id in SoundBanks, and every id has a bank.
	local text = Source.read("src/shared/SoundBanks.luau")
	local block = string.match(text, "local IDS: [^=]+= (%b{})") or ""
	local listed = {}
	for bank, id in string.gmatch(block, '([%w_]+) = "([^"]*)"') do
		listed[bank] = true
		t.check(isAssetId(id), `SoundBanks IDS.{bank} is not an rbxassetid:// id or ""`)
		t.check(SoundBankData[bank] ~= nil, `SoundBanks IDS.{bank} has no generated bank`)
	end
	t.check(next(listed) ~= nil, "found no bank ids in SoundBanks.luau (IDS table moved?)")
	for bank in SoundBankData do
		t.check(listed[bank] == true, `generated bank {bank} has no entry in SoundBanks IDS`)
	end
end

return function(t)
	local Config = Shared.require("Config")
	checkAnimations(t, Config, Shared.require("EnemyDefinitions"))
	checkSounds(t, Config, Shared.require("SoundBankData"))
end
