# Retired: the Chosen (archive)

**Not canon.** Retired 2026-11-08 by the owner ("we scrap the whole character idea... just
soldiers, like Helldivers"). The players are now Pike One to Four ([LORE.md](../LORE.md) >
Pike; body sheet in [CHARACTERS.md](../CHARACTERS.md) section C). The sheets below are kept
verbatim from CHARACTERS.md section C as of 2026-11-08 so the art is not lost. The Pike
body is built from Weller's sheet.

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

**Body build (art v2 decision B, 2026-11-07).** The Chosen are the bodies the camera sits
behind all run, so they get the hybrid treatment: **Weller is built as one skinned mesh**
on an R15 armature (`pc_assault_skinned`, 944 tris; every joint is a vertex loop skinned
50/50 to the two bones it joins, forearms and shins taper to 75%, elbow and knee pads
straddle the joints), with the helmet and the Pike carrier as separate rigid accessories
so they, and the rifle, weld on as before. The Infected stay rigid per-limb. **Shipped
2026-11-07** (`Config.Player.SkinnedBody = true`): the skin rides a hidden 15-part R15
rig assembled at boot (`assets/3d/README.md` "Skinned Weller"), so joints, headshots and
the rifle weld work as on any R15 body. Hands are fists (0.82 x 0.33 x 0.88), not gloves
that out-size the helmet (art-director pass). The five rigid limb sets carry the
**fallback** and the bots: tapered octagonal forearms/shins and round joint caps at every
elbow and knee (`PC_TAPER` in the build script), inside the same R15 boxes. On the skinned
body the colour square sits on the left sleeve only; the rigid sets show it on both arms
because left and right share one mesh.

### Isaac Weller, Assault (`pc_assault`)

> **In game (2026-11-07):** the tapered rigid body (`PC_TAPER`). The skinned one-mesh body
> is built and uploaded but switched off: its bones and the hidden Motor6D rig diverge
> under the R15 clips (handoff/README.md open work).
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
