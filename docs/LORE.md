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

Command lost the Harlan quarantine corridor. The Chosen go up it by helo, one fallen
position at a time, toward the station that started it. Each place failed the same way:
from the inside, by trying to help. Road signs count down the distance to Harlan; the sky
goes from evening to night to dawn.

1. **Checkpoint Delta** — the southern screening gate. Boss: the Warden.
2. **Mile 14** — the stalled evacuation convoy on the highway. Boss: the Bloat.
3. **Aid Station Kestrel** — a high school turned field hospital. Boss: the Patient.
4. **Harlan Yard** — the rail yard. Boss: the Lineman.
5. **Harlan Reservoir Station** — the dam and the research station. Boss: the Specimen.

**Control, Lantern, the Burn.** Harlan Control runs the corridor net; the squad is Pike; the
helo that carries the Chosen is Lantern, the only thing that stays the same and the only way
out. Command sanitizes what it cannot hold: each district has a scheduled incendiary fire
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

# The Chosen

As governments began to fall, intelligence agencies and military leadership identified a
handful of individuals who possessed extraordinary skills considered critical to humanity's
survival. These individuals became known informally as **"The Chosen."**

Each possesses expertise that cannot easily be replaced. They are not superheroes. They are
specialists. The world needs them because ordinary solutions have already failed. While
countless soldiers and civilians continue to fight for survival, these individuals are
uniquely capable of carrying out missions that nobody else can.

Five of them make the squad Control calls Pike; four deploy on any mission. They came in on
Lantern and dress like it: grey fatigues (the corridor garrison wore olive, and the olive is
on the Infected now) under the Pike carrier, one black plate carrier with a PIKE tab on the
left shoulder and one square patch on the shoulder and back in the wearer's own colour.
Weller blue, Cole tan, Reyes white, Cross black with a grey border, Kane orange. From
behind in the dark, the square is how a squad knows who is who. The dog wears one too.
Build sheets in [CHARACTERS.md](CHARACTERS.md).

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

Characters should be memorable because of their personalities, beliefs, and roles within
the world. Characters should NOT be defined solely by their weapons. Weapons may change
during a run; a character's identity should remain recognizable regardless of equipment.
A player should be able to describe a character without mentioning their gun.

---

# The squad

Canon as of 2026-11-07 (the Assault became Weller when the roster was redesigned).

## Staff Sergeant Isaac Weller — Assault

Pike's rifleman and the default pick. Infantry, by the book, the one who does it the way
soldiers are trained to. Carries two tourniquets where everyone else carries one. Believes
the plan is the thing that gets people home.

## Mason Cole — K-9 Handler

Veteran military working dog handler. Protective of civilians. Practical. Calm under
pressure. Believes nobody should be left behind. His dog is his partner, not equipment.
His dog is Kilo, a Belgian Malinois, male, in a black harness with a grab handle and
Cole's tan square on the side. Cole carries Kilo's spare tag on his own chain.

## Dr. Elena Reyes — Epidemiologist

Expert in infectious diseases. Searching for answers behind the outbreak. Focused and
analytical. Still believes humanity can recover. Often places civilian lives above
military objectives.

## Ava Cross — Recon Specialist

Scout and intelligence operative. Independent. Confident. Comfortable operating behind
enemy lines. Believes information is often more valuable than firepower.

## Victor Kane — Field Engineer

Problem solver. Builder. Logistics expert. Keeps equipment and operations functioning
despite impossible circumstances. Views preparation as the difference between life and
death.

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
