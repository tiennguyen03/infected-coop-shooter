# Characters: the Infected, the Index hosts, Pike

Build sheets for every body in the game. Written by the lore developer 2026-11-07 for the
body redesign; the engineer models straight from these in `assets/3d/build/build_assets.py`.
Constraints every sheet obeys: stock R15, one mesh per limb inside its box (left/right
shared), flat facets from the palette (`docs/STYLES.md` §2), budgets from §6 (3,000 tris
per Infected, 5,000 for Brute/Index). Asymmetry lives on the head and torso only, or on
attached parts (the Hocker sac proves attached parts work).

Status: Walker, Runner, Brute, Hocker and the player body (then the five Chosen, retired 2026-11-08) rebuilt to these sheets 2026-11-07
(list kept in `docs/STYLES.md` §7); everything else is sheet only. Skin v2 (art director,
2026-11-07) repainted the four built Infected: where a sheet below says `infected skin` read
`pallor` (the Bloat reads `flesh`), the Runner's muscle is `wound`, the Brute's skin `bruise`;
each built form carries a **Skin v2** line with what changed. Palette rows in `STYLES.md` §2.

## The two rules that make the roster read

**1. The strain has two colours, the same on every form.** New tissue is *rebuilt*: pale,
waxy, bloodless, like scar over bone (`rebuilt` row). Where the agent is actively working it
is wet and caustic yellow-green (`strain` row), and only where it is working: open seams, the
Hocker's throat and sac, Bloat veins, Warden seams; never skin. Eyes are two milky `pus.l`
facets set in a `wound` rim (skin v2 canon; the green eyes in the sheets below are superseded).
Blood stays `red.m`, and only where the strain tore through *fresh*; old damage is `rebuilt`,
not red. Infection on skin is boils (`pus` domes with a `pus.l` head), lesions (a `flesh.d` rim
round a `wound` core) and bruise blotches, all as geometry. The further down the roster, the more `rebuilt` and the less skin and cloth is left.

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
  milky `pus.l` eyes in a `wound` rim; mouth a closed `dark.d` line. A `rebuilt.m` seam from
  the jaw down the neck.
- **Torso:** civilian: `tan.m` jacket over a `white.d` shirt, jacket torn open on the
  dropped-shoulder side showing `infected skin` and a slab of `rebuilt.m` where the ribs
  were re-set. A `foliage` blanket (the pens issued them) tied round the waist like a shawl,
  hanging to the thigh at the back: this is what reads from behind.
- **Arms/hands:** sleeves to the elbow, `infected skin` forearms, fingers curled. The Delta
  **screening band**: `white.m` paper band with one `red.m` stripe on the wrist.
- **Legs/feet:** `asphalt` civilian trousers, knees knotted `rebuilt` (limbs mirror), `dark` shoes.
- **Tell:** the `rebuilt` seams at jaw and ribs: wounds that closed too well.
- **Skin v2 (built):** `pallor` skin; an open lesion on the left cheek and a bruise blotch on
  the right temple; a four-boil cluster along the jaw next to the seam, which now weeps a
  thin `strain.d` line; a `flesh` flush round the rib slab; hands swollen `flesh`, filling
  the box, a bruise and one pustule on the back. Limbs: rounded tan shoulder, octagonal
  sleeve and forearm tapering to the band, hip inset, knee cap under the trouser. 1,528 tris.
- **Accuracy pass (2026-11-08, lore developer), staying blocky.** All four built forms
  stand in the same neutral pose, so the silhouette ladder does not read: fix posture in
  the torso/head meshes (or idle clips) before adding detail.
  - Drop one shoulder: lower one side of the torso block about 0.2.
  - Tilt the head down and forward.
  - The pens blanket reads as a thin green belt: make it a slab hanging to mid-thigh at the
    back, the read from behind.
  - Trousers read black; the sheet says `asphalt`.
  - The screening band is a dot: make it bigger and whiter, it is the story detail.

