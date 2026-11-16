# First-person views, per gun (Tien + Claude, 2026-11-11)

**Changed:** in first person every gun now aims through its own sights. Each gun row carries
`Sight` (`Config.Weapons.<id>.Sight`: the mesh's rear and front sight points from `guns.py`,
plus kind, eye relief, zoom and hip hold, defaults in `Config.Weapon.Sights`);
`Rules/Sight` turns that into the eye position, the aimed FOV and the scope's phases;
`FirstPersonView` places the gun from it (hip by the grip, not the mesh centre);
`CameraController` zooms per gun and lowers the sights during a reload or swap; `ScopeView`
draws the scope picture for the M2010 (6x), M110 (3.5x) and Goose (3x). The `sight` point and
the Tool's Sight part are gone from `MeshAssets` / `PlayerSetup`. Dev: F10 or the panel's
"Sight tour" row puts every gun in hand in first person, hip then sights (`SightTour`).
**Verified:** maths only: `tests/Sight.spec.luau` (13 tests, every gun row checked against its
mesh), 148 tests, lint, both builds and types clean. **Nothing was seen in game**: the owner
was playtesting in the same Studio, and Blender was in use.
**Heads-up:** to check in game with the sight tour: (1) the scope picture: the ring of black
strips round the lens has no gaps or seams, the blink is not a flicker, 6x / 3.5x / 3x feel
right; (2) M16, MP5, M249: the post centred in the peep, the rear sight not clipped by the
camera (on a device with a deep near plane the gun is drawn larger: walls may cut into it);
(3) Mossberg: the receiver top does not fill the lower screen; (4) M17 and revolver at arm's
length, and the new hip holds (sidearm, Goose on the shoulder); (5) the Q-swap dip. The
revolver's hammer spur stands 0.013 above its rear notch on the mesh, so it is sighted over
the spur: rebuild `wpn_revolver` with a lower hammer, then set its `Sight.Rear` to the notch
(0, 0.45, -0.02). The peeps are modelled at true size (0.022-0.026 studs): if they read too
small, widen them in `guns.py`, not the eye relief. Third person still uses the shared ADS
view, also for the sniper. PR #20 rewrites `DevTestPanel`: the tour's row there is one line,
F10 works without it.
**Next:** the owner's look in game, then tune `Zoom` / `EyeRelief` per row; the revolver mesh.
