--!strict
-- The Fallow's hangar desks (docs/LORE.md > The Fallow): who stands at each and what they say
-- when a soldier talks to them. Read by the server (DeskService builds the desks) and the
-- client (DeskDialogUI shows the line). Nobody sells anything: a team draws kit against its
-- record, and the record is not open yet (lobby v1), so every desk says what it will issue.
-- Lines are drafts for the lore developer to pass.

export type Desk = {
	id: string,
	title: string, -- the desk, as stencilled over it
	who: string, -- the person behind it
	line: string, -- what they say
	issues: string, -- what the desk will issue once the record opens
}

local LobbyDesks: { Desk } = {
	{
		id = "arms_room",
		title = "ARMS ROOM",
		who = "The armorer",
		line = "Record's not cut yet. You fly standard issue. Sign the rifle back in if you bring it home.",
		issues = "Guns, sidearms, grenades",
	},
	{
		id = "loadmaster",
		title = "LOADMASTER",
		who = "Lantern's crew chief",
		line = "Everything that goes out that door goes past me. Pop a flare down there and I kick it.",
		issues = "Supply cases and support kit",
	},
	{
		id = "fires",
		title = "FIRES",
		who = "Fire support officer",
		line = "Hammer, Anvil, Shrike. I put your callsign on the net. Mark it and they hear you.",
		issues = "Fire missions",
	},
	{
		id = "engineers",
		title = "ENGINEERS",
		who = "Sapper sergeant",
		line = "Wire, mines, the door charge. Mind the coils on your way past.",
		issues = "Wire, mines and charges",
	},
}

return table.freeze(LobbyDesks)
