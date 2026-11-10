--!strict
-- The Fallow's hangar desks (docs/LORE.md > The Fallow): who stands at each and what they say
-- when a soldier talks to them. Read by the server (DeskService builds the desks) and the
-- client (DeskDialogUI shows the line). Nobody sells anything: a team draws kit against its
-- record, and the record is not open yet (lobby v1), so every desk says what it will issue.
-- Lines are drafts for the lore developer to pass.

-- A desk with a rack (the Arms Room): talking gives choices instead of one line, and one of
-- them turns the camera to the guns on the wall behind the cage (ArmsRackUI). Wording by the
-- lore developer (2026-11-09): nothing on the Fallow is bought or sold, so the rack says "on
-- issue" / "not on issue", never price, buy, sell, lock, unlock, shop, store or wares.
export type Rack = {
	askWork: string, -- choice: side work ("taskings" in canon; the Plot hands work out)
	showRack: string, -- choice: turn to the rack
	leave: string, -- choice: walk away
	workAnswer: string,
	rackLine: string, -- said as the camera turns to the wall
	header: string, -- the rack view's title
	onIssue: string,
	notOnIssue: string,
	notOnIssueWhy: string,
}

export type Desk = {
	id: string,
	title: string, -- the desk, as stencilled over it
	who: string, -- the person behind it
	line: string, -- what they say
	issues: string, -- what the desk will issue once the record opens
	rack: Rack?,
}

local LobbyDesks: { Desk } = {
	{
		id = "arms_room",
		title = "ARMS ROOM",
		who = "The Quartermaster",
		line = "Window team. Record's not cut, so you fly standard issue. What do you need?",
		issues = "Guns, sidearms, grenades",
		rack = {
			askWork = "Any work going?",
			showRack = "Show me the rack.",
			leave = "Carry on.",
			workAnswer = "Work comes down from the Plot, not this cage. Get your record open and I'll have jobs for you. Not today.",
			rackLine = "Look all you like. Nothing comes off that wall till your record says so.",
			header = "THE RACK",
			onIssue = "ON ISSUE",
			notOnIssue = "NOT ON ISSUE",
			notOnIssueWhy = "Record not open",
		},
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
