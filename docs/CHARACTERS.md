# Characters: the Infected, the Index hosts, the Chosen

Build sheets for every body in the game. Written by the lore developer 2026-11-07 for the
body redesign; the engineer models straight from these in `assets/3d/build/build_assets.py`.
Constraints every sheet obeys: stock R15, one mesh per limb inside its box (left/right
shared), flat facets from the palette (`docs/STYLES.md` §2), budgets from §6 (3,000 tris
per Infected, 5,000 for Brute/Index). Asymmetry lives on the head and torso only, or on
attached parts (the Hocker sac proves attached parts work).

Status: Walker, Runner, Brute and Hocker rebuilt to these sheets 2026-11-07 (list kept in
`docs/STYLES.md` §7); everything else is sheet only.

## The two rules that make the roster read

**1. The strain has two colours, the same on every form.** New tissue is *rebuilt*: pale,
waxy, bloodless, like scar over bone (`rebuilt` row). Where the agent is actively working it
is wet and caustic yellow-green (`strain` row). Eyes stay two `infected green` facets. Blood
stays `red.m`, and only where the strain tore through *fresh*; old damage is `rebuilt`, not
red. The further down the roster, the more `rebuilt` and the less skin and cloth is left.

**2. The silhouette ladder.** Walker stands like a person. Runner leans forward. Brute is
wider than tall. Hocker throws its head back. Bloat is a sphere on legs. Shedder is a tall
banded stack. Crawler is knee-high. Kite is a wedge. Growth is a mound. Nine outlines, none
shared.

Who they were: the corridor fell by trying to help, so every form still wears the thing
that was done to help it (a screening band, a bandage over the bite, cut restraints, an IV).

---

## A. The Infected

### Walker (scale 1.0, ~1,800 tris)
- **Was:** a civilian from the pens, screened at Delta and held. The strain's first day.
- **Silhouette:** the only Infected that stands upright. One shoulder dropped (old wound,
  on the torso mesh), arms hanging, head down and slightly forward. Flat shuffle.
- **Head:** bare; hair a flat `dark.m` cap cut short on one side; `infected skin` face;
  green eyes; mouth a closed `dark.d` line. A `rebuilt.m` seam from the jaw down the neck.
- **Torso:** civilian: `tan.m` jacket over a `white.d` shirt, jacket torn open on the
  dropped-shoulder side showing `infected skin` and a slab of `rebuilt.m` where the ribs
  were re-set. A `foliage` blanket (the pens issued them) tied round the waist like a shawl,
  hanging to the thigh at the back: this is what reads from behind.
- **Arms/hands:** sleeves to the elbow, `infected skin` forearms, fingers curled. The Delta
  **screening band**: `white.m` paper band with one `red.m` stripe on the wrist.
- **Legs/feet:** `asphalt` civilian trousers, one knee a `rebuilt` knot, `dark` shoes.
- **Tell:** the `rebuilt` seams at jaw and ribs: wounds that closed too well.

### Runner (scale 0.9, ~2,200 tris)
- **Was:** a soldier of the Delta garrison. The agent did what it was built to do.
- **Silhouette:** forward lean from the hips, shoulders up and no neck, arms long with
  hands at knee height. From behind, a ridge of cable-tendons down the spine.
- **Head:** helmet gone; `infected (runner)` skin, scalp bare; jaw clenched, teeth a
  `white.d` strip; green eyes; brow a `rebuilt.d` ridge.
- **Torso:** plate carrier torn off (two `dark` strap stubs on the shoulders), a `gun.d`
  T-shirt split up the middle by the chest growth: `infected (runner)` muscle blocks with
  `rebuilt.l` tendon lines across the pecs and down the spine (back ridge: a stepped spine
  of 5 blocks). `red.m` at the tear edges: this one is fresh. Dog tags: two `gun.l` facets
  on a `dark` cord.
- **Arms/hands:** sleeves gone, muscle banded (3 stepped blocks per upper arm), elbow a
  `rebuilt.l` knob, hands open, fingers long and splayed, knuckles `rebuilt.l`.
- **Legs/feet:** `olive.m` fatigue trousers blown at the knees, calves banded, `dark`
  combat boots, laces trailing (a `tan.d` strip on the foot).
