# assets/3d — Roblox asset ids

Uploaded 2026-11-06 via Open Cloud (`upload_asset`, assetType Model for FBX, Decal for the
palette). Mesh ids were read in Studio with `InsertService:LoadAsset(<modelAssetId>)` and are
wired into `src/shared/MeshAssets.luau` (server-built MeshPart templates). Old env v1 model
uploads (126781711029053, 110183901153071, 111918726514098) are superseded.

Palette texture (v3, 2026-11-07, adds the `rebuilt`/`strain`/`foliage_d`/`rust_l`/`rust_d`
swatches): decal `120331040807954` → image **`110782102234723`** (the `TextureID`). v2 was
`88256641133314`, v1 `87519201884536`.

| Mesh | MeshId | Model asset (upload) | In-game Size (studs) | Placement note |
|---|---|---|---|---|
| pick_xp_orb | 95196197176639 | 134499655967097 | 1.0 x 1.0 x 1.0 | uniform; service sets Size per orb value |
| prop_ammo_crate | 70908704628683 | 111854712064143 | 2.86 x 1.68 x 1.92 | pivot bottom: place at ground + 0.84 |
| prop_repulsor_mine | 122106813224951 | 102515645095030 | 1.9 x 0.97 x 2.0 | pivot bottom: place at ground + 0.485 |
| prop_drone | 132929388031760 | 93513427419630 | 1.94 x 0.43 x 1.94 | 0.8x of the Blender size (2.43 read too big in-hand scale) |
| prop_drone_beacon | 117405323536844 | 71937735064271 | 1.56 x 3.21 x 1.36 | pivot bottom: place at ground + 1.60; not used by a service yet |
| wpn_rifle | 86613539481097 | 77112302177721 | 0.195 x 0.84 x 2.9 | 0.65x of the Blender size; grip offset handled in PlayerSetup |
| prop_plague_rat | 102065990394982 | 135041557109073 | 0.47 x 0.52 x 1.88 | 0.7x of Blender; PlagueRatService PrimaryPart, faces -Z |
| env_barrier_jersey | 83842095201437 | 120043526542183 | 6 x 2.75 x 2 | solid; ArenaService dressing |
| env_sandbag_bunker (v2) | 72798329648015 | 104090605242659 | 12.8 x 6.3 x 10.8 | solid; rebuilt 2026-11-06 to character scale |
| env_guard_tower (v2) | 140295675948906 | 86672166489335 | 11 x 27.25 x 11 | solid; rebuilt 2026-11-06 |
| env_ruin_building (v2) | 112569589520919 | 75991267203586 | 32.73 x 24.6 x 25.35 | solid; rebuilt 2026-11-06 (10.5-stud storeys) |
| env_container_olive | 90739805417437 | 132200158345619 | 22.1 x 9.55 x 9.2 | solid |
| env_container_rust | 108583453603951 | 134169217220802 | 22.1 x 9.55 x 9.2 | solid |
| env_wreck_humvee | 101500567016827 | 78504635684807 | 17 x 7.11 x 8.1 | solid; nose toward -X |
| env_twall | 123453107626792 | 95876600065674 | 8 x 12.5 x 2.6 | solid |
| env_hesco | 76249676881241 | 85372982024960 | 6.22 x 4.58 x 4.72 | solid |
| env_comm_tower | 121850127656343 | 136043833521905 | 8.04 x 44.7 x 8 | solid; landmark |
| env_tent | 81822440803835 | 138062558436837 | 19.2 x 8.6 x 12 | solid; door on -X |
| env_checkpoint | 71573561117915 | 129215637928455 | 22.05 x 9.5 x 7.4 | PreciseConvexDecomposition; booth at -X, boom along +X |
| env_dead_tree | 103119294791056 | 130464254006022 | 4.97 x 13.98 x 7.09 | Hull |
| env_lamp_post | 132474171948585 | 84369687950095 | 4.9 x 13 x 1.2 | Hull; arm along +X |
| inf_walker_head | 89158175147461 | 130652970591168 | 1.21, 1.22, 1.31 | R15 limb (v2 2026-11-07), offset -0.005, 0.020, -0.035 |
| inf_walker_upper_torso | 128339684458111 | 96331127663285 | 2.00, 1.75, 1.20 | R15 limb (v2 2026-11-07), offset 0.000, 0.025, 0.000 |
| inf_walker_lower_torso | 115889571442634 | 122831631690254 | 2.05, 0.43, 1.37 | R15 limb (v2 2026-11-07), offset 0.000, 0.005, -0.045 |
| inf_walker_upper_arm | 120794439621284 | 121265289798260 | 1.04, 1.24, 1.04 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_walker_lower_arm | 106412532252762 | 101532175778754 | 0.98, 1.12, 0.98 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_walker_hand | 82054942299820 | 104717175543319 | 0.98, 0.40, 1.03 | R15 limb (v2 2026-11-07), offset 0.000, -0.040, -0.002 |
| inf_walker_upper_leg | 119669238480601 | 90384933236146 | 1.00, 1.48, 1.26 | R15 limb (v2 2026-11-07), offset 0.000, -0.060, -0.048 |
| inf_walker_lower_leg | 102042184592850 | 94403639097046 | 0.99, 1.30, 0.97 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_walker_foot | 79144855233866 | 130560415633858 | 1.01, 0.31, 1.00 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_runner_head | 117624060503646 | 95727434560417 | 1.16, 1.18, 1.26 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, -0.050 |
| inf_runner_upper_torso | 107263794622603 | 111382194663325 | 1.94, 1.81, 1.23 | R15 limb (v2 2026-11-07), offset 0.000, 0.055, -0.005 |
| inf_runner_lower_torso | 88359244284243 | 106695059140827 | 2.01, 0.40, 1.09 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, -0.035 |
| inf_runner_upper_arm | 136771154014251 | 94740774310322 | 1.04, 1.25, 1.04 | R15 limb (v2 2026-11-07), offset 0.000, -0.025, 0.000 |
| inf_runner_lower_arm | 73890653650999 | 115226299588447 | 0.94, 1.42, 0.94 | R15 limb (v2 2026-11-07), offset 0.000, 0.110, 0.000 |
| inf_runner_hand | 112441012464559 | 79365237811651 | 0.98, 0.34, 1.18 | R15 limb (v2 2026-11-07), offset 0.000, 0.010, -0.080 |
| inf_runner_upper_leg | 125662424919143 | 77667022611447 | 1.01, 1.40, 1.11 | R15 limb (v2 2026-11-07), offset 0.000, -0.020, -0.071 |
| inf_runner_lower_leg | 129895373185483 | 111965815305442 | 1.01, 1.28, 0.99 | R15 limb (v2 2026-11-07), offset 0.000, -0.010, 0.000 |
| inf_runner_foot | 101646860898946 | 139809077230027 | 1.01, 0.32, 1.15 | R15 limb (v2 2026-11-07), offset 0.000, 0.008, 0.075 |
| inf_brute_head | 73597512666594 | 138968620774740 | 1.24, 1.24, 1.30 | R15 limb (v2 2026-11-07), offset 0.000, 0.030, -0.030 |
| inf_brute_upper_torso | 89721973590609 | 112449043882123 | 2.10, 1.95, 1.45 | R15 limb (v2 2026-11-07), offset 0.000, 0.125, 0.045 |
| inf_brute_lower_torso | 123309828753718 | 83908206117109 | 2.01, 0.40, 1.09 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, -0.035 |
| inf_brute_upper_arm | 134350483574031 | 105001913242516 | 0.98, 1.24, 0.98 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_brute_lower_arm | 126689486489276 | 75756136778480 | 1.19, 1.12, 1.00 | R15 limb (v2 2026-11-07), offset 0.094, 0.000, 0.000 |
| inf_brute_hand | 139690589575020 | 114010551344148 | 0.98, 0.41, 1.05 | R15 limb (v2 2026-11-07), offset 0.000, -0.005, -0.035 |
| inf_brute_upper_leg | 136635886287618 | 129070738691797 | 1.01, 1.49, 1.14 | R15 limb (v2 2026-11-07), offset 0.000, -0.065, -0.073 |
| inf_brute_lower_leg | 103129814688361 | 112060620309967 | 0.99, 1.30, 1.03 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, -0.028 |
| inf_brute_foot | 129900549102552 | 86637950340205 | 1.01, 0.37, 1.07 | R15 limb (v2 2026-11-07), offset 0.000, 0.027, -0.035 |
| inf_hocker_head | 95865084839192 | 135677500790235 | 1.33, 1.58, 1.68 | R15 limb (v2 2026-11-07), offset 0.000, 0.002, -0.040 |
| inf_hocker_upper_torso | 97667163763245 | 105034044672711 | 2.00, 1.71, 1.16 | R15 limb (v2 2026-11-07), offset 0.000, 0.007, 0.020 |
| inf_hocker_lower_torso | 115889571442634 | 126844940436737 | 2.05, 0.43, 1.37 | R15 limb (v2 2026-11-07), offset 0.000, 0.005, -0.045 |
| inf_hocker_upper_arm | 120857161769092 | 129579733561569 | 1.00, 1.24, 1.00 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_hocker_lower_arm | 136581492405467 | 116452554435798 | 0.96, 1.12, 0.96 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_hocker_hand | 107899889726305 | 119976682392082 | 0.98, 0.52, 1.15 | R15 limb (v2 2026-11-07), offset 0.000, -0.090, -0.067 |
| inf_hocker_upper_leg | 119669238480601 | 88472952067354 | 1.00, 1.48, 1.26 | R15 limb (v2 2026-11-07), offset 0.000, -0.060, -0.048 |
| inf_hocker_lower_leg | 102042184592850 | 129028388580658 | 0.99, 1.30, 0.97 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_hocker_foot | 79144855233866 | 139880549411227 | 1.01, 0.31, 1.00 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| pc_assault_head | 113120416771558 | 108816968954550 | 1.34, 1.24, 1.54 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.030, -0.060 |
| pc_assault_upper_torso | 109606627346841 | 101027325915224 | 1.94, 1.70, 1.51 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.000, -0.025 |
| pc_assault_lower_torso | 130324769107274 | 103310952242998 | 2.01, 0.40, 1.12 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.000, -0.050 |
| pc_assault_upper_arm | 70752581527557 | 130102142650442 | 1.04, 1.24, 1.10 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.000, -0.030 |
| pc_assault_lower_arm | 111242427197801 | 89733526738016 | 1.04, 1.12, 1.04 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| pc_assault_hand | 133846130665573 | 93761417336976 | 0.98, 0.33, 1.03 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.000, -0.002 |
| pc_assault_upper_leg | 123449912579061 | 103599487897185 | 1.08, 1.36, 1.09 | R15 limb (Weller v2 2026-11-07), offset 0.043, 0.000, -0.058 |
| pc_assault_lower_leg | 87884254546571 | 116185213877232 | 1.01, 1.30, 0.99 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| pc_assault_foot | 79144855233866 | 112575972731289 | 1.01, 0.31, 1.00 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| env_bus | 115848012015557 | 84471628520896 | 42.9 x 12.75 x 10.9 | solid; the Gate bus line (ArenaService), Mile 14 later; 2026-11-07 |

Open Cloud imports the FBX at 100x (1 Blender unit → 100 studs) and clamps any axis to 2048,
so the imported size is meaningless; `MeshAssets.luau` sets the intended stud size (Blender
dimensions X, Z, Y) and the MeshPart scales the mesh to it.
