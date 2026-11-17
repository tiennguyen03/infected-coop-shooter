# Spit puddle (Tien + Claude, 2026-11-17)

**Changed:** the Hocker's (and the Warden's gas) spit pool is no longer a perfect disc: it is
a puddle of low wet domes (a core and six lobes, a new uneven layout each time from
`Rules/PuddleShape`, spec first), each over a dark red rim, with a lighter glint. It spreads
out over 0.3 s with the lobes running a little behind, bubbles, gives off faint fumes, and
shrinks 30% as it fades (`SpitShape.pool` gained `shrink`). A floor hit also throws low
droplets skimming out. Client only: `src/client/SpitFX.luau`, `Config.Enemies.SpitFX.Pool`.
The server's damage area is untouched; every blob stays inside 1.04x the damage radius and
the puddle covers at least 3/4 of it in every direction (tested over 200 layouts).
**Verified:** stylua, selene, both rojo builds, 499 Lune tests, luau-lsp. Not seen in game:
the owner was playtesting, so no Studio run.
**Heads-up:** a pool is now 14 parts (was 2), 8 pools at most; SpitFX has 12 emitters (fumes
added). The floor spatters round the pool are smaller (0.22x radius).
**Next:** look in game (dev menu, spawn 1 Hocker): dome height (`Pool.Depth`), whether the
rim shows on dark ground, how faint the fumes are, and whether the edge dips (down to about
0.77x the radius) read as "safe" where they still hurt; tune `Pool.Shape` if so.
