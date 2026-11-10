--!strict
-- The Carrier's working crew who walk the ship (Nova, 2026-11-10: "give the fallow some
-- life"; roles and lines by the lore developer, docs/lore/ship_company.md). They don't stop
-- or take prompts: a line shows over their head when a soldier walks close. Where each one
-- walks is FallowLayout.Crew (server); CrewService builds them and CrewWalk (client) moves
-- them.

export type Crew = {
	id: string,
	role: string,
	lines: { string }, -- one picked at random when a soldier comes close
}

local LobbyCrew: { Crew } = {
	{
		id = "director",
		role = "Plane director",
		lines = {
			"Stay behind the line. Spot three's turning.",
			"Mind the tail rotor. You won't see it.",
		},
	},
	{
		id = "deckhand",
		role = "Deck hand",
		lines = {
			"Chocks and chains. Every spot, every time.",
			"They hose the birds before I touch them.",
		},
	},
	{
		id = "mechanic",
		role = "Hangar mechanic",
		lines = {
			"Mind your feet. Hose water's in everything down here.",
			"New tail rotor on that one. Don't ask.",
		},
	},
	{
		id = "runner",
		role = "Plot runner",
		lines = {
			"Make a hole. Message for the island.",
			"Plot wants a count. Nobody likes the count.",
		},
	},
	{
		id = "medic",
		role = "Screening medic",
		lines = {
			"Hands out, sleeves up. Same as every time.",
			"Nobody's failed my lane. Let's keep it that way.",
		},
	},
	{
		id = "sentry",
		role = "Lane sentry",
		lines = {
			"Walk the lane slow. I'm paid to watch it.",
			"Delta had a sentry too. Keep moving.",
		},
	},
}

return table.freeze(LobbyCrew)
