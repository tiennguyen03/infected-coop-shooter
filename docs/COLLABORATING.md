# Collaborating: sounds and animations for a second developer

Written 2026-11-09 for onboarding Nova. Checked against Roblox's creator docs that day:
[asset privacy](https://create.roblox.com/docs/projects/assets/privacy) and
[collaboration](https://create.roblox.com/docs/projects/collaboration). Roblox changes these
rules often; re-check the two pages if a step below no longer matches.

## The problem

The code is shared through git, but the game's **audio and animations are Roblox assets owned
by the owner's account** (the six sound banks, the rifle shot, 48 published animation clips; ids in
`SoundBanks`, `SoundFX` and `Config.Animations.Ids`). Roblox loads audio and animations only:

- in games **owned by the account that uploaded them**, or
- in games that were **granted access** to them by the owner.

A collaborator who syncs the repo into a place of their own (the README's "new Baseplate")
is in a game nobody granted access to, so every sound is silent and every clip is missing.
Meshes and images are Open Use by default, which is why the bodies and the map still load.

**No code change can make Roblox load an asset in a game that has no permission for it.** The
fix is where each developer's place lives. In Studio, `client/AssetAccessCheck` now preloads
every uploaded sound and animation a few seconds after boot and prints either
`[AssetAccess] all N uploaded sounds and animations load in this place` or a warning that
counts what failed and points here.

## Recommended: one experience, one place per developer (no group)

Everything the owner uploads loads in any place inside the owner's own experience, and anyone
with Edit access to that experience can work in it. Each developer gets their own place in
the same experience so two `rojo serve` sessions never write into the same place.

1. **Become Roblox friends** with the collaborator. A user-owned game can give Edit access
   only to friends.
2. **Owner: publish the game to Roblox** if it is not published yet (File > Publish to
   Roblox; keep it private). This is the experience everyone works in.
3. **Owner: add the collaborator.** With that place open in Studio, click **Collaborate**,
   search for the friend, choose **Edit**, then **Save**. Team Create collaboration needs an
   age check from both accounts.
4. **Owner: add a place for the collaborator** in the same experience (Studio **Asset
   Manager** > **Places**, right-click > **Add New Place**), named e.g. `Dev - Nova`.
5. **Collaborator: open that place** in Studio, then run `rojo serve default.project.json`
   and **Connect**, as in the README. If Studio's script collaborative editing (drafts) is on
   for the place, turn it off so Rojo's writes go live.
6. **Check:** press Play. The Output shows `[AssetAccess] all ... load in this place`.

New uploads by the owner work in every place of the experience with no extra step.

## Alternative: share each asset (also no group)

Use this if the collaborator must keep a place in an experience of their own.

1. Become Roblox friends.
2. Owner: for each audio and animation asset, Creator Dashboard > **Development Items** >
   **Audio** / **Animations** > the asset > **Permissions** > **Collaborators** > **Add
   collaborators** > the friend. The Asset Manager beta can bulk-share many assets at once.
3. Collaborator: publish their place, open it in Studio and Play. Each restricted asset
   prints a clickable error in Output; clicking it grants the collaborator's game access.
   A game's access to an asset is permanent once granted.

Every asset uploaded later has to be shared again, which is why the recommended setup is
the one above.

## What does not work

- **Making assets Open Use.** It is permanent and lets any game use them.
- **Copying the ids.** An id is only a reference; the permission check happens on load.
- **Re-uploading from the collaborator's account.** It forks every id in the code.
