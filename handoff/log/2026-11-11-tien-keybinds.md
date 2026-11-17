# Keyboard layout (Tien's agent, 2026-11-11)

**Changed:** the owner's new keys: E interact (hold to revive; the lobby desks too), V stim,
F shove, C or LeftControl crouch, Z prone, X Resupply flare; the rest unchanged (table:
`docs/OWNER.md` > Rules already decided). Every key is now a row of `Config.Keys` and every
hint (ability circles, `[X] FLARE`, `[Q]`, `DRY [R]`, the Arms Room hints, the frag's
description) is made from the key with `Rules/KeyBindings.label`. `Config.Camera.FirstPerson.Key`
moved to `Config.Keys.Camera`.
**Verified:** stylua, selene, both rojo builds, luau-lsp (match and lobby), 139 Lune tests.
Not played: no playtest was run (the owner was in Studio).
**Heads-up:** `tests/KeyBindings.spec.luau` fails when two actions share a key (the meant
overlaps, Crouch with Roll and Slide while sprinting, are listed there);
`tests/SourceReferences.spec.luau` fails on an `Enum.KeyCode.<key>` in `src/client` or
`src/server` other than F-keys, gamepad buttons and text-box keys, and on `MouseButton3`
(kept free for a ping). The open branches got a "Keys: ..." commit each with the new keys
set in their own rows; when they merge after this, point those rows at `Config.Keys`
(each has a `-- becomes Config.Keys.<X>` comment). PR #38 (roll/slide) will conflict in
`StanceController` and `MovementController`: keep its roll/slide, this branch's key reads,
and drop `Keys.Roll` / `Keys.Slide` plus their pairs in the spec's `SHARED` list as needed.
**Next:** play it; the ping on middle mouse.