- **Tell:** the tendons: pale cable over yellow muscle, every joint knotted.

### Brute (scale 2.0, ~3,000 tris)
- **Was:** a Delta soldier who took massive trauma and was rebuilt around the breaks.
- **Silhouette:** wider than tall: a bone shelf over both shoulders rises above the head,
  the head sunk between. Knuckles drag. From behind, the shelf and a split pack.
- **Head:** small for the body; skull plated in `rebuilt.m` with a helmet split in two
  halves still strapped on (`olive.d` halves either side of a `rebuilt.l` crest, chin strap
  `dark`). Green eyes deep under the brow. Jaw `infected (brute)`.
- **Torso:** the shelf: two `rebuilt` bone slabs growing out of the upper torso top-front
  and top-back, ribs as `rebuilt.m` bars down the chest. A plate carrier that no longer fits
  hangs open on one side (`olive.d` panel, `dark` straps), the plate cracked. A burst
  assault pack on the back, `olive.m`, one strap.
- **Arms/hands:** forearms thicker than the upper arms (`infected (brute)` skin, 3
  `rebuilt.m` spurs along the ulna), fists with `rebuilt.l` knuckle plates.
- **Legs/feet:** `olive.m` trousers torn to the thigh, shins plated `rebuilt.m`, `dark.d`
  boots split open at the toe by bone.
- **Tell:** bone where there should be joints. Headshot x1.25 is the plated skull: the crest.

### Hocker (scale 1.0, ~2,200 tris; sac stays an attached part)
- **Was:** a Walker a day further on. The agent found the throat and lungs.
- **Silhouette:** head thrown back, chest caved, elbows clamped to the ribs, hands up at the
  collarbones: a heron. The sac under the jaw is the widest thing on it.
- **Head:** jaw split at the chin into two halves (`infected skin` outside, `strain.d`
  inside), tilted up 20 degrees; nose and lips gone to `rebuilt.m`; green eyes rolled up.
- **Torso:** the Walker's `tan.m` jacket, soaked: a `strain.d` stain from the collar. Chest
  hollow (front of the upper torso concave). A `white.m` surgical mask pulled down round
  the neck, under where the sac sits.
- **Arms/hands:** folded against the chest in the mesh (upper arm angled in, lower arm
  vertical, hands at the collar, fingers hooked). `infected skin`, `rebuilt.m` wrists.
- **Legs/feet:** as the Walker, knees slightly bent.
- **Tell:** the sac: `strain.m` with a `strain.l` highlight facet, swells 1.8x on windup.

### Bloat (scale 1.1, BodyDepth/WidthScale 1.35, ~2,400 tris)
- **Was:** a passenger on a sealed Mile 14 bus. Bitten, bandaged, three days in the heat
  with nobody to pass to; the agent filled the body instead.
- **Silhouette:** a sphere on legs. Arms out to the sides for balance, head tiny on top.
- **Head:** `infected skin`, face swollen flat, green eye slits, cheeks `rebuilt.l`, hair a
  `dark.m` cap.
- **Torso:** both torso boxes sculpted into one bulge, `white.d` at the equator going to
  `rebuilt.l` at the sides, 6-8 `strain.d` veins as thin raised strips. A shirt that no
  longer closes: two `tan.m` flaps with `brass` buttons popped. One attached `strain.m`
  sphere at the navel that swells 1.3x in the last second before it bursts.
- **Arms/hands:** swollen `rebuilt.l` forearms, fat short fingers, the **bite bandage** on
  the forearm: `white.m` wrap with `red.m` bled through.
- **Legs/feet:** knees bowed out, `asphalt` trousers split up the thigh, `dark` shoes.
- **Tell:** the pale belly with green veins. (Optional Transparency 0.1 on the torso parts.)

### Shedder (scale 1.15, ~2,800 tris)
- **Was:** a Kestrel ward patient. Given time, the agent partitioned the body.
- **Silhouette:** tall and thin, banded like a stack with a dark ring at every seam; a
  second pair of small arms folded flat against the ribs.
- **Head:** bald, `infected skin`, skull seamed front to back (`strain.d`), green eyes,
  mouth open and black.