### Runner (scale 0.9, ~2,200 tris)
- **Was:** a soldier of the Delta garrison. The agent did what it was built to do.
- **Silhouette:** forward lean from the hips, shoulders up and no neck, arms long with
  hands at knee height. From behind, a ridge of cable-tendons down the spine.
- **Head:** helmet gone; `infected (runner)` skin, scalp bare; jaw clenched, teeth a
  `white.d` strip; milky `pus.l` eyes in a `wound.d` rim; brow a narrow `rebuilt` bone ridge.
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
- **Skin v2 (built):** flayed: `wound` muscle everywhere skin was (face, chest, arms, blown
  knees, calves) under `rebuilt.l` tendon cables, with `pus.d` weep strips down the face,
  sternum, under the pecs and down every limb; eyes in a `wound.d` rim; nose gone to bone;
  a `wound.d` torn patch on the side of the head. Limbs: the hardest taper on the roster
  (forearm 0.40 to 0.32), bone knobs (`rebuilt.l` caps) at elbow and knee. 1,880 tris.
- **Accuracy pass (2026-11-08, lore developer), staying blocky.**
  - No forward lean: pitch the torso about 20 degrees at the hips.
  - Raise the shoulders so it has no neck.
  - Hands sit at the hips: lengthen forearms and hands to hang at the knees.
  - The spine ridge needs five stepped blocks that read in profile.
  - Dog tags are missing.

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
- **Skin v2 (built):** `bruise` skin; three boil clusters under the shelf on the bare right
  side of the chest; a `flesh` goitre at the base of the neck with a weeping pustule; a jaw
  lesion and a `bruise.d` blotch on the head; two lesions on each thigh. Forearms swollen
  (fill the box, `bruise.d` strike bruise, one pustule) over thinner tapered upper arms;
  shoulder caps in the olive sleeve stub. 2,080 tris.
- **Accuracy pass (2026-11-08, lore developer), staying blocky.**
  - It is taller than wide, which breaks rule 2: widen the torso, shorten the legs.
  - The shelf is a flat collar: raise both slabs above the crown so the head sits in a
    trench between them.
  - Lengthen the arms so the knuckles drag.
  - The split pack on the back is missing.

### Hocker (scale 1.0, ~2,200 tris; sac stays an attached part)
- **Was:** a Walker a day further on. The agent found the throat and lungs.
- **Silhouette:** head thrown back, chest caved, elbows clamped to the ribs, hands up at the
  collarbones: a heron. The sac under the jaw is the widest thing on it.
- **Head:** jaw split at the chin into two halves (`infected skin` outside, `strain.d`
  inside), tilted up 20 degrees; nose and lips gone to `rebuilt.m`; milky `pus.l` eyes set
  high under the hairline (rolled up).
- **Torso:** the Walker's `tan.m` jacket, soaked: a `strain.d` stain from the collar. Chest
  hollow (front of the upper torso concave). A `white.m` surgical mask pulled down round
  the neck, under where the sac sits.
- **Arms/hands:** the heron pose (elbows clamped, hands at the collar) comes from the Hocker
  clips; the mesh arms hang straight with the fingers hooked (the pose does not fit the R15
  limb boxes). `infected skin`, `rebuilt.m` wrists.
- **Legs/feet:** as the Walker, knees slightly bent.
- **Tell:** the sac: `strain.m` with a `strain.l` highlight facet, swells 1.8x on windup.
- **Skin v2 (built):** `pallor` skin; fevered throat: `flesh` under the split jaw with
  `flesh.d` flushes up both sides of the head and a `flesh` base where the neck meets the
  collar; the rolled eyes are one `pus.l` band in a `wound` rim; the jacket is soaked `pus.d`
  down the front (drips and cuffs too); a ring of six pustules round the collar where the sac
  sits; the open throat keeps `strain.d` (the only green left on the body besides the sac).
  Arms tapered with caps; legs are the Walker's. 1,424 tris.
