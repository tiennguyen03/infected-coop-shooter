# assets/3d — Roblox asset ids

Uploaded 2026-11-06 via Open Cloud (`upload_asset`, assetType Model for FBX, Decal for the
palette). Mesh ids were read in Studio with `InsertService:LoadAsset(<modelAssetId>)` and are
wired into `src/shared/MeshAssets.luau` (server-built MeshPart templates). Old env v1 model
uploads (126781711029053, 110183901153071, 111918726514098) are superseded.

Palette texture: decal `77421611874143` → image **`87519201884536`** (the `TextureID`).

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
| pc_assault_head | 95005339350582 | 109799809484018 | 1.34, 1.25, 1.48 | R15 limb, offset 0.000, 0.035, -0.090 |
| pc_assault_upper_torso | 86706465408743 | 117944474269990 | 1.94, 1.70, 1.44 | R15 limb, offset 0.000, 0.000, -0.060 |
| pc_assault_lower_torso | 138634306069937 | 78418535413019 | 2.01, 0.40, 1.12 | R15 limb, offset 0.000, 0.000, -0.050 |
| pc_assault_upper_arm | 76463628405742 | 129827125546347 | 1.04, 1.24, 1.09 | R15 limb, offset 0.000, 0.000, -0.025 |
| pc_assault_lower_arm | 111242427197801 | 94086121640082 | 1.04, 1.12, 1.04 | R15 limb |
| pc_assault_hand | 133846130665573 | 100198436557637 | 0.98, 0.33, 1.03 | R15 limb, offset 0.000, 0.000, -0.002 |
| pc_assault_upper_leg | 99577988454218 | 83831662733103 | 1.08, 1.36, 1.09 | R15 limb, offset 0.043, 0.000, -0.058 |
| pc_assault_lower_leg | 87884254546571 | 140543316185534 | 1.01, 1.30, 0.99 | R15 limb |
| pc_assault_foot | 79144855233866 | 126410611292083 | 1.01, 0.31, 1.00 | R15 limb (same mesh as inf_walker_foot) |
| inf_walker_head | 125036021688938 | 109685456333011 | 1.300, 1.220, 1.510 | R15 limb, offset 0.000, 0.020, -0.115 |
| inf_walker_upper_torso | 73526825074456 | 78180467775035 | 2.000, 1.700, 1.190 | R15 limb, offset 0.030, 0.000, -0.095 |
| inf_walker_lower_torso | 90864407049648 | 113855995604506 | 1.990, 0.400, 1.080 | R15 limb, offset 0.000, 0.000, -0.040 |
| inf_walker_upper_arm | 130641385322566 | 73006443638264 | 1.000, 1.240, 1.000 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_walker_lower_arm | 106641376979082 | 100694177543106 | 1.000, 1.120, 1.000 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_walker_hand | 101524032490960 | 76718662226412 | 0.980, 0.330, 1.035 | R15 limb, offset 0.000, 0.000, -0.002 |
| inf_walker_upper_leg | 97365267283514 | 78344420150205 | 0.990, 1.360, 1.085 | R15 limb, offset 0.000, 0.000, -0.058 |
| inf_walker_lower_leg | 97366869131440 | 120441409706166 | 0.990, 1.300, 0.970 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_walker_foot | 79144855233866 | 131302364413019 | 1.010, 0.310, 1.000 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_runner_head | 85607611852070 | 118700028583668 | 1.200, 1.220, 1.260 | R15 limb, offset 0.000, 0.020, -0.030 |
| inf_runner_upper_torso | 116304103046435 | 132329715642560 | 2.000, 1.700, 1.190 | R15 limb, offset 0.030, 0.000, -0.095 |
| inf_runner_lower_torso | 94511863005066 | 104614099358095 | 1.990, 0.400, 1.080 | R15 limb, offset 0.000, 0.000, -0.040 |
| inf_runner_upper_arm | 119560986493213 | 117335289187495 | 1.000, 1.240, 1.000 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_runner_lower_arm | 109736917953704 | 100075989644327 | 1.000, 1.120, 1.000 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_runner_hand | 84025375138002 | 125550171019580 | 0.980, 0.330, 1.035 | R15 limb, offset 0.000, 0.000, -0.002 |
| inf_runner_upper_leg | 93056587028938 | 103675269444114 | 0.990, 1.360, 1.085 | R15 limb, offset 0.000, 0.000, -0.058 |
| inf_runner_lower_leg | 132251690624078 | 104343540661739 | 0.990, 1.300, 0.970 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_runner_foot | 79144855233866 | 86916526090840 | 1.010, 0.310, 1.000 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_brute_head | 140393473012009 | 101543426413746 | 1.300, 1.240, 1.360 | R15 limb, offset 0.000, 0.030, -0.030 |
| inf_brute_upper_torso | 105779397180273 | 83929351055894 | 2.000, 1.700, 1.440 | R15 limb, offset 0.030, 0.000, 0.030 |
| inf_brute_lower_torso | 88192737666842 | 129266791021034 | 1.990, 0.400, 1.080 | R15 limb, offset 0.000, 0.000, -0.040 |
| inf_brute_upper_arm | 73003273286253 | 92252221322997 | 1.160, 1.240, 1.160 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_brute_lower_arm | 121529679833263 | 81901269762410 | 1.000, 1.120, 1.000 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_brute_hand | 80232071254581 | 136748566496919 | 0.980, 0.330, 1.035 | R15 limb, offset 0.000, 0.000, -0.002 |
| inf_brute_upper_leg | 140452804420046 | 114052891152507 | 0.990, 1.360, 1.085 | R15 limb, offset 0.000, 0.000, -0.058 |
| inf_brute_lower_leg | 101498519950030 | 75867742447788 | 0.990, 1.300, 0.970 | R15 limb, offset 0.000, 0.000, 0.000 |
| inf_brute_foot | 110603242759494 | 87394103471009 | 1.010, 0.310, 1.000 | R15 limb, offset 0.000, 0.000, 0.000 |

Open Cloud imports the FBX at 100x (1 Blender unit → 100 studs) and clamps any axis to 2048,
so the imported size is meaningless; `MeshAssets.luau` sets the intended stud size (Blender
dimensions X, Z, Y) and the MeshPart scales the mesh to it.