- **Torso:** `white.m` hospital gown open at the back (spine visible, seamed across three
  times). Seams: `strain.d` grooves ringing the upper torso twice and the lower torso once,
  each edged `rebuilt.l`. Two small `rebuilt.m` arms (3 blocks each) folded against the
  lower ribs, on the upper torso mesh. A Kestrel ID band on the gown's hem.
- **Arms/hands:** long, seamed at the elbow, **cut restraint cuffs**: `tan.d` leather with
  a `gun` buckle on each wrist, strap cut short.
- **Legs/feet:** bare `infected skin`, seamed at the knee, cut cuffs on the ankles, bare
  feet with `rebuilt.l` toes.
- **Tell:** the seams. Count the segments before it dies: 2-3 Crawlers.

### Crawler (scale 0.45, Runner clip, ~700 tris)
- **Was:** a segment shed from a Shedder. Not a person; a delivery.
- **Silhouette:** knee-high, a torso with arms and no real legs, fast on its hands.
- **Head:** a `rebuilt.m` knob with two green eyes and a `strain.d` slit.
- **Torso:** one segment, `infected skin` front, `rebuilt.m` back, a `strain.d` raw ring
  where it broke off (top of the upper torso), a scrap of `white.m` gown caught on it.
- **Arms/hands:** the whole animal: long, `rebuilt.m`, fingers splayed as claws.
- **Legs/feet:** stubs: upper leg a `rebuilt.d` knot, lower leg and foot minimal.

### Kite (non-Humanoid mover, 4 parts, ~600 tris, S4)
- **Parts:** body: a wedge 2.5 studs, `rebuilt.m` top, `strain.d` underside, green eye pair
  at the point. Two wings: flat ribbed fans 3 studs span, membrane `rebuilt.l`, 4 ribs
  `rebuilt.d`, a `strain.m` vein on the leading edge. Tail: a 2-stud `rebuilt.d` strip with
  a scrap of `warning orange` hi-vis caught on it.
- **Motion:** wings hinge 25 degrees on a Motor6D; dive = body pitch 60 down, wings back.

### Growth (no mover, 6 parts, ~1,200 tris, S4 nests / S5)
- **Was:** a Harlan Yard rail worker rooted where he fell, bent double into the mat.
- **Parts:** mat: irregular 8-stud disc, `rebuilt.m` with `strain.d` veins radiating. Host:
  torso-and-head bent forward, face down into the mat, `warning orange` hi-vis with `gun.l`
  strips, arms sunk to the elbow. Three `strain.m` sacs 1.5 studs behind the host, each
  swells and opens (`strain.d` slit) to release a Crawler. Two `rebuilt.d` root cables to
  the nearest wall or rail.
- **Burn:** fire turns the sacs `asphalt.d` and the veins black; a burnt Growth stops.
- **Reservoir variant:** `white.m` lab coat instead of the hi-vis.

---

## B. The Index hosts (5,000 tris, boss, health bar)

### The Warden (Delta; scale 2.3)
- **Was:** the Delta MP who ran the Gate. The strain grew his riot kit into him.
- **Head:** riot helmet fused to the skull, `dark.m` shell, `gun.l` visor cracked and set
  into the `rebuilt` brow; green eyes behind it.
- **Torso:** the Brute's bone shelf under `dark` riot plates (chest, shoulders, back); a
  `white.m` **MP brassard** with `dark.d` letters on the upper arm; a `dark` radio handset
  on its coiled cord grown into the chest plate.
- **Arms/hands:** `rebuilt` spurred forearms; the **riot shield** grown into the left
  forearm as an attached part (`dark.l`, 2 studs wide, `gun.l` window).
- **Legs/feet:** `dark.d` shin guards, `olive.m` trousers, `dark.d` boots.
- **Mechanic:** six plates (helmet shell, chest, back, both shoulders, shield) are attached
  parts with their own health; each one off reveals `rebuilt` bone and a `strain.d` seam.

### The Bloat (Mile 14; scale 1.6, depth/width 1.5)
- **Was:** the driver of the lead bus. Sealed the bitten aboard, then was bitten himself.
- **Read:** a common Bloat half again as large in a `gun.l` transit shirt with a `brass`
  name badge, the **seatbelt still on**: a `dark.m` strap cutting a groove into the belly,
  `gun.l` buckle. `tan.d` company cap split by the swelling; a `tan.d` driver's glove.