- **Accuracy pass (2026-11-08, lore developer), staying blocky.**
  - The head is barely tilted: throw it back about 20 degrees on the mesh.
  - The chest needs a visible concave notch at the front.
  - Mount the sac in the preview: it is the widest thing on the body and does not show.
  - The surgical mask is lost under the pustule ring: make it a white band.
  - Bend the knees.

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

### The Warden (Delta; scale 1.9; v2 built 2026-11-07, 2,604 tris with the six plates)
- **Was:** the Delta MP sergeant who ran the Gate, the Gate NCOIC. Bitten through the
  shield sleeve on the last day of screening; chained the Gate from outside under the
  containment order, shutting the garrison and the highway's refugees in with himself.
  The strain grew his riot kit into him. The only Index that stands upright.
- **Silhouette (v2, owner-approved in Blender):** not a Brute in armour. Upright and tall;
  asymmetric: the left side one armoured mass (shield grown into the forearm, shoulder
  dome, raised riot collar), the right side the bare MP; the head sunk into the collar so
  helmet and shoulders read as one dome; long legs; duty belt with the canisters.
- **Head:** riot helmet fused to the skull, `dark.m` shell, `gun.l` visor cracked and set
  into the `rebuilt` brow; `strain.l` eyes in `dark.d` rims behind it.
- **Torso:** the Brute's bone shelf under `dark` riot plates (chest, shoulders, back); a
  `white.m` **MP brassard** with `dark.d` letters on the upper arm; a `dark` radio handset
  on its coiled cord grown into the chest plate.
- **Arms/hands:** `rebuilt` spurred forearms; the **riot shield** grown into the left
  forearm as an attached part (`dark.l`, a tall curved plate strapped along the outer
  forearm the way the Mixamo shield clips carry one: a door from eye level to shin when he
  guards, at his side on the walk; `gun.l` window).
- **Legs/feet:** `dark.d` shin guards, `olive.m` trousers, `dark.d` boots.
- **Mechanic:** six plates (helmet shell, chest, back, both shoulders, shield) are attached
  parts with their own health; each one off reveals `rebuilt` bone and a `strain.l` seam
  (built as the limb geometry under the plate). Gas canisters on the right hip feed the
  phase-2 lob. Built in `assets/3d/build/warden.py` as `inf_warden_*` with sided upper
  arm / lower arm / hand (`_l` shield grip and seam, `_r` brassard) and
  `inf_warden_plate_*` (helmet, chest, back, shoulder `_l` / `_r`, shield); numbers in
  `docs/PROGRESSION.md` > *Index kit: the Warden*. Clips: `warden_*` in
  `assets/animations/README.md`.

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

## C. Pike

Canon as of 2026-11-08 (owner: "just soldiers, like Helldivers"). One body for every player
and bot: the Weller build with Weller's face. Ballistic helmet with NVG mount, grey
fatigues, black Pike carrier (PIKE tab, three mag pouches, radio, one tourniquet), dark
gloves, knee pads and boots. The only per-player detail is the seat square (One
`friendly blue`, Two `tan.l`, Three `white.l`, Four `warning orange`) on the left shoulder
and the back panel. The support weapon from a call-in is carried on the back, where the
squad can see it. Bots are Pike Two, Three and Four by seat. Added 2026-11-10 (same on
every body): the Carrier's screening band on the left wrist (white paper, one yellow stripe;
the Walker's Delta band is white with red: the soldiers wear what the corridor wore) and a
chemlight taped to the left shoulder strap. Ship and desk crew bodies:
[lore/desk_crew.md](lore/desk_crew.md) > Bodies. Retired sheets (Weller, Cole,
Kilo, Reyes, Cross, Kane) are in [lore/retired_chosen.md](lore/retired_chosen.md).
