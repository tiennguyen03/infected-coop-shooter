--!strict
-- The Carrier's hangar desks (docs/LORE.md > The Fallow, renamed the Carrier; voices in
-- docs/lore/desk_crew.md): who stands at each and what they say. Every desk talks the same
-- way: a greeting picked at random, then 1 their kit, 2 a question, 3 leave. Lines by the
-- lore developer (2026-11-10, Nova and Tien: "too cryptic, no personality").

-- What the person behind a desk says (the same shape at every desk).
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
	first: string?, -- said instead of a greeting the first time a soldier talks to them (a visit)
	farewell: string?, -- said on choice 3 before the panel closes (otherwise it closes at once)
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
	display: Rack?, -- the Call-ins display behind the desk (CallInDisplayUI): its labels
	kit: Kit?,
	unmarked: boolean?, -- no sign over them; the prompt needs a line of sight (the Visitor)
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
		issues = "Your Loadout: what you fly with",
		talk = {
			greetings = {
				"Loadmaster. Pick what you carry, sign for it, then up the ramp to your bird.",
				"You're Pike? Good. Get your kit signed. My bird doesn't wait on paperwork.",
				"Whatever you sign for here is what you drop with. Choose like you mean it.",
				"I tally every seat out and every seat back on my door. Come back, Pike.",
			},
			open = "Set up my Loadout.",
			ask = "What can you drop me?",
			answer = "Ammo and medical, kicked out of my door when you throw for it. Buy them at Call-ins.",
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
			notOnRecord = "That's not yours yet. Guns at the Arms Room, call-ins at Call-ins, ATVs at Vehicles.",
		},
	},
	{
		id = "plot",
		title = "MAP ROOM",
		who = "Control's watch officer",
		issues = "The corridor map and the board of what we hold",
		talk = {
			greetings = {
				"This is the map room. I'm Control, the voice on your radio when you're down there.",
				"Delta's your mission. Do the job, kill the big one, get to the helicopter before it leaves.",
				"Every number on that board is a place we're holding. I'd like them higher.",
				"Keep it down. Half this room is on the radio with a team that's still out.",
			},
			open = "Show me the missions.",
			ask = "What's the board for?",
			answer = "How much of each district we hold. Contained isn't clean, it's just stopped spreading.",
			leave = "That's all.",
			openLine = "The Harlan Corridor. Pick where you go in and I'll call the helicopter.",
			bought = "That's on your record now. I just keep the map.",
			short = "You're short on merits. Nothing I can do about that from the map room.",
			refused = "Can't do that from here. Try again in a minute.",
		},
	},
	{
		-- Every call-in (owner 2026-11-16: one desk for them; the Fires desk is gone). What it
		-- sells is each call-in row's own `Desk`, or Config.Lobby.Sellers.CallIn (KitPrices).
		id = "callins",
		title = "CALL-INS",
		who = "Sapper sergeant",
		issues = "Every call-in: fire missions, the sentry gun, mines, wire and supply drops",
		talk = {
			greetings = {
				"Call-ins. Mortars, artillery, a gunship, mines, wire, ammo and med drops. All here.",
				"Mind the coils on your way past. That wire bites, and it doesn't let go.",
				"Nine fingers and counting. Ask me anything about mines. Or mortars, these days.",
				"Hammer, Anvil, Shrike and Tripline come free. The rest cost merits. Worth every one.",
			},
			open = "Show me the call-ins.",
			ask = "How do I call one in?",
			answer = "Press its number and throw. It comes down where your marker lands.",
			leave = "That's all.",
			openLine = "It's all laid out behind me. Pick one, buy it, sign for it with the Loadmaster.",
			bought = "It's yours. Set it, step back, let it work.",
			short = "You're short. I'd do you a deal, but the Quartermaster counts my wire.",
			refused = "Paperwork's jammed. Give it a minute.",
		},
		display = {
			header = "THE KIT",
			onIssue = "ON YOUR RECORD",
			notOnIssue = "NOT ON YOUR RECORD",
			currency = "MERITS",
			buy = "BUY",
		},
	},
	{
		-- The motor pool at the hangar's aft end (Nova and Tien 2026-11-17; lines by the lore
		-- developer, docs/lore/desk_crew.md). She sells every row with Desk = "vehicles": the
		-- ATV today (Config.CallIns.ATV); it is signed into a call-in slot at the Loadmaster.
		id = "vehicles",
		title = "VEHICLES",
		who = "Motor sergeant",
		issues = "The ATVs: one drives, one rides the back and shoots",
		talk = {
			greetings = {
				"Vehicles. I keep the ATVs running. You bring them back. That's the deal.",
				"Two seats. One drives, one rides the back and shoots. Nobody rides the roof.",
				"Roads up there are full of dead cars. An ATV fits between them. A truck doesn't.",
				"Every ATV goes down hanging under a helo. I write down which ones come back.",
			},
			open = "Show me the vehicles.",
			ask = "Who does what on it?",
			answer = "Driver steers. Whoever's on the back shoots their main gun. Get on and off with E.",
			leave = "That's all.",
			openLine = "That's what's running. Buy it here, then sign it into a call-in slot with the Loadmaster.",
			bought = "It's on your record. Bring it back. You too, ideally.",
			short = "Not enough merits. Fuel's free. The ATV isn't.",
			refused = "That one's in bits right now. Give me a minute.",
		},
	},
	{
		-- The Visitor (owner 2026-11-18: "the visitor is fine for now, it should change every
		-- week and sell like 5 items, do not implement the items yet, just give him some dialog
		-- for now"; lines by the lore developer, docs/lore/desk_crew.md > The Visitor). He stands
		-- in the hidden nook under the ramp (FallowLayout.Desks, Carrier v2 only): no sign, no
		-- marker. He sells the Fifty (Config.Weapons.Fifty: Desk "visitor", merits), so "What do
		-- you sell?" opens his desk screen (DeskScreen); his weekly rotating stock of five is
		-- written down (docs/sprints/CARRIER_V2.md > The Visitor), not built.
		id = "visitor",
		title = "VISITOR",
		who = "Escort required",
		issues = "Not on the ship's books",
		unmarked = true,
		talk = {
			first = "You walked past twice. Come in.",
			greetings = {
				"You found me. Most don't. Have a look, and keep it off the radio.",
				"Bring me something of the Warden's, one day.",
				"Mind the tarp on your way out. It's there for a reason.",
				"Sit, if you like. The chair is the only thing down here that isn't sealed.",
				"I read every report from the ground. Yours are better than most.",
			},
			open = "What do you sell?",
			ask = "Who are you?",
			answer = "A visitor. I'm not on the ship's books, and I'd like it to stay that way.",
			leave = "Leave.",
			farewell = "I'll have something else next week. What goes won't come back soon.",
			openLine = "Nothing on the table this week. Come back when the crates are open.",
			bought = "Yours, then. Look after it. There isn't another.",
			short = "Not enough merits. The price doesn't move, I'm afraid.",
			refused = "Not today. Come back in a minute.",
		},
	},
}

return table.freeze(LobbyDesks)
