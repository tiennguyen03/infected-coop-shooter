--!strict
-- The kinds a remote message carries as its first argument (docs/ARCHITECTURE.md F3), one
-- frozen table per remote (Remotes.REMOTE_NAMES documents each payload). Senders and
-- receivers use these constants, so a misspelt kind is a type error instead of a message
-- the other side silently ignores. The values are the wire strings and never change.

local Messages = table.freeze({
	-- Resupply: client -> server ("flare", target) | ("pick", crateId, cardId);
	-- server -> client ("called", thrower) | ("cards", ...) | ("picked", crateId) | ("closed", crateId)
	Resupply = table.freeze({
		Flare = "flare",
		Pick = "pick",
		Called = "called",
		Cards = "cards",
		Picked = "picked",
		Closed = "closed",
	}),
	-- UseAbility (client -> server) and AbilityUsed (server -> client): the soldier's kit
	-- (KitService) and the call-in report (CallInService)
	Ability = table.freeze({
		Swap = "swap",
		Grenade = "grenade",
		Shove = "shove",
		Stim = "stim",
		CallIn = "callin",
	}),
	-- Loadout (the Arms Room): client -> server ("request", {primary, secondary, grenade,
	-- callIns}); server -> client ("result", ok, reason)
	Loadout = table.freeze({
		Request = "request",
		Result = "result",
		Signed = "signed", -- lobby, server -> client: (loadout) the Loadout saved from a past visit
	}),
	ObjectiveUpdate = table.freeze({
		Started = "started",
		Progress = "progress",
		Completed = "completed",
	}),
	ExtractionUpdate = table.freeze({
		Available = "available",
		Progress = "progress",
		Returning = "returning",
		Waiting = "waiting", -- (progress, playersIn, playersLiving): some of the squad is on the pad
		Complete = "complete",
		Hide = "hide",
	}),
	BossUpdate = table.freeze({
		Show = "show",
		State = "state",
		Tell = "tell",
		Zone = "zone",
		Hide = "hide",
	}),
	-- BossUpdate "tell" kinds that are not attacks (attack tells carry the attack's name)
	BossTell = table.freeze({
		Break = "break",
		Stun = "stun",
	}),
	Impact = table.freeze({
		Knockdown = "knockdown",
		Push = "push",
	}),
	Stance = table.freeze({
		Stand = "stand",
		Crouch = "crouch",
		Prone = "prone",
	}),
	-- BuffNotice: (text, kind) — a radio line shows as a subtitle, anything else as a card.
	Notice = table.freeze({
		Radio = "radio",
		Pickup = "pickup",
	}),
	CoverMove = table.freeze({
		Vault = "vault",
		Climb = "climb",
		Roll = "roll",
		Slide = "slide",
	}),
	-- Launch (lobby place, server -> client): your seat on a Lantern spot
	-- Record (lobby place): the Quartermaster's rack (RecordService, Rules/Record)
	Record = table.freeze({
		Buy = "buy", -- client -> server: (gunId)
		State = "state", -- server -> client: (merits, ownedIds, tabs) the soldier's record
		Refused = "refused", -- server -> client: (gunId, reason) "short" | "owned" | "unknown" | "loading"
	}),
	Launch = table.freeze({
		Manifest = "manifest", -- (spot, names, secondsLeft, squad, isLead) you are aboard; squad 0 = not picked
		Squad = "squad", -- client -> server: (size) the first aboard picks the squad size, 1 to Capacity
		Lifting = "lifting", -- (spot) the bird is lifting; the teleport is under way
		Failed = "failed", -- (reason) the teleport did not happen
		Cleared = "cleared", -- () you stepped off the spot
	}),
})

return Messages
