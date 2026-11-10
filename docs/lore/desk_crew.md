# The Carrier's desk crew

Canon as of 2026-11-10 (Nova and Tien asked for dialog that is plain and has personality;
Nova approved this pass). The place is [LORE.md > The Carrier](../LORE.md#the-carrier). The
code copy of every line is `src/lobby/shared/LobbyDesks.luau` (the `Talk` type); this file
is the canon copy. Change a line in both.

Rules for every desk line:

- A new 13+ player knows from the first line who this is and what they do for them.
- One or two lines on the panel (90 characters or fewer). Jargon only when the sentence
  explains it.
- Merits, the record, BUY. Never shop, store, wares, sell, lock or unlock.
- The lines describe the game as it is. No friendly-fire warnings (there is none), no "one
  support weapon" (no such rule), no "book's shut" (buying works).
- No personal names in the UI: the sign says the job. Surnames, if ever, go on name tapes
  (art only).
- Lines that name kit (Fires, the Engineers, the `issues` text) are updated by whoever moves
  a call-in to another desk.

How a desk talks: a greeting picked at random, then 1 their kit, 2 a question, 3 leave.
After a BUY: `bought`, or `short` (not enough merits), or `refused` (any other refusal).

## The Quartermaster (Arms Room)

Sergeant First Class, mid-fifties, male. An Army supply lifer who has run arms rooms for
thirty years. Dry, unhurried, protective of his rack, fond of the soldiers and won't say so.
He talks in short, flat sentences, and everything is a signature, a count or a price ("Price
is the price."). He never raises his voice and never jokes about the dead. The one detail
for art: reading glasses on a cord and a clipboard he never puts down.

## The Loadmaster (Lantern's crew chief)

Early thirties, male. He rides the door on every flight. Quick and loud from years of
shouting over rotors; impatient, not unkind. He thinks in minutes and kit and talks in
bursts. He says "my bird" and "my door" and calls the squad "Pike". He keeps the tally on the
door frame ([LORE.md > Lantern](../LORE.md#lantern)) and is the one person who talks about it
plainly. The one detail for art: a flight helmet pushed up, the monkey-strap harness still on
over his working dress.

## Fires (fire support officer)

Lieutenant, late twenties, female. Calm, precise, polite, a natural teacher. She is a
little unnerving about how calmly she describes a 105 mm shell. She speaks in complete,
ordered sentences, explains in steps and ends on "Simple." She respects the net. The one
detail for art: a headset round her neck, its cord running back to a radio on the desk.

## The Engineers (sapper sergeant)

Staff Sergeant, forties, male, a sapper. Slow and patient, fond of his wire, with the
gallows humour of a man who handles mines for a living. He never hurries. He says "my wire"
and "mind the coils" and jokes about the fingertip he lost ("Nine fingers and counting"). He
thinks the Quartermaster counts everything, which is true. The one detail for art: the tip
of one finger missing, work gloves and wire cutters on his belt.

## Control's watch officer (the Plot)

Canon 2026-11-10 (replaces the stand-in block figure; owner approved). Major, late forties,
female, Army. She has the watch in the Plot and she is Control: when Pike hears "Pike,
Control" on the net, it is her. Off the net she is drier, quieter, a little tired, and kind
in a way she keeps short. She talks in places and times, never in casualties: a team that
does not come back is "off the net", and a district is Lost, Contested, Held or Contained,
nothing else. "Contained isn't clean" is hers; the plotter wrote it on the map. She calls the
squad "Pike". The one detail for art: a headset worn with one earcup on and one pushed back,
so she can hear the net and the room at once.

The **plotter** behind the Containment Board is ship's company: a young sailor in dark blue
writing backwards in grease pencil, a sound-powered phone headset on with its mouthpiece on
his chest. He never speaks.

## Bodies: what each one wears (for the art director)

Simple low-poly accessories that make each body read as a person. Pike grey is only Pike.

| Body | Dress | Details |
|---|---|---|
| Pike (every player and bot) | Pike grey, black carrier, seat square | the Carrier's **screening band** on the left wrist (white paper, one yellow stripe; Delta's was white with red); a chemlight taped to the left shoulder strap; the tourniquet on the carrier (already canon) |
| The Quartermaster | Army working dress | reading glasses on a cord; the clipboard; the cage keys on a ring at his belt |
| The Loadmaster | Lantern aircrew flight suit | flight helmet pushed up on his head, visor up; monkey-strap harness on over the suit, tether hanging; a grease pencil in the sleeve pocket (the tally) |
| Lantern crew chief (on each bird) | aircrew flight suit | helmet on, visor down; tether clipped to the kick rail; flight gloves |
| Fires | Army working dress | headset round her neck, its cord to the radio on her desk; a small notebook in the sleeve pocket |
| The Engineers | Army working dress | work gloves tucked in his belt; wire cutters on the belt; a short coil of wire over one shoulder |
| Control's watch officer | Army working dress | headset, one earcup on, one pushed back; a steel mug (the coffee is cold); rank on the chest tab |
| The plotter | ship's dark blue | sound-powered phone headset with a chest mouthpiece; a grease pencil in hand |
| Ship's company walkers | see [ship_company.md](ship_company.md) | the jersey colour is the read; one prop each (ear defenders, chain, rag, clipboard, smock, rifle) |

## Lines (canon copy)

### The Quartermaster

| Field | Line |
|---|---|
| Greeting | "Arms Room. Guns, sidearms and grenades. Pay in merits and it's yours for good." |
| Greeting | "Rifle and pistol come free. Anything better costs merits. Have a look." |
| Greeting | "Thirty years behind a cage like this. Guns don't change. Soldiers get younger." |
| Greeting | "Take your time. I'd rather you pick right than come back and complain." |
| 1 (open) | Show me the guns. |
| 2 (ask) | How do I get merits? |
| Answer | "You signed on with a thousand. Control's not paying for missions yet, so spend careful." |
| 3 (leave) | That's all. |
| Kit opens | "Pick one for a closer look. Buy it here, then sign for it with the Loadmaster." |
| Bought | "It's yours now, on your record for good. Loadmaster's at the ramp." |
| Short | "Not enough merits for that one. Price is the price." |
| Refused | "Can't sign that one over right now. Try me again in a minute." |
| Rack labels | THE RACK; ON YOUR RECORD; NOT ON YOUR RECORD; MERITS; BUY |

When missions pay merits, the answer becomes: "You signed on with a thousand. Control pays
more when your team gets the job done."

### The Loadmaster

| Field | Line |
|---|---|
| Greeting | "Loadmaster. Pick what you carry, sign for it, then up the ramp to your bird." |
| Greeting | "You're Pike? Good. Get your kit signed. My bird doesn't wait on paperwork." |
| Greeting | "Whatever you sign for here is what you drop with. Choose like you mean it." |
| Greeting | "I tally every seat out and every seat back on my door. Come back, Pike." |
| 1 (open) | Set up my Loadout. |
| 2 (ask) | What can you drop me? |
| Answer (with his supply panel) | "Ammo and medical, kicked out of my door when you throw for it. Buy it here first." |
| 3 (leave) | That's all. |
| Loadout opens | "Main gun, sidearm, grenade, four different call-ins. Dimmed ones you still have to buy." |
| Bought | "Bought. Throw for it out there and I'll kick it out the door." |
| Short | "You're short on merits. Can't kick what you haven't paid for." |
| Refused | "Couldn't sign that over. Give it a minute and try again." |
| Signed | "Signed. That's what you fly with. Up the ramp, find a bird with a seat." |
| Rules refused | "That won't go. You need four call-ins, and no two the same." |
| Not bought | "That's not yours yet. Buy it first: guns at the Arms Room, call-ins at their desk." |
| Loadout labels | LOADOUT; SIGN FOR IT |

### Fires

| Field | Line |
|---|---|
| Greeting | "Fires. I put you on the mortar, artillery and gunship nets. Throw the marker, they shoot." |
| Greeting | "Hammer, Anvil and Shrike are free. You're already cleared on all three nets." |
| Greeting | "The guns can't see you. They only see your marker. So throw it where you mean it." |
| Greeting | "Quiet on the net. It never stays quiet. What do you need?" |
| 1 (open) | Show me the fire missions. |
| 2 (ask) | How do I call one in? |
| Answer | "Press its number and throw the marker. The guns fire where it lands. Simple." |
| 3 (leave) | That's all. |
| Kit opens | "Hammer: six mortar rounds. Anvil: one big shell. Shrike: a gun run along your throw." |
| Bought | "You're on that net now. Your callsign's in the book." |
| Short | "You're short on merits. Come back when you can cover it." |
| Refused | "The net's busy. Try that again in a minute." |

Hammer, Anvil and Shrike are issued free, so her Bought and Short lines wait for a paid fire
mission.

### The Engineers

| Field | Line |
|---|---|
| Greeting | "Engineers. Wire, mines and the Doorman gun. Things that hold ground when you can't." |
| Greeting | "Mind the coils on your way past. That wire bites, and it doesn't let go." |
| Greeting | "Nine fingers and counting. Ask me anything about mines." |
| Greeting | "Tripline comes free. The gun and the wire cost merits. Worth every one." |
| 1 (open) | Show me the kit. |
| 2 (ask) | Any advice? |
| Answer | "Lay wire across their path, not yours. Nothing climbs over it. Nothing." |
| 3 (leave) | That's all. |
| Kit opens | "Doorman's a gun that shoots on its own. Tripline's six mines. Concertina's the wire." |
| Bought | "It's yours. Set it, step back, let it work." |
| Short | "You're short. I'd do you a deal, but the Quartermaster counts my wire." |
| Refused | "Paperwork's jammed. Give it a minute." |

### Control's watch officer (the Plot)

Desk id `plot`; she sells nothing, so her BUY lines are only fallbacks.

| Field | Line |
|---|---|
| Greeting | "This is the Plot. I'm Control, the voice on your radio when you're down there." |
| Greeting | "Delta's your mission. Do the job, kill the big one, get to your bird before the Burn." |
| Greeting | "Every number on that board is a place we're holding. I'd like them higher." |
| Greeting | "Keep it down. Half this room is on the net with a team that's still out." |
| 1 (open) | Show me the map. |
| 2 (ask) | What's the board for? |
| Answer | "How much of each district we hold. Contained isn't clean, it's just stopped spreading." |
| 3 (leave) | That's all. |
| Map opens | "The Harlan Corridor. Coast at the bottom, the dam at the top. You start at Delta." |
| Bought | "That's on your record now. I just keep the map." |
| Short | "You're short on merits. Nothing I can do about that from the Plot." |
| Refused | "Can't do that from here. Try again in a minute." |

## Open

- **Taskings** (side work handed out at a desk, from the Plot) stay an open idea, no longer
  in the dialog.
- What the other window teams on the ship are called is still open
  ([LORE.md > The Carrier](../LORE.md#the-carrier)).
