--!strict
-- The Carrier's hangar desks (docs/LORE.md > The Fallow, renamed the Carrier; voices in
-- docs/lore/desk_crew.md): who stands at each and what they say. Every desk talks the same
-- way: a greeting picked at random, then 1 their kit, 2 a question, 3 leave. Lines by the
-- lore developer (2026-11-10, Nova and Tien: "too cryptic, no personality").

-- What the person behind a desk says (the same shape at all four desks).
export type Talk = {
	greetings: { string }, -- one picked at random each time you talk
	open: string, -- choice 1: see / buy this desk's kit (the Loadmaster: the Loadout)
	ask: string, -- choice 2
	answer: string, -- their reply to choice 2 (the Loadmaster: shown with his supply panel)
	leave: string, -- choice 3: walk away (closes the panel, no line)
	openLine: string, -- said as their kit opens
	bought: string, -- a BUY went through
	short: string, -- a BUY refused: not enough merits
	refused: string, -- a BUY refused for any other reason (save down, etc.)
}

-- The Arms Room's wall of guns (ArmsRackUI): labels only.
export type Rack = {
	header: string,
	onIssue: string,
	notOnIssue: string,
	currency: string,
	buy: string,
}

-- The Loadmaster's Loadout screen (LoadmasterUI, LoadoutMenu): labels and his answers.
export type Kit = {
	header: string,
	confirm: string,
	confirmLine: string, -- the Loadout was signed
	reject: string, -- the rules refused it
	notOnRecord: string, -- something in it isn't bought
}

export type Desk = {
	id: string,
	title: string, -- the desk, as stencilled over it
	who: string, -- the person behind it
	issues: string, -- what the desk deals in
	talk: Talk,
	rack: Rack?,
	kit: Kit?,
}

local LobbyDesks: { Desk } = {
	{
		id = "arms_room",
		title = "ARMS ROOM",
		who = "The Quartermaster",
		issues = "Guns, sidearms and grenades",
		talk = {
			greetings = {
				"Arms Room. Guns, sidearms and grenades. Pay in merits and it's yours for good.",
				"Rifle and pistol come free. Anything better costs merits. Have a look.",
				"Thirty years behind a cage like this. Guns don't change. Soldiers get younger.",
				"Take your time. I'd rather you pick right than come back and complain.",
			},
			open = "Show me the guns.",
			ask = "How do I get merits?",
			answer = "You signed on with a thousand. Control's not paying for missions yet, so spend careful.",
			leave = "That's all.",
			openLine = "Pick one for a closer look. Buy it here, then sign for it with the Loadmaster.",
			bought = "It's yours now, on your record for good. Loadmaster's at the ramp.",
			short = "Not enough merits for that one. Price is the price.",
			refused = "Can't sign that one over right now. Try me again in a minute.",
		},
		rack = {
			header = "THE RACK",
			onIssue = "ON YOUR RECORD",
			notOnIssue = "NOT ON YOUR RECORD",
			currency = "MERITS",
			buy = "BUY",
		},
	},
	{
		id = "loadmaster",
		title = "LOADMASTER",
		who = "Helicopter crew chief",
		issues = "Your Loadout, plus ammo and medical drops",
		talk = {
			greetings = {
				"Loadmaster. Pick what you carry, sign for it, then up the ramp to your bird.",
				"You're Pike? Good. Get your kit signed. My bird doesn't wait on paperwork.",
				"Whatever you sign for here is what you drop with. Choose like you mean it.",
				"I tally every seat out and every seat back on my door. Come back, Pike.",
			},
			open = "Set up my Loadout.",
			ask = "What can you drop me?",
			answer = "Ammo and medical, kicked out of my door when you throw for it. Buy it here first.",
			leave = "That's all.",
			openLine = "Main gun, sidearm, grenade, four different call-ins. Dimmed ones you still have to buy.",
			bought = "Bought. Throw for it out there and I'll kick it out the door.",
			short = "You're short on merits. Can't kick what you haven't paid for.",
			refused = "Couldn't sign that over. Give it a minute and try again.",
		},
		kit = {
			header = "LOADOUT",
			confirm = "SIGN FOR IT",
			confirmLine = "Signed. That's what you fly with. Up the ramp, find a bird with a seat.",
			reject = "That won't go. You need four call-ins, and no two the same.",
			notOnRecord = "That's not yours yet. Buy it first: guns at the Arms Room, call-ins at their desk.",
		},
	},
	{
		id = "fires",
		title = "FIRES",
		who = "Fire support officer",
		issues = "Fire missions: Hammer, Anvil, Shrike",
		talk = {
			greetings = {
				"Fires. I put you on the mortar, artillery and gunship nets. Throw the marker, they shoot.",
				"Hammer, Anvil and Shrike are free. You're already cleared on all three nets.",
				"The guns can't see you. They only see your marker. So throw it where you mean it.",
				"Quiet on the net. It never stays quiet. What do you need?",
			},
			open = "Show me the fire missions.",
			ask = "How do I call one in?",
			answer = "Press its number and throw the marker. The guns fire where it lands. Simple.",
			leave = "That's all.",
			openLine = "Hammer: six mortar rounds. Anvil: one big shell. Shrike: a gun run along your throw.",
			bought = "You're on that net now. Your callsign's in the book.",
			short = "You're short on merits. Come back when you can cover it.",
			refused = "The net's busy. Try that again in a minute.",
		},
	},
	{
		id = "plot",
		title = "THE PLOT",
		who = "Control's watch officer",
		issues = "The corridor map and the Containment Board",
		talk = {
			greetings = {
				"This is the Plot. I'm Control, the voice on your radio when you're down there.",
				"Delta's your mission. Do the job, kill the big one, get to your bird before the Burn.",
				"Every number on that board is a place we're holding. I'd like them higher.",
				"Keep it down. Half this room is on the net with a team that's still out.",
			},
			open = "Show me the map.",
			ask = "What's the board for?",
			answer = "How much of each district we hold. Contained isn't clean, it's just stopped spreading.",
			leave = "That's all.",
			openLine = "The Harlan Corridor. Coast at the bottom, the dam at the top. You start at Delta.",
			bought = "That's on your record now. I just keep the map.",
			short = "You're short on merits. Nothing I can do about that from the Plot.",
			refused = "Can't do that from here. Try again in a minute.",
		},
	},
	{
		id = "engineers",
		title = "ENGINEERS",
		who = "Sapper sergeant",
		issues = "Sentry gun, mines and wire",
		talk = {
			greetings = {
				"Engineers. Wire, mines and the Doorman gun. Things that hold ground when you can't.",
				"Mind the coils on your way past. That wire bites, and it doesn't let go.",
				"Nine fingers and counting. Ask me anything about mines.",
				"Tripline comes free. The gun and the wire cost merits. Worth every one.",
			},
			open = "Show me the kit.",
			ask = "Any advice?",
			answer = "Lay wire across their path, not yours. Nothing climbs over it. Nothing.",
			leave = "That's all.",
			openLine = "Doorman's a gun that shoots on its own. Tripline's six mines. Concertina's the wire.",
			bought = "It's yours. Set it, step back, let it work.",
			short = "You're short. I'd do you a deal, but the Quartermaster counts my wire.",
			refused = "Paperwork's jammed. Give it a minute.",
		},
	},
}

return table.freeze(LobbyDesks)