- **Mechanic:** two navel spheres swell over the last two seconds; death cloud `strain.m`
  at Transparency 0.5.

### The Patient (Kestrel; scale 1.3)
- **Was:** the first Kestrel patient given the antiviral. Half a person, half rebuilt,
  visibly healing in real time.
- **Read:** asymmetry: the right side is a person (`infected skin`, gown, hair), the left
  is `rebuilt` with the seams lit. Half face, half `rebuilt.l` plate, a `white.m` oxygen
  mask hanging off one ear. `white.m` gown open; left ribs `rebuilt.m`; an IV line
  (`white.l` strip, `white.d` bag) on the left forearm and torso. **Uncut restraints**:
  `tan.d` cuffs buckled, straps trailing 1 stud, at wrists and ankles. Bare feet.
- **Mechanic:** on a regen surge every `strain.d` seam goes Neon `strain.l` and the
  rebuilt side scales 1.05; damage windows are when the seams go dark.

### The Lineman (Harlan Yard; scale 1.4)
- **Was:** a Yard switchman finished as a Runner, built to pull.
- **Read:** a Runner's lean with arms too long (hands below the knees), a `warning orange`
  hi-vis vest with `gun.l` strips: the brightest Infected in the game. Jaw split like a
  Hocker's, mouth an open black box; a dark `gun` headlamp still strapped on. Ribcage a
  ribbed `rebuilt.m` bellows under the vest; one attached `rebuilt.l` chest part scales
  1.4x on the call. A `gun.d` **coupling chain** (8 links) round the right forearm and hand.
  `asphalt` work trousers, `dark` boots, calves roped.
- **Mechanic:** chest swells, jaw opens, every Infected turns: shoot the chest on the swell.

### The Specimen (Reservoir; scale 2.5)
- **Was:** the program's live host. Every form was rehearsed here first.
- **Read:** every tell at once on a Brute frame under **lab restraints**: a `dark`
  four-point harness with `gun` rings, `white.l` sensor leads taped to skull and chest, a
  `white.m` station ID band, a `white.m` lab-coat sleeve caught in the harness. Warden's
  fused brow, Hocker's split jaw, Brute's shelf, Shedder's seams, Bloat's belly, Lineman's
  bellows chest and chain, bare feet in ankle restraints.
- **Mechanic:** attached parts leave as the phases go (plates, belly spheres, seams shed
  Crawlers, then the call). What is left is a `rebuilt` body with a `white` ID band.

---

## C. The Chosen

**Decision (2026-11-07): the Assault is a fifth Chosen, not one of the four.** The shipped
kit (dash, breach charge, Combat Momentum) is a rifleman's kit; each named Chosen has an
obvious kit that is not that. He is **Staff Sergeant Isaac Weller**, Pike's rifleman, the
default pick. Four of five deploy per run.

**The squad-shared element: the Pike carrier.** Every Chosen (and the dog) wears the same
`dark` plate carrier: a `white.m` "PIKE" tab on the left shoulder strap and one square
patch (0.34 x 0.2) on the left shoulder and one on the top of the back panel, in the
wearer's colour. From behind in co-op: five identical carriers, five coloured squares. The
Infected never wear `dark` carriers, and the Chosen's trousers are `gun` grey, which no
Infected wears (the corridor garrison was olive). Grey means "came in on Lantern".

Colours: Weller `friendly blue`, Cole `tan.l`, Reyes `white.l`, Cross `dark.d` with a
`gun.l` border, Kane `warning orange`. Faces: skin `tan.l`/`tan.m`, two `dark.d` eye
facets, a brow line, a mouth line. ~2,500 tris each, rifle unchanged.

### Isaac Weller, Assault (`pc_assault`)
- **Silhouette:** helmet, squared shoulders, the straightest back in the squad.
- **Head:** `dark.m` ballistic helmet with NVG mount, chin strap; face `tan.m`, short
  `dark.d` hair at the sides, a `dark.d` beard line; `gun.l` IR strobe on the helmet back.
- **Torso/gear:** `gun.m` fatigue blouse, Pike carrier with three `gun.d` mag pouches and a
  `dark` radio; two `red.d`-handled **tourniquets**, one on each shoulder strap.
