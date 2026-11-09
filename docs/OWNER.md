# What the owner wants (read before proposing anything)

Every rule here is something the owner (Tien) asked for or pushed back on. Agents and
engineers read this first; a proposal that breaks one of these is wrong even if it is
clever. Each line: the rule, then where it came from. Add a line when the owner corrects
something; never delete one without the owner.

## How to work with the owner

- **Recommend, don't hand over menus.** First game, not a designer: bring one clear
  recommendation with the reason. Options only when they are stuck. (2026-11-06)
- **Plain words.** No jargon, short answers. The owner says they are "bad at explaining":
  when a request is fuzzy, play it back in your own words before building. (2026-11-09)
- **Visible progress keeps them going.** A bland-looking build loses them; ship things they
  can see and show screenshots. (2026-11-06)
- **They play between sessions.** Ask what felt wrong before building more; measure in a live
  playtest. Never take over or restart their running playtest without asking. (2026-11-07)
- **The repo is the memory.** Every change carries its docs; keep always-loaded docs short.
  (2026-11-05)

## The game

- **Grounded, not sci-fi.** Near-future military bio-horror. Helldivers 2 is the structure
  (loadout, call-ins, missions, extraction), never the names, factions or look. Call-ins
  must be things a real army could field: mortars, a gun run, a sentry, wire, supply drops;
  no drones with lasers, no shock coils. (2026-11-08)
- **No hero characters.** Players are anonymous soldiers, Pike One to Pike Four (bots Pike
  Two to Four in solo). The Chosen (Weller, Cole, Reyes, Cross, Kane) are retired.
  (2026-11-08)
- **Names:** one map is a **mission**, three missions are an **operation** (the Helldivers
  convention). (2026-11-08)
- **Power is the loadout,** never stat items: guns, grenade, kit, call-ins, a few big field
  upgrades. (2026-11-07)
- **Real guns.** Each gun fires at its real-world rate (M16A4 750 rpm, M249 ~800, ...);
  balance damage and ammo around that, not the other way. (2026-11-08)
- **The run is the story.** The story is what the squad lived through on that run, not
  lore text or builds. Design toward moments players retell. (2026-11-09)
- **Guns are ones we can get a free 3D model for.** The weapon roster is limited to real
  guns with a free model online (licence must allow use in a commercial Roblox game; keep
  the source and licence in `assets/3d/ASSET_IDS.md`). No gun gets designed or tuned that
  has no model. (2026-11-09)
- **It must feel satisfying.** Kick, shake, limp bodies, flinch, limbs that come off when
  shot (dismemberment stays). Feedback is part of the design, not polish. (2026-11-08)
- **Modular loadouts.** Nova is building the loadout and weapon selection screens; guns and
  call-ins will be added, swapped and cut. Anything per item (kick, shake, heavy, reload
  clip, icon, sound) lives on that item's own Config/definition row with a default. Never a
  hard-coded list of item names in a system. (2026-11-09)
- **Transitions are a fade, not a loading card.** Fade to black with the helicopter sound, Roblox's
  own loading screen on a teleport, fade in on the pad with the drop-off sound; the same between
  missions. No custom ride card or teleport screen for now. (2026-11-09)
- **Loadout is chosen in the lobby** once the lobby exists; the in-mission Arms Room (B) is
  a stand-in. (2026-11-08)

## How it looks and sounds

- **Blocky Roblox style for the Infected,** lore-accurate poses and costumes. A rounded,
  sculpted low-poly redesign was built and rejected: "I like the blocky Roblox style".
  (2026-11-08)
- **No zombie green.** Resident Evil bio-horror skin: pallor, bruises, lesions, pustules,
  exposed flesh, wet reds. (2026-11-07)
- **Nothing clips or flickers.** No parts through each other, no z-fighting, anywhere; check
  placements and coplanar faces before shipping. (2026-11-08)
- **Backgrounds must look real.** Flat slabs read as "goofy"; the skyline is modelled towers.
  (2026-11-08)
- **Bosses are their own design.** The Warden was rejected as "a Brute with riot armour
  slapped on": a singular asset gets its own silhouette and its own build file.
  (2026-11-07)
- **Build 3D in live Blender and look at it** (Blender MCP); headless only for the final
  export. (2026-11-07)
- **No harsh sound.** The ambience beds were turned off because they "hurt my ears";
  regenerate before re-enabling. Every boss gets its own sound bank; every speaker a sound
  profile so its clips match. (2026-11-08)
- **UI direction:** Prototype 2's HUD, adapted to a squad shooter. (2026-11-08)

## Rules already decided

- Razor wire (Concertina) can never be vaulted. (2026-11-08)
- Q dash and E breach are gone: Q swaps guns, G frag, V shove, E stim, 1-4 call-ins, 5 flare.
  (2026-11-08)
- Movement keys: roll and slide need too many key combos; the owner wants a Helldivers-like
  answer, not decided yet. Do not change the bindings without them. (2026-11-08)

## Team and accounts

- **Nova** (second developer) owns the lobby and the loadout screen; bugs in those files go
  to Nova. (2026-11-09)
- **The Roblox group Boomin Dev Studios** (270506601) owns the game ("Co-op Zombie Shooter",
  place 87556879379942) and every uploaded asset; upload with `groupId`. (2026-11-09)
- Nothing goes to `main` without the owner; never print or commit keys or tokens.
