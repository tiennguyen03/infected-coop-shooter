# LORE.md

# Project Vision

This document is NOT a gameplay specification.

It provides world-building context, character direction, tone, themes, and long-term vision.
Future implementation should reference this document to maintain consistency, but gameplay
decisions are always driven by [PLAN.md](PLAN.md) and sprint documents.

**If gameplay and lore ever conflict, prioritize gameplay.**

---

# High Concept

Humanity is losing.

An engineered strain has collapsed cities, overwhelmed military forces, and pushed
civilization to the brink of extinction. Entire regions have gone dark. Communication
networks are failing. Supply chains have collapsed. Millions are dead. Millions more are
infected. What it is and where it came from: [The strain](#the-strain) below.

Small pockets of survivors remain scattered throughout the world. Most people are simply
trying to survive another day. Very few are still fighting back.

---

# The strain

It was a field-medicine program: an engineered agent meant to make wounded soldiers rebuild
tissue fast and keep fighting. It works. It never got a stop signal. In a living host it
keeps rebuilding, pulling bone, muscle and skin into whatever shape gets the agent to the
next body, and it burns the host to do it. Nothing wants anything; a body is raw material
being re-sorted. It spreads by fluid, so every form is a delivery method. Harlan Reservoir
research station was the program's home and its cultures are the only clean copies.

The strain has a look. New tissue is rebuilt: pale, waxy and bloodless, closing wounds
too well, growing bone where a joint should be. Where the agent is working the tissue is
wet and caustic yellow-green: the Hocker's throat, the Bloat's belly, the seams a Shedder
will split along. Nothing about an Infected is dead; its eyes are green and its blood is
red where the strain tore through fresh. The corridor fell by trying to help, so every
form still wears the thing that was done for it: Delta's screening band on a Walker's
wrist, the bandage over the bite on the convoy passenger that became a Bloat, the cut
restraints on a Kestrel patient that became a Shedder. Every district banded its people
before it lost them.

**The Infected** is Command's name for every form (and the model name). The Infected are not
hungry and not dead; they are rebuilt. The soldiers' slang for each form, ordered by how far
the agent has gone in one body: Walker (a civilian, the first day), Runner (a garrison
soldier the agent did its job on), Brute (a soldier rebuilt around his breaks with bone),
Hocker (a Walker a day on, the throat a pump), Bloat (a bitten passenger sealed on a bus
with nobody to pass to), Shedder (a ward patient the agent had time to partition), Crawler
(a shed segment), Kite (shed tissue that found the wind), Growth (a host rooted where it
fell). One rule per form; roster and stage of first appearance in
[PROGRESSION.md](PROGRESSION.md); what each one looks like in [CHARACTERS.md](CHARACTERS.md).

---

# The Harlan Corridor

Command lost the Harlan quarantine corridor. Pike goes up it by helo, one fallen
position at a time, toward the station that started it. Each place failed the same way:
from the inside, by trying to help. Road signs count down the distance to Harlan; the sky
goes from evening to night to dawn. The geography (coast, Route 9, the river, the rail, the
towns, the quarantine line and what has burned) is the Plot's map:
[lore/world_map.md](lore/world_map.md).

1. **Checkpoint Delta** — the southern screening gate. Boss: the Warden.
2. **Mile 14** — the stalled evacuation convoy on the highway. Boss: the Bloat.
3. **Aid Station Kestrel** — a high school turned field hospital. Boss: the Patient.
4. **Harlan Yard** — the rail yard. Boss: the Lineman.
5. **Harlan Reservoir Station** — the dam and the research station. Boss: the Specimen.

**Control, Lantern, the Burn.** Harlan Control runs the corridor net; the squad is Pike; the
helo that carries Pike is Lantern (airframe in [The Carrier > Lantern](#lantern)), the only
thing that stays the same and the only way out. Command sanitizes what it cannot hold: each district has a scheduled incendiary fire
mission, the Burn, and the skyline burning beyond the walls is the districts that already
got theirs. A squad is inserted in the window before the Burn. Prove the district can be
held and Control pushes the Burn back; stay past it and the fire does not wait. **Stand
Down** is Lantern offering the seat home at the end of the operation: board it and the run
ends on your terms. Ask for a Second Pass and the bird turns south into a corridor that has
had time to get worse. Stage detail (landmarks, sites, story spots) is in
[PROGRESSION.md](PROGRESSION.md).

Control's voice is procedural, short, no banter: "Pike, Control. Green smoke on the Helipad."
"Lantern 2-1, ninety seconds. Hold the LZ."

## Containment

Control keeps the Containment Board: every district (Delta, Mile 14, Kestrel, the Yard, the
Reservoir) carries a containment percentage, raised by every mission any squad brings home.
Contained does not mean clean; it means the district has stopped exporting hosts, the lights
are back on and the Burn is deferred. Lost, Contested, Held, Contained are the only four
words Control uses for a place.

## Index hosts

Every fallen position has an index host: the body the strain finished first, the one that
turned the place from the inside. Control calls them the Index; the soldiers call them what
they look like (the Warden, the Bloat, the Patient, the Lineman, the Specimen). Putting one
down is the only kill Control pays for on the spot.

**The Warden** (Delta). The Gate NCOIC, an MP sergeant, ran the screening lane on the last
day: hands, papers, through. He was bitten through the shield sleeve by a civilian who
had passed the count. When the containment order came he chained the Gate himself, from
the outside, with the garrison and the highway's refugees still in the pens, and stayed
on post. The strain found the kit before it found the man: riot plate grown into bone,
the handset fused to the chest plate and still keyed open, so every attack starts with
carrier hiss and a squelch. He still walks the route, Gate to bus line to Inner Gate to
the Apron, checking buses that have been empty for a week. Shoot the plates off and he
is just a man again. Optional name for the roster board: SGT HALE (not used in game).

Radio for the Warden mission (`Config.Index.Warden.Radio`; the insert and wipe lines are
written but not yet placed):

| Cue | Line |
|---|---|
| Insert (not placed) | "Pike, Control. Delta's Index is the Gate NCOIC. He chained it. Expect him to come looking." |
| Primary complete | "Control copies. That's the Primary. Index is moving at the Gate." |
| Gate open | "Gate's open. Contact in the lane, big. It's wearing riot plate." |
| Sighting | "Eyes on. That's the Gate NCOIC. Control, Index confirmed." |
| Bus line | "Bus line. He's checking buses. Plates first, then the body." |
| Inner Gate | "Inner Gate. He's working his second checkpoint. Flank when he guards." |
| First plate | "Plate's off. That's bone under it. Keep working the seams." |
| Last plate | "Last plate. He's just a man again. Put him down." |
| Riot Call (the handset) | "...all posts, Gate. Crowd at the wire. Send the reserve..." |
| Bash (the handset) | "...hands. Show me your hands. Hands..." |
| Charge (the handset) | "...move back. Move back. Clear the lane..." |
| Canister (the handset) | "...gas. Gas in the lane..." |
| Kill | "Index down. Control copies. Gate's yours, Pike. Pallet inbound." |
| Wipe (not placed) | "Pike, Control. Lost you at the Gate. Marking Delta red." |

Gate dressing written for Open the Route, not placed yet: the chain and padlock on the
outside of the Gate; spray on the T-wall, "GATE CLOSED BY ORDER. NCOIC"; the Gate log on
the booth desk, the last line "212 held. Bitten: 1 (self). Chaining the gate." (the
highway, never a number, when it is spoken on the radio).

## Resupply

Lantern does not come back for a squad that has not earned it. Kills and objectives build
Resupply on Control's board; when it clears, a red flare brings a pallet down in twenty
seconds, loud, with three issues on it and one pick per soldier. Green smoke brings the bird
itself. The stores each position abandoned when it fell are still where they left them, if
you can get the lid off quietly, which you cannot.

---

# The Carrier

Canon as of 2026-11-09 (lobby place, Nova). Renamed from "the Fallow" by the owner
(2026-11-09: easier to understand); older docs and code comments that say "LORE.md > The
Fallow" mean this section.

The corridor runs north from the coast to the dam; Checkpoint Delta is the gate nearest the
sea. Command runs the corridor from offshore. The Carrier is a helicopter carrier pulled out
of the reserve fleet for Harlan: a flat deck, one island, a hangar under the deck, her old
hull number painted out and HARLAN sprayed over it. She holds station off the coast, past the
reach of anything that walks. Harlan Control works out of her Plot, every Lantern flies off
her deck, and every window team waits in her hangar until its window opens. The seat home at
Stand Down is a seat back to the Carrier.

The Infected cannot reach the ship. The one way aboard is Lantern, so everyone who steps off
a helo walks the screening lane at the deck edge (hose, hands, eyes, band), Pike included,
every time. Delta screened and failed. The Carrier screens and has not, yet.

Many window teams share the ship. They are **not** all Pike (owner and Nova, 2026-11-09):
how the other teams are called is open, for the lore developer.

- **Flight deck.** Numbered Lantern spots; a team launches by boarding its bird. By day smoke
  stands over the coast where the Burn has been; at night it shows orange.
- **Hangar deck.** Where the teams wait, and where they kit up (owner, 2026-11-09). Every
  soldier has a **record**: the kit signed to their name. A soldier buys kit onto it at the
  **Arms Room** with **merits**, which the Plot pays a window team for containment work done
  before the Burn (not "Requisition", which is the pallet cost). The desks: the **Arms Room**
  (the **Quartermaster** behind a wire cage: guns, sidearms, grenades, bought off the rack),
  the **Loadmaster** (Lantern's crew chief: he makes up each soldier's **Loadout**, what they
  carry and what is kicked out of the door, and they sign for it before they walk up the
  ramp), **Fires** (a fire support officer: your callsign on the
  Hammer, Anvil and Shrike nets), the **Engineers** (a sapper sergeant: Doorman, Tripline,
  Concertina). Desk crew wear ship or Army working dress, never Pike grey. The four desks
  are run by the same four people every visit: the Quartermaster (a sergeant first class,
  thirty years in arms rooms), the Loadmaster (Lantern's crew chief, who rides the door),
  Fires (a lieutenant) and the Engineers (a staff sergeant, a sapper). Voices and lines in
  [lore/desk_crew.md](lore/desk_crew.md).
- **The Plot.** Control's map room under the island, lit red. The corridor chart is a paper
  map on the table under tape and grease pencil (what it shows:
  [lore/world_map.md](lore/world_map.md)); the Containment Board on a lit perspex wall, five
  columns, written backwards by a plotter standing behind it. Contained is still not clean.
  The Plot is run by **Control's watch officer**, a major, the voice on Pike's radio; she
  talks like a desk (lines in [lore/desk_crew.md](lore/desk_crew.md)).
- **Ship's company.** Deck crew, a sentry, the screening medic, a mechanic and a runner walk
  the deck and the hangar while the teams wait. Who they are and what they say:
  [lore/ship_company.md](lore/ship_company.md).
- **The ship's dress.** The sponson guns are under canvas: they are aboard, and nothing that
  walks reaches her. The name on the transom is painted out like the hull number; the raised
  weld letters show faintly through the paint and cannot be read. She flies one flag from the
  flagstaff: plain yellow, the quarantine flag, because everything that comes aboard comes
  from the corridor.
- **The mark: HARLAN.** (2026-11-10, replaces HRD, which the owner did not like and which
  misread as NRD.) Every hull and airframe drawn from the reserve for the corridor has its
  old unit marks painted out and HARLAN sprayed over them by hand, white, in capitals: on the
  island, both bow sides, the deck's bow end and every Lantern. It means the thing belongs to
  Task Force Harlan and is quarantined with it: nothing that wears the word goes back to the
  fleet until the corridor is Contained. Soldiers say it is the one promise Command ever
  wrote down.

Keep it ours: the ship is shared and never upgraded by players (no ship modules), the board
is paper and perspex (no hologram), a team launches by boarding a helo (no drop pods), the
desks are people at counters (no rotating store: the rack has fixed prices, no sales, no
daily stock), and the PA is procedural (no propaganda).

| Cue | Line |
|---|---|
| Launch | "Pike, Control. Lantern on spot three, turning. Window opens on lift." |
| Recovery | "Lantern recovering, spot two. Screening party to the deck edge." |
| Board change | (no line; the plotter's grease pencil) |

## Lantern

Canon as of 2026-11-09 (owner approved).

Every lift bird off the Carrier flies as Lantern. Each is a medium utility helo drawn from the
same reserve fleet as the ship: one main rotor, a tail rotor, skids, a boxy cabin and a long
thin tail boom ending in a tall fin. It is built to carry one window team and nothing else:
two pilots, a crew chief, four Pike on canvas seats facing the door, and the bundles at their
feet.

- **The door.** The starboard cargo door slides all the way back and stays open in flight.
  The crew chief rides in it on a monkey strap, clipped to a kick rail along the sill.
  Everything the Loadmaster issues goes out of that door: slung cases, speedballs, pallets.
  The crew chiefs are the Loadmaster's people; at his desk on the hangar deck each soldier
  signs for their Loadout before boarding.
- **No door gun.** The pintle mount is still on the door frame, empty, its arm swung inboard
  and tied off. Lantern does not fight for its LZ. Pike holds it. When the squad needs a gun
  from the air, it calls Shrike.
- **The lamp.** A single amber lamp sits on the housing behind the rotor mast. It is lit
  whenever the rotor turns, day or night. Soldiers say it is what you look for when you have
  thrown green smoke and cannot see the smoke. Officially the name comes from the net; nobody
  believes that.
- **Reserve paint.** The paint is faded, with darker patches where the old unit markings were
  painted out and HARLAN sprayed over each one, as on the ship. The bird's number is stencilled
  in white on both nose doors and on the fin. The boom is sooted behind the exhausts. There is
  a tide line on the skids and lower cabin where the bird is hosed down at every recovery: the
  screening lane screens the helo too.
- **The tally.** On the inside of the door frame, at the crew chief's shoulder, there is a
  column of grease-pencil marks: a stroke for every seat taken out, a cross for every seat
  brought home. The crosses are behind.
- **Numbers.** "Lantern" is the callsign; the number is flight and aircraft. "Lantern 2-1" is
  the second flight's first bird, stencilled 21. The four birds on the Carrier's deck spots are
  21 to 24. A bird and a spot are not tied: Control gives the spot ("Lantern on spot three")
  and the bird answers with its number.

# Pike

Canon as of 2026-11-08 (owner: "just soldiers, like Helldivers"; the five Chosen are
retired, their sheets kept in [lore/retired_chosen.md](lore/retired_chosen.md)).

Command does not send heroes up the corridor. It sends window teams: four soldiers, a helo
and the time before the Burn. On paper each one is a Task Force Harlan recovery team;
everyone who has done it calls it "the window". Control knows a team by its callsign and a
soldier by a number. This team is Pike: Pike One to Pike Four, numbered in boarding order.
When a soldier goes down, Control says "Pike Three down", and whoever Lantern brings in next
is Pike Three again. The number belongs to the seat, not the man. In solo, the empty seats
are filled by soldiers called only by their numbers: Pike Two, Pike Three, Pike Four.

Pike wears grey fatigues (the garrison wore olive, and the olive is on the Infected now), a
black plate carrier with a PIKE tab, a helmet and a square on the shoulder and back in the
seat's colour: One blue, Two tan, Three white, Four orange. From behind in the dark, the
square tells you who is who. The name tape is the soldier's own name. Kit is the only other
identity. Build sheet in [CHARACTERS.md](CHARACTERS.md) section C.

## The Arms Room and the call-ins

The loadout menu is the **Loadout** (owner, 2026-11-09: signed for at the Loadmaster's desk).
The **Arms Room** (the Army's name for a unit armoury) is the Quartermaster's cage on the
Carrier, where kit is bought onto a soldier's record. Naming rules:

- **Guns** carry their plain real-world designation on the HUD ("M4A1 Carbine"), no
  nicknames. Starting list: M4A1 Carbine (default), M16A4 Rifle, Mossberg 590 Shotgun,
  MP5 SMG, M110 DMR, M17 Pistol (sidearm).
- **Fire missions** are named by the asset's radio callsign: the player is calling someone
  on the net.
- **Support weapons, emplacements and supply** take a soldier's word for the thing, with
  the designation in small type under it.
- **Delivery:** Lantern's crew chief kicks support weapons and supply out of the starboard
  door as a slung case or a speedball ([The Carrier > Lantern](#lantern)). Nothing falls from
  orbit.

| HUD name | Under it | Family |
|---|---|---|
| **Gun** | M240B machine gun | support weapon |
| **Goose** | M3 recoilless rifle (anti-tank) | support weapon |
| **Thumper** | M32 grenade launcher | support weapon |
| **Kettle** | M9 projector (flamethrower; the Burn crews' kit) | support weapon |
| **Hammer** | 81 mm mortar section, six rounds | fire mission |
| **Anvil** | 105 mm battery | fire mission |
| **Shrike** | helicopter gun run along a line | fire mission |
| **Doorman** | tripod sentry MG | emplacement |
| **Tripline** | anti-personnel minefield | emplacement |
| **Concertina** | wire obstacle | emplacement |
| **Speedball** | ammunition bundle | supply |
| **Aid Bag** | medical and plates drop | supply |

Retired 2026-11-08 as too far from the ground: Magpie (the quadcopter beacon) and Pen Coil
(the shock coil). Hammer and Anvil are a deliberate pair.

Radio, one line per family:

| Cue | Line |
|---|---|
| Fire mission call | "Hammer, Pike. Fire mission, my smoke, over." |
| Fire mission answer | "Hammer. Shot, over." |
| Supply call | "Lantern, Pike. Need a Speedball at my flare." |
| Supply answer | "Lantern. Kicking it now." |
| Gun run | "Shrike inbound. Mark your line." |

---

# Core Theme

The game is not about saving the world. The game is about **saving whoever can still be
saved**.

Players are not conquering the apocalypse. Players are surviving inside it. Every rescued
survivor matters. Every successful mission matters. Every failure has consequences. The
world is already broken. The goal is to preserve what remains.

---

# Tone

Balance: military survival, hope, desperation, heroism, dark humor.

The world is dangerous and often tragic, but it should not be relentlessly depressing.
Players should feel like they are making a difference. Even small victories should feel
meaningful.

---

# Character Philosophy

The soldiers are not characters; the corridor is. The people a player remembers are the ones
the strain finished: who they were, and what they still wear. A soldier is told apart by
seat colour and kit, and kit is supposed to change.

---

# Survivor Philosophy

Survivors are important. They are not background decoration. They represent what remains
of humanity.

Future gameplay may include: rescue missions, evacuations, defensive operations, escort
missions, supply recovery, medical assistance.

Survivors should make players feel responsible for something larger than themselves.

---

# Objective Philosophy

The game should eventually become more than endless zombie killing. Combat is important.
Progression is important. But the player's actions should feel purposeful.

Future objectives may include: protecting civilians, recovering supplies, defending safe
zones, establishing communication networks, extracting survivors, investigating outbreak
sites, securing military assets.

These objectives should reinforce the idea that humanity is still fighting back.

---

# Progression Philosophy

The player should begin each run as a capable survivor and gradually become a powerful
force capable of handling overwhelming odds. Progression should create stories. The most
memorable moments should come from unexpected combinations of upgrades, weapons,
objectives, and encounters.

---

# World Building Rules

- Avoid magic, supernatural explanations, and fantasy themes.
- Technology stays grounded in military, scientific, and emergency-response concepts.
- The infection may evolve in unusual ways, but the setting remains a believable
  apocalypse.

---

# Long-Term Vision

The ideal player experience:

> "I entered a ruined city, rescued trapped civilians, defended a radio tower, survived an
> overwhelming zombie attack, found powerful equipment, completed critical objectives, and
> escaped feeling like I actually helped humanity survive another day."

The game should feel like a story generator. Every run should create memorable moments.
Players should remember the people they saved, the objectives they completed, and the
impossible situations they survived.
