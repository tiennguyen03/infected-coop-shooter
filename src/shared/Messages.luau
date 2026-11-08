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
	-- UseAbility (client -> server) and AbilityUsed (server -> client)
	Ability = table.freeze({
		Dash = "dash",
		Breach = "breach",
		CallIn = "callin",
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
	CoverMove = table.freeze({
		Vault = "vault",
		Climb = "climb",
		Roll = "roll",
		Slide = "slide",
	}),
})

return Messages
