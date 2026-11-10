--!strict
-- The Fallow's hangar desks (docs/LORE.md > The Fallow): who stands at each and what they say
-- when a soldier talks to them. Read by the server (DeskService builds the desks) and the
-- client (DeskDialogUI shows the line). The Quartermaster sells kit onto a soldier's record
-- for merits; the Loadmaster makes up the Loadout. Buying waits for the save service (F9);
-- signing for a Loadout works now (prototype: everything in the catalog). Lines by the lore
-- developer, owner-approved 2026-11-09.

-- A desk with a rack (the Arms Room): talking gives choices instead of one line, and one of
-- them turns the camera to the guns on the wall behind the cage (ArmsRackUI). The card may
-- show BUY and a price in merits; never shop, store, wares, sell, lock or unlock.
export type Rack = {
	askWork: string, -- choice: side work ("taskings" in canon; the Plot hands work out)
	showRack: string, -- choice: turn to the rack
	leave: string, -- choice: walk away
	workAnswer: string,
	rackLine: string, -- said as the camera turns to the wall
	header: string, -- the rack view's title
	onIssue: string, -- on the soldier's record
	notOnIssue: string,
	notOnIssueWhy: string,
	currency: string, -- price shown as "<n> MERITS" (buying waits for F9)
	buy: string,
	bookShut: string, -- BUY pressed before the save service exists
	bought: string,
	short: string,
}

-- A desk with a kit (the Loadmaster): choices like the rack's; the first opens the Loadout
-- (LoadmasterUI, LoadoutMenu) and SIGN FOR IT sends it to LoadmasterService.
export type Kit = {
	kitUp: string, -- choice 1: open the Loadout
	ask: string, -- choice 2
	leave: string, -- choice 3
	askAnswer: string,
	kitLine: string, -- shown under the Loadout as it opens
	header: string, -- the Loadout's title
	confirm: string, -- the sign button
	confirmLine: string, -- said once the Loadout is signed
	reject: string, -- the rules refused it
	notOnRecord: string, -- ownership refused it (after F9)
	bookShut: string, -- unused while signing is open (prototype)
}

export type Desk = {
	id: string,
	title: string, -- the desk, as stencilled over it
	who: string, -- the person behind it
	line: string, -- what they say
	issues: string, -- what the desk deals in
	rack: Rack?,
	kit: Kit?,
}

local LobbyDesks: { Desk } = {
	{
		id = "arms_room",
		title = "ARMS ROOM",
		who = "The Quartermaster",
		line = "Window team. You buy it here, you sign for it at the ramp. What do you need?",
		issues = "Guns, sidearms, grenades, for merits",
		rack = {
			askWork = "Any work going?",
			showRack = "Show me the rack.",
			leave = "Carry on.",
			workAnswer = "Work comes down from the Plot, not this cage. No taskings yet.",
			rackLine = "Pay in merits and it goes on your record. Kit up with the Loadmaster.",
			header = "THE RACK",
			onIssue = "ON YOUR RECORD",
			notOnIssue = "NOT ON YOUR RECORD",
			notOnIssueWhy = "Merit book not open",
			currency = "MERITS",
			buy = "BUY",
			bookShut = "Book's shut till Control pays out. Look all you like.",
			bought = "Signed. It's on your record. Loadmaster's at the ramp.",
			short = "You're short. Bring me merits.",
		},
	},
	{
		id = "loadmaster",
		title = "LOADMASTER",
		who = "Lantern's crew chief",
		line = "What's on you and what I kick, you sign for here. Then up the ramp.",
		issues = "Your Loadout: guns, grenade, call-ins",
		kit = {
			kitUp = "Make up my Loadout.",
			ask = "What do you kick?",
			leave = "Carry on.",
			askAnswer = "Four call-ins a soldier, one support weapon. You flare, my chief kicks it.",
			kitLine = "Gun, sidearm, grenade, four call-ins. Only what's on your record.",
			header = "LOADOUT",
			confirm = "SIGN FOR IT",
			confirmLine = "Signed. Your bird's up the ramp. Don't keep it waiting.",
			reject = "That won't go. Four call-ins, all different, one support weapon.",
			notOnRecord = "That's not on your record. Quartermaster first.",
			bookShut = "Book's not open. You fly standard issue today.",
		},
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