- **Arms/hands:** sleeves down, `dark` gloves, blue square on the left sleeve.
- **Legs/feet:** `gun.m` trousers, `dark` knee pads, `dark` boots.

### Mason Cole, K-9 handler (`pc_k9`)
- **Silhouette:** patrol cap and a coiled leash on the hip; a dog beside him.
- **Head:** `tan.m` patrol cap, flat brim; face `tan.m`, grey at the temples (`gun.l`).
- **Torso/gear:** `olive.m` fatigue blouse (the one olive top; he was Army before Pike)
  under the Pike carrier, `tan.d` dump pouch and `tan.d` tug pouch on the right hip, the
  **leash** coiled `tan.m` with a `gun` clip on the left hip; a chewed `tan.l` tug toy
  hanging from the dump pouch.
- **Arms/hands:** sleeves rolled, `tan.m` forearms, `dark` gloves, tan square.
- **Legs/feet:** `gun.m` trousers, `dark` boots, a stuffed `tan.d` cargo pocket.

### Kilo, the dog (4 parts, ~900 tris)
- Belgian Malinois, male. 3 studs nose to tail base, 1.8 at the shoulder.
- **Parts:** head with ears up (`tan.m`, `dark.m` mask, `dark.d` ears/eyes/nose); body with
  tail (`tan.m` back to `tan.l` chest, `dark.m` saddle) wearing the **harness**: `dark`
  straps, `tan.l` grab handle, Cole's tan square on the left side, `gun.l` IR strobe, a
  small `tan.d` first-aid pouch; front legs as one mesh and hind legs as one mesh (`tan.m`,
  `dark.d` lower legs). Two Motor6Ds (front, hind) rock for the gallop.

### Dr. Elena Reyes, epidemiologist (`pc_epi`)
- **Silhouette:** white jacket and a respirator: the only white and the only covered face.
- **Head:** `white.m` hood up over `dark.d` hair tied back; `gun.d` half-face respirator
  with two `gun` filters; `gun.l` goggle lenses on a `dark` strap; face `tan.l` above.
- **Torso/gear:** `white.m` field jacket (`white.d` seams) under the Pike carrier; a
  `white.d` sample pouch on the right chest with three `white.l` vials with `red.d` caps;
  a sharpie clipped to the carrier; a hospital ID badge on a `gun.l` lanyard.
- **Arms/hands:** jacket sleeves, `white.d` nitrile gloves (the only non-black gloves).
- **Legs/feet:** `gun.m` trousers, `dark` boots, `white.d` knee pads.

### Ava Cross, recon (`pc_recon`)
- **Silhouette:** hood and boonie brim, face wrap, whip antenna over the right shoulder.
- **Head:** `dark.m` hood under a `dark.m` boonie brim, `dark.d` face wrap to the nose,
  face `tan.m`, a `tan.d` pencil behind the ear.
- **Torso/gear:** `dark.l` smock under the Pike carrier, a `dark` radio with a 2-stud
  `gun.d` **whip antenna** on the back panel, a `dark.d` notebook in a chest pocket, a
  sheathed `dark` knife on the left strap; name tape blacked out with `dark.d` tape.
- **Arms/hands:** `dark` gloves, `dark.d` square with `gun.l` border, sleeves down.
- **Legs/feet:** `gun.m` trousers, `dark.d` boots, no knee pads.

### Victor Kane, field engineer (`pc_engineer`)
- **Silhouette:** hard hat and coveralls, a pry bar across the back. Thickest torso.
- **Head:** `warning orange` hard hat with a `dark` headlamp, "KANE" in `dark.d` marker;
  face `tan.l`, `tan.d` moustache.
- **Torso/gear:** `olive.l` coveralls under the Pike carrier; `gun` tool pack on the back
  with a `rust.l` **pry bar** across it; `dark` tool belt with a `gun.l` wrench, a `tan.m`
  tape roll and a `brass` carabiner.
- **Arms/hands:** sleeves rolled, `tan.l` forearms, `tan.d` work gloves, orange square; a
  strip of `warning orange` tape on the left wrist.
- **Legs/feet:** coveralls, `rust.d` work boots with `gun.l` toe caps, `olive.d` knee pads.
