# assets/3d — Roblox asset ids

Uploaded 2026-11-06 via Open Cloud (`upload_asset`, assetType Model for FBX, Decal for the
palette). Mesh ids were read in Studio with `InsertService:LoadAsset(<modelAssetId>)` and are
wired into `src/shared/MeshAssets.luau` (server-built MeshPart templates). Old env v1 model
uploads (126781711029053, 110183901153071, 111918726514098) are superseded.

Palette texture (v4, 2026-11-07, skin v2: cells 25-27 and 43-56 become the `pallor` /
`flesh` / `bruise` / `wound` / `pus` rows plus `concrete_l/_d`): decal `80401218749683` → image
**`115366221483568`** (the `TextureID`). v3 was `120331040807954` → `110782102234723`, v2
`88256641133314`, v1 `87519201884536`.

Delta rework meshes (ruin v2, guard tower v3, tall hesco, crib stack, deck plate, 12 props)
uploaded 2026-11-07 and wired; rows below.

| Mesh | MeshId | Model asset (upload) | In-game Size (studs) | Placement note |
|---|---|---|---|---|
| pick_xp_orb | 95196197176639 | 134499655967097 | 1.0 x 1.0 x 1.0 | uniform; service sets Size per orb value |
| prop_ammo_crate | 70908704628683 | 111854712064143 | 2.86 x 1.68 x 1.92 | pivot bottom: place at ground + 0.84 |
| prop_repulsor_mine | 122106813224951 | 102515645095030 | 1.9 x 0.97 x 2.0 | pivot bottom: place at ground + 0.485 |
| prop_drone | 132929388031760 | 93513427419630 | 1.94 x 0.43 x 1.94 | 0.8x of the Blender size (2.43 read too big in-hand scale) |
| prop_drone_beacon | 117405323536844 | 71937735064271 | 1.56 x 3.21 x 1.36 | pivot bottom: place at ground + 1.60; not used by a service yet |
| wpn_rifle | 86613539481097 | 77112302177721 | 0.195 x 0.84 x 2.9 | 0.65x of the Blender size; grip offset handled in PlayerSetup |
| prop_plague_rat | 102065990394982 | 135041557109073 | 0.47 x 0.52 x 1.88 | 0.7x of Blender; faces -Z; unused since Sprint 18 (PlagueRatService deleted) |
| env_barrier_jersey | 83842095201437 | 120043526542183 | 6 x 2.75 x 2 | solid; ArenaService dressing |
| env_sandbag_bunker (v2) | 72798329648015 | 104090605242659 | 12.8 x 6.3 x 10.8 | solid; rebuilt 2026-11-06 to character scale |
| env_guard_tower (v2, superseded) | 140295675948906 | 86672166489335 | 11 x 27.25 x 11 | solid; rebuilt 2026-11-06 |
| env_ruin_building (2026-11-06, superseded) | 112569589520919 | 75991267203586 | 32.73 x 24.6 x 25.35 | solid; rebuilt 2026-11-06 (10.5-stud storeys) |
| env_container_olive | 90739805417437 | 132200158345619 | 22.1 x 9.55 x 9.2 | solid |
| env_container_rust | 108583453603951 | 134169217220802 | 22.1 x 9.55 x 9.2 | solid |
| env_wreck_humvee | 101500567016827 | 78504635684807 | 17 x 7.11 x 8.1 | solid; nose toward -X |
| env_twall | 123453107626792 | 95876600065674 | 8 x 12.5 x 2.6 | solid |
| env_hesco | 76249676881241 | 85372982024960 | 6.22 x 4.58 x 4.72 | solid |
| env_crib_stack | 84277153513044 | 97934930804371 | 1.20 x 2.80 x 2.60 | pivot bottom, offset (0.000, 1.400, 0.000); cribbing under a lifted T-wall (Scrapes) |
| env_deck_plate | 87378908913829 | 75563930153038 | 12.00 x 0.33 x 5.00 | pivot bottom, offset (0.000, 0.165, 0.000); walkable road plate between roofs |
| env_guard_tower | 115469907629978 | 71139384321705 | 11.00 x 27.25 x 11.00 | pivot bottom, offset (0.000, 13.625, 0.000); v3 rail gate; composite colliders + TrussPart ladder; replaces 140295675948906 |
| env_hesco_tall | 87652619532508 | 82867781130855 | 6.22 x 8.88 x 4.72 | pivot bottom, offset (0.000, 4.440, 0.000); two-high hesco (the Pens ring) |
| env_ruin_building | 97636619216682 | 81543978894479 | 32.09 x 23.60 x 25.15 | pivot bottom, offset (0.847, 11.800, -0.517); v2 enterable; composite colliders, `shell` for outer ruins; replaces 112569589520919 |
| prop_body_bag | 138563921819343 | 73076169933777 | 6.60 x 0.95 x 2.20 | pivot bottom, offset (0.100, 0.475, 0.000); prop (Delta rework 2026-11-07) |
| prop_chainlink_panel | 135724153731021 | 125979502358349 | 12.06 x 7.00 x 0.30 | pivot bottom, offset (0.000, 3.500, 0.000); prop (Delta rework 2026-11-07) |
| prop_civilian_car | 131007713996765 | 117334770094341 | 15.70 x 4.80 x 7.50 | pivot bottom, offset (0.000, 2.400, 0.000); prop (Delta rework 2026-11-07) |
| prop_concertina | 110184084591558 | 137827068150629 | 12.13 x 2.89 x 2.93 | pivot bottom, offset (0.000, 1.447, 0.000); prop (Delta rework 2026-11-07) |
| prop_cot | 111579390093659 | 137412438411439 | 6.50 x 2.10 x 2.95 | pivot bottom, offset (0.000, 1.048, 0.000); prop (Delta rework 2026-11-07) |
| prop_dumpster | 135179607691394 | 108883133700802 | 7.50 x 4.40 x 4.24 | pivot bottom, offset (0.000, 2.200, 0.000); prop (Delta rework 2026-11-07) |
| prop_fuel_bladder | 104420152748932 | 124744311184847 | 11.00 x 3.03 x 7.40 | pivot bottom, offset (0.000, 1.513, 0.000); prop (Delta rework 2026-11-07) |
| prop_generator | 102465817431781 | 126567041190669 | 8.00 x 5.20 x 4.50 | pivot bottom, offset (0.000, 2.600, 0.000); prop (Delta rework 2026-11-07) |
| prop_light_tower | 109327327787712 | 97029406002742 | 4.70 x 17.95 x 3.90 | pivot bottom, offset (0.350, 8.975, 0.000); prop (Delta rework 2026-11-07) |
| prop_pallet | 85849726914721 | 95269029743380 | 4.05 x 0.57 x 4.00 | pivot bottom, offset (0.000, 0.285, 0.000); prop (Delta rework 2026-11-07) |
| prop_plank | 85743587635839 | 81118116311720 | 10.00 x 0.40 x 2.00 | pivot bottom, offset (0.000, 0.200, 0.000); prop (Delta rework 2026-11-07) |
| prop_portable_toilet | 106338287683599 | 137067132484823 | 4.30 x 8.45 x 4.39 | pivot bottom, offset (0.000, 4.225, -0.045); prop (Delta rework 2026-11-07) |
| env_comm_tower | 121850127656343 | 136043833521905 | 8.04 x 44.7 x 8 | solid; landmark |
| env_tent | 81822440803835 | 138062558436837 | 19.2 x 8.6 x 12 | solid; door on -X |
| env_checkpoint | 71573561117915 | 129215637928455 | 22.05 x 9.5 x 7.4 | Box + composite colliders (2026-11-07); booth at -X, boom along +X |
| env_dead_tree | 103119294791056 | 130464254006022 | 4.97 x 13.98 x 7.09 | Hull |
| env_lamp_post | 132474171948585 | 84369687950095 | 4.9 x 13 x 1.2 | Hull; arm along +X |
| inf_walker_head | 100636262646383 | 110247687735003 | 1.22, 1.29, 1.31 | R15 limb (skin v2 2026-11-07), offset -0.000, -0.016, -0.035 |
| inf_walker_upper_torso | 119661347321934 | 87191220395464 | 2.00, 1.75, 1.20 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.025, 0.000 |
| inf_walker_lower_torso | 115889571442634 | 122831631690254 | 2.05, 0.43, 1.37 | R15 limb (v2 2026-11-07), offset 0.000, 0.005, -0.045 |
| inf_walker_upper_arm | 88373539845018 | 72026300702418 | 0.92, 1.24, 0.92 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_walker_lower_arm | 81627412669309 | 108502255788150 | 0.78, 1.12, 0.78 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_walker_hand | 119988488149184 | 107551213918410 | 0.98, 0.48, 1.03 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.002, -0.002 |
| inf_walker_upper_leg | 133917422037960 | 77578052851832 | 1.00, 1.40, 1.13 | R15 limb (skin v2 2026-11-07), offset 0.000, -0.020, 0.016 |
| inf_walker_lower_leg | 129665594524599 | 139491515162004 | 0.99, 1.30, 0.97 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_walker_foot | 79144855233866 | 130560415633858 | 1.01, 0.31, 1.00 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_runner_head | 137864155811153 | 121678587348122 | 1.22, 1.18, 1.26 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, -0.050 |
| inf_runner_upper_torso | 80475549545734 | 134476672954444 | 1.94, 1.81, 1.25 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.055, -0.015 |
| inf_runner_lower_torso | 88359244284243 | 106695059140827 | 2.01, 0.40, 1.09 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, -0.035 |
| inf_runner_upper_arm | 123865928638635 | 97918719949523 | 0.89, 1.22, 0.90 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.010, -0.010 |
| inf_runner_lower_arm | 105743362905245 | 132597105260862 | 0.74, 1.12, 0.77 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, -0.005 |
| inf_runner_hand | 112441012464559 | 79365237811651 | 0.98, 0.34, 1.18 | R15 limb (v2 2026-11-07), offset 0.000, 0.010, -0.080 |
| inf_runner_upper_leg | 77353023411798 | 86901390883494 | 0.92, 1.40, 1.05 | R15 limb (skin v2 2026-11-07), offset 0.000, -0.020, -0.063 |
| inf_runner_lower_leg | 77168222660520 | 133065158250400 | 0.96, 1.30, 0.96 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_runner_foot | 101646860898946 | 139809077230027 | 1.01, 0.32, 1.15 | R15 limb (v2 2026-11-07), offset 0.000, 0.008, 0.075 |
| inf_brute_head | 111819664336015 | 77756429766290 | 1.27, 1.24, 1.30 | R15 limb (skin v2 2026-11-07), offset 0.015, 0.030, -0.030 |
| inf_brute_upper_torso | 74874414531963 | 85855571335282 | 2.10, 1.95, 1.47 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.125, 0.034 |
| inf_brute_lower_torso | 123309828753718 | 83908206117109 | 2.01, 0.40, 1.09 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, -0.035 |
| inf_brute_upper_arm | 133254036749836 | 118403209465589 | 0.82, 1.24, 0.78 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_brute_lower_arm | 131637342574392 | 100989347666393 | 1.19, 1.12, 1.01 | R15 limb (skin v2 2026-11-07), offset 0.095, 0.000, -0.006 |
| inf_brute_hand | 139690589575020 | 114010551344148 | 0.98, 0.41, 1.05 | R15 limb (v2 2026-11-07), offset 0.000, -0.005, -0.035 |
| inf_brute_upper_leg | 96003182956310 | 121920230299655 | 1.02, 1.49, 1.13 | R15 limb (skin v2 2026-11-07), offset 0.020, -0.065, -0.076 |
| inf_brute_lower_leg | 104847318095639 | 102942322533440 | 0.99, 1.30, 1.03 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, -0.028 |
| inf_brute_foot | 129900549102552 | 86637950340205 | 1.01, 0.37, 1.07 | R15 limb (v2 2026-11-07), offset 0.000, 0.027, -0.035 |
| inf_hocker_head | 126429750811463 | 99961797424897 | 1.33, 1.58, 1.68 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.002, -0.040 |
| inf_hocker_upper_torso | 136320366451034 | 99485094541500 | 2.00, 1.75, 1.19 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.025, 0.003 |
| inf_hocker_lower_torso | 115889571442634 | 126844940436737 | 2.05, 0.43, 1.37 | R15 limb (v2 2026-11-07), offset 0.000, 0.005, -0.045 |
| inf_hocker_upper_arm | 126385736674962 | 111804259787762 | 0.87, 1.24, 0.87 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_hocker_lower_arm | 76090964452945 | 93281343211347 | 0.74, 1.12, 0.74 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_hocker_hand | 107899889726305 | 119976682392082 | 0.98, 0.52, 1.15 | R15 limb (v2 2026-11-07), offset 0.000, -0.090, -0.067 |
| inf_hocker_upper_leg | 133917422037960 | 77578052851832 | 1.00, 1.40, 1.13 | R15 limb (skin v2 2026-11-07, Walker mesh), offset 0.000, -0.020, 0.016 |
| inf_hocker_lower_leg | 129665594524599 | 139491515162004 | 0.99, 1.30, 0.97 | R15 limb (skin v2 2026-11-07, Walker mesh), offset 0.000, 0.000, 0.000 |
| inf_hocker_foot | 79144855233866 | 139880549411227 | 1.01, 0.31, 1.00 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| pc_assault_head | 113120416771558 | 108816968954550 | 1.34, 1.24, 1.54 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.030, -0.060 |
| pc_assault_upper_torso | 109606627346841 | 101027325915224 | 1.94, 1.70, 1.51 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.000, -0.025 |
| pc_assault_lower_torso | 130324769107274 | 103310952242998 | 2.01, 0.40, 1.12 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.000, -0.050 |
| pc_assault_upper_arm | 137615567202319 | 129827927152847 | 1.04, 1.44, 1.10 | R15 limb (Weller v3 tapered 2026-11-07), offset 0.000, -0.098, -0.030 |
| pc_assault_lower_arm | 135982743004456 | 114217511098805 | 1.00, 1.12, 1.00 | R15 limb (Weller v4 tapered, 0.84 cuff 2026-11-07), offset 0.000, 0.000, 0.000 |
| pc_assault_hand | 78025074389286 | 102964661396130 | 0.82, 0.33, 0.88 | R15 limb (Weller v3 fist 2026-11-07), offset 0.000, 0.000, -0.010 |
| pc_assault_upper_leg | 96325067678523 | 114031815727891 | 1.08, 1.59, 1.09 | R15 limb (Weller v3 tapered 2026-11-07), offset 0.043, -0.115, -0.058 |
| pc_assault_lower_leg | 131875477288797 | 108866156558305 | 1.01, 1.30, 0.99 | R15 limb (Weller v3 tapered 2026-11-07), offset 0.000, 0.000, 0.000 |
| pc_assault_foot | 79144855233866 | 112575972731289 | 1.01, 0.31, 1.00 | R15 limb (Weller v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| pc_assault_skinned (skin) | 106205735830249 (v1) | 87236345847400 | 3.98, 5.45, 1.26 | Weller skinned body, one MeshPart with 16 Bones (`MeshAssets.SKINNED_BODIES.body`, loaded whole with LoadAsset; v2 fist hands 2026-11-07) |
| pc_assault_skinned_parts (hidden rig) | 15 meshes | 89768415142935 | R15 boxes | the same geometry split per R15 limb with Motor6Ds (`SKINNED_BODIES.parts`; v2 2026-11-07) |
| pc_assault_gear_helmet | 106002887456604 | 115206275662165 | 1.34, 1.11, 1.54 | rigid gear on Head, offset 0.000, 0.095, -0.060 |
| pc_assault_gear_carrier | 136938794151000 | 103203928656779 | 1.53, 1.44, 1.51 | rigid gear on UpperTorso, offset -0.025, 0.120, -0.025 |
| inf_warden_head | 91451946704174 | 125862857256724 | 1.26, 1.22, 1.26 | R15 limb (the Warden); 2026-11-07, offset 0.020, 0.020, -0.050 |
| inf_warden_upper_torso | 127929460133902 | 70398955261052 | 2.10, 1.93, 1.23 | R15 limb (the Warden); 2026-11-07, offset 0.000, 0.115, -0.044 |
| inf_warden_lower_torso | 135925546743840 | 71175322983905 | 2.36, 0.50, 1.13 | R15 limb (the Warden); 2026-11-07, offset 0.040, -0.040, -0.055 |
| inf_warden_upper_arm_l | 128429828626584 | 87060185256263 | 0.90, 1.24, 0.87 | R15 limb (the Warden, side-specific arm); 2026-11-07, offset -0.018, 0.000, 0.000 |
| inf_warden_upper_arm_r | 92719408011297 | 128852748802007 | 0.88, 1.24, 0.87 | R15 limb (the Warden, side-specific arm); 2026-11-07, offset 0.008, 0.000, 0.000 |
| inf_warden_lower_arm_l | 119556389365321 | 88018299009582 | 1.28, 1.10, 0.99 | R15 limb (the Warden, side-specific arm); 2026-11-07, offset -0.160, -0.010, -0.015 |
| inf_warden_lower_arm_r | 103182885123605 | 127119804504870 | 1.16, 1.10, 1.00 | R15 limb (the Warden, side-specific arm); 2026-11-07, offset 0.099, -0.010, -0.020 |
| inf_warden_hand | 90513292529609 | 119267048723164 | 0.98, 0.41, 1.05 | R15 limb (the Warden); 2026-11-07, offset 0.000, -0.005, -0.035 |
| inf_warden_upper_leg | 135036799820300 | 95714787492482 | 0.96, 1.38, 1.08 | R15 limb (the Warden); 2026-11-07, offset 0.000, -0.010, -0.060 |
| inf_warden_lower_leg | 110791812728893 | 124541262283914 | 0.99, 1.30, 1.09 | R15 limb (the Warden); 2026-11-07, offset 0.000, 0.000, -0.058 |
| inf_warden_foot | 88019661795689 | 121443990789556 | 1.01, 0.34, 1.05 | R15 limb (the Warden); 2026-11-07, offset 0.000, 0.017, -0.025 |
| inf_warden_plate_helmet | 93019556832338 | 123255776325658 | 1.51, 1.12, 1.65 | Warden plate (IndexService welds it to Head); 2026-11-07, offset 0.025, 0.160, -0.065 |
| inf_warden_plate_chest | 119813747852082 | 117709402038329 | 1.90, 1.42, 0.60 | Warden plate (IndexService welds it to UpperTorso); 2026-11-07, offset 0.000, -0.010, -0.770 |
| inf_warden_plate_back | 117946002815095 | 82460354205839 | 1.90, 1.40, 0.53 | Warden plate (IndexService welds it to UpperTorso); 2026-11-07, offset 0.000, 0.000, 0.735 |
| inf_warden_plate_shoulder | 138769670496956 | 79528139241232 | 1.33, 0.51, 1.33 | Warden plate (IndexService welds it to either UpperArm); 2026-11-07, offset 0.000, 0.515, 0.000 |
| inf_warden_plate_shield | 81264490942347 | 114017635854116 | 2.08, 4.00, 0.68 | Warden plate (IndexService welds it to LeftLowerArm); 2026-11-07, offset -0.600, -0.300, -0.510 |
| env_bus | 115848012015557 | 84471628520896 | 42.9 x 12.75 x 10.9 | solid; the Gate bus line (ArenaService), Mile 14 later; 2026-11-07 |

Open Cloud imports the FBX at 100x (1 Blender unit → 100 studs) and clamps any axis to 2048,
so the imported size is meaningless; `MeshAssets.luau` sets the intended stud size (Blender
dimensions X, Z, Y) and the MeshPart scales the mesh to it.
