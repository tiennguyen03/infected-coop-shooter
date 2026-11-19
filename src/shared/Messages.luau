--!strict
-- The kinds a remote message carries as its first argument (docs/ARCHITECTURE.md F3), one
-- frozen table per remote (Remotes.REMOTE_NAMES documents each payload). Senders and
-- receivers use these constants, so a misspelt kind is a type error instead of a message
-- the other side silently ignores. The values are the wire strings and never change.

local Messages = table.freeze({
	-- Breach: server -> every client ("warn", from: Vector3, seconds) a horde is coming from
	-- that point (BreachUI draws the arrow) | ("clear") a new run
	Breach = table.freeze({
		Warn = "warn",
		Clear = "clear",
	}),
	-- Resupply: client -> server ("flare", target) | ("pick", crateId, cardId);
	-- server -> client ("called", thrower) | ("cards", ...) | ("picked", crateId, cardId) |
	-- ("refused", crateId, reason) | ("taken", crateId, names) | ("closed", crateId)
	Resupply = table.freeze({
		Flare = "flare",
		Pick = "pick",
		Called = "called",
		Cards = "cards",
		Picked = "picked",
		Refused = "refused", -- (crateId, reason): Rules/Reward.checkPick's word
		Taken = "taken", -- (crateId, names): the callsigns that have taken a card from the crate
		Closed = "closed",
	}),
	-- Vehicle (VehicleService, client VehicleController)
	Vehicle = table.freeze({
		Exit = "exit",
		Ram = "ram",
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
		-- The objective pools (Config.Objectives): (entries: { Rules/Objectives.Entry }) the
		-- main objective and the side objectives, resent whenever one changes
		Board = "board",
		-- (name, why, place) the main objective's card at insert, before the squad moves
		Brief = "brief",
		-- client -> server: () send me the board (a client that just loaded)
		Request = "request",
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
	-- EnemySpit (server -> client): an Infected spit's look (EnemyProjectileService -> SpitFX)
	EnemySpit = table.freeze({
		Windup = "windup", -- (model, seconds) the spitter planted and is rearing back
		Launch = "launch", -- (id, origin, velocity, size) a glob left the mouth
		Impact = "impact", -- (id, position, normal, splashRadius, poolGround?, poolRadius?, poolSeconds?)
		Gone = "gone", -- (id) the glob left the world without landing
		Reset = "reset", -- () new run: clear everything
	}),
	-- Launch (lobby place, server -> client): your seat on a Lantern spot
	-- Record (lobby place): the Quartermaster's rack (RecordService, Rules/Record)
	Record = table.freeze({
		Buy = "buy", -- client -> server: (gunId)
		State = "state", -- server -> client: (merits, ownedIds, tabs) the soldier's record
		Refused = "refused", -- server -> client: (gunId, reason) "short" | "owned" | "unknown" | "loading"
	}),
	-- KitMods (lobby place): the Loadmaster's KIT MODS tab (KitModService, Rules/KitModRules).
	-- Merits only; the server checks and spends.
	KitMods = table.freeze({
		Buy = "buy", -- client -> server: (modId, rank) the rank being bought, the next one
		Get = "get", -- client -> server: () send my ranks
		State = "state", -- server -> client: (ranks) { [modId]: rank }
		Refused = "refused", -- server -> client: (modId, reason) "short" | "maxed" | "beyond max" | "not next" | "disabled" | "unknown" | "loading" | "busy"
	}),
	-- Optic (lobby place): the Loadmaster's EDIT, the M16A4's optic slot (OpticService,
	-- Rules/AttachmentRules). Bought once with merits; the server checks and spends.
	Optic = table.freeze({
		Buy = "buy", -- client -> server: (opticId)
		Equip = "equip", -- client -> server: (gunId, opticId) "" takes the optic off
		Owned = "owned", -- client -> server: () send the optics on my record
		State = "state", -- server -> client: (ownedOpticIds)
		Equipped = "equipped", -- server -> client: (gunId, opticId) fitted and signed
		Refused = "refused", -- server -> client: (id, reason) "short" | "owned" | "unknown" | "not owned" | "incompatible" | "loading"
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
