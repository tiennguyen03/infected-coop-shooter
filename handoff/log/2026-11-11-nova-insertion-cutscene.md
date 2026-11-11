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

**Second look (Nova):** "for about a second ... you can see the squad standing on the pad", and "see the squad sitting in the heli and then see them jumping out". A black cover is up from the client's first frame while the run is in Lobby or Insert (StagingUI drawn over it). The squad rides as local stand-ins (clones of each body, scripts stripped, root anchored) seated on a bench along the cabin's far wall facing the door (Roblox's stock R15 sit); in the hover each in turn steps to the door and falls in an arc (stock fall) onto the spot its real body stands on, which then shows. The blink cut is gone; the drop is seen from the door side. Cutscene 14.5 s (Drop 2.8). Seats, bench, door, timings in `Config.Insertion`.

**Third look (Nova):** feet through the cabin floor, and the AI team not aboard. Seats measured: the stock sit puts the feet 2.32 under the root (R15 rig, Edit mode); the floor is 2.45 over the frame origin (the lobby crew chief's), so seated roots at 4.77, bench top 3.27, DeckY 2.45. The bots are dressed after the cutscene starts: anyone who appears is now seated each frame until their jump is near.

**Fourth look:** the AI team never showed (bot bodies are built seconds into the cutscene, and a bot's stand-in, cloned with its SquadBot tag, was then hidden as a squad body every frame), then Nova did not see himself (seats went by roster name, b: before p:, so he sat at Z -4.4 behind the wall aft of the door). Now: one seat per SquadRoster entry from the start (a bot with no body yet rides as a copy of this soldier, lands on a free pad and waits for its body), players seated first, seats moved into the door opening (Z 4.2 to -1.8), the stand-ins lose their tags and the ally outline, and the server prefetches the uniform's item kinds (`AvatarLook.prefetch`). Checked in a playtest: all four stand-ins aboard and visible at the hover (screenshot), before the seat move.
