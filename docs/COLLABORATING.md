# Collaborating: sounds and animations for a second developer

Written 2026-11-09 for onboarding Nova. Checked against Roblox's creator docs that day:
[asset privacy](https://create.roblox.com/docs/projects/assets/privacy),
[groups](https://create.roblox.com/docs/projects/groups) and
[collaboration](https://create.roblox.com/docs/projects/collaboration). Roblox changes these
rules often; re-check those pages if a step below no longer matches.

## The problem

The code is shared through git, but the game's **audio and animations are Roblox assets owned
by the owner's personal account** (the six sound banks, the rifle shot, 48 published animation
clips; ids in `SoundBanks`, `SoundFX` and `Config.Animations.Ids`). Roblox loads audio and
animations only:

- in games **owned by whoever owns the asset**, or
- in games that were **granted access** to the asset.

A collaborator who syncs the repo into a place of their own (the README's "new Baseplate")
is in a game nobody granted access to, so every sound is silent and every clip is missing.
Meshes and images are Open Use by default, which is why the bodies and the map still load.

**No code change can make Roblox load an asset in a game that has no permission for it.** The
fix is who owns the game and the assets. In Studio, `client/AssetAccessCheck` preloads every
uploaded sound and animation a few seconds after boot and prints either
`[AssetAccess] all N uploaded sounds and animations load in this place` or a warning that
counts what failed and points here.

## Recommended: the group owns the game (the owner has a group)

Members of a group whose role has **Edit group games** can edit every game the group owns and
use every asset the group owns. The existing assets belong to the owner's personal account,
so they are shared with the group once; new uploads go to the group directly.

1. **Roles.** Group (Creator Dashboard, account switcher > the group > **Roles**): give the
   collaborator's role **Edit group games** (and **Create and edit group assets** if they
   will upload). Invite the collaborator and assign that role.
2. **Publish the game into the group.** In Studio, File > **Publish to Roblox As** > a new
   game with the **group** as creator (keep it private). This is the experience everyone
   works in. Give each developer their own place in it (Studio **Asset Manager** >
   **Places**, right-click > **Add New Place**, e.g. `Dev - Nova`) so two `rojo serve`
   sessions never write into the same place.
3. **Share the existing assets with the group.** For each sound and animation: Creator
   Dashboard > **Development Items** > **Audio** / **Animations** > the asset >
   **Permissions** > **Collaborators** > **Add collaborators** > the group. Sharing with a
   group needs the owner to have **Edit group games** in it (the group owner does). The
   **Asset Manager** beta can bulk-share all of them at once. The ids do not change, so no
   code changes.
4. **Grant the group game access, once.** Open the group game in Studio and press Play. If
   Output lists restricted-asset errors, click them: that grants this game the asset, and a
   game's access is permanent and covers every place in the game.
5. **Collaborator:** open their place in the group game, run `rojo serve
   default.project.json` and **Connect**, as in the README. If Studio's script collaborative
   editing (drafts) is on for the place, turn it off so Rojo's writes go live. Team Create
   collaboration needs an age check from each account.
6. **Check:** press Play. Output shows `[AssetAccess] all ... load in this place` for both.

**From now on, upload sounds and animations as the group** (Creator Hub's creator picker, or
an Open Cloud call with `creator.groupId` and a group API key), so every group game can use
them with no sharing step. Images and meshes are Open Use and need nothing.

## Without a group: one experience owned by the owner

Everything the owner uploads loads in any place inside the owner's own experience.

1. Become Roblox friends (a user-owned game gives Edit access only to friends).
2. Owner: publish the game (private), then in Studio **Collaborate** > the friend > **Edit**
   > **Save**.
3. Owner: add a place for the collaborator in that experience (Asset Manager > Places).
4. Collaborator: open it, `rojo serve`, Connect, Play, check the `[AssetAccess]` line.

## Per-asset sharing to the collaborator's own game

1. Become Roblox friends.
2. Owner: share each asset with the friend (asset > Permissions > Collaborators).
3. Collaborator: publish their place, Play, click each restricted-asset error in Output.

Every asset uploaded later has to be shared again.

## What does not work

- **Making assets Open Use.** It is permanent and lets any game use them.
- **Copying the ids.** An id is only a reference; the permission check happens on load.
- **Re-uploading from another account.** It forks every id in the code.
