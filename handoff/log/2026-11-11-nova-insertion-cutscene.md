# Insertion cutscene (Nova, 2026-11-11)

**Changed:** on `nova/insertion-cutscene` (from `nova/carrier-update`). The squad's arrival is a
cutscene (owner rule updated in docs/OWNER.md). `InsertionService` (server) assembles the Lantern
from the four mesh templates into `ReplicatedStorage.InsertLantern` at boot; `InsertionCutscene`
(client) clones it when RunState turns Insert and flies it locally: approach from the map's edge
(6 s), flare to a hover over the LZ pad (2.5 s), the drop in rotor dust (1.6 s; the squad's bodies
appear at its middle, on a blink), the climb away over their heads (3.2 s). Three camera shots,
letterbox, HUD hidden, controls held, `Attributes.Cinematic` blocks firing, reloads and kit; the
rotor loop is the existing `lantern_rotor` sound. Space / A skips (`Config.Insertion.SkipKeys`).
CameraController gained `setCinematic`. RunManager: Insert lasts `Insertion.Seconds` +
`Run.InsertSeconds`; `ObjectiveService.brief` runs when the cutscene ends.
**Verified:** stylua, selene, both builds, 396 tests, types for both places. Not played.
**Heads-up:** Tien's areas touched: RunManager (Insert timing, brief), CameraController,
WeaponController and AbilityController (the Cinematic check).
**Next:** Nova playtests and tunes the shots and timings in `Config.Insertion`; a door-side jump
by the squad could replace the blink later.

**First look (Nova):** no cutscene at first: in Studio the run turns Insert before the client is up, and the client found no InsertLantern yet. Now the server stamps `Attributes.InsertStartsAt` (Insert + `Insertion.LeadSeconds` 2.5, written before the state) and clients wait for the model and that time (black meanwhile), joining late if they must. Then: the first shot was behind the LZ cutting's wall, and the helicopter flew tail first (its nose is +Z). Every camera now stands over the pad; the frame looks along -facing and the pitch is flipped.
