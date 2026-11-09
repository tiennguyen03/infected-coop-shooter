# assets/3d — Roblox asset ids

Uploaded 2026-11-06 via Open Cloud (`upload_asset`, assetType Model for FBX, Decal for the
palette). Mesh ids were read in Studio with `InsertService:LoadAsset(<modelAssetId>)` and are
wired into `src/shared/MeshAssets.luau` (server-built MeshPart templates). Old env v1 model
uploads (126781711029053, 110183901153071, 111918726514098) are superseded.

Palette texture (v5, 2026-11-08, cells 57-60 `glass`, `glass_l`, `paint_maroon`,
`paint_navy` appended): decal `120194869942486` → image **`121741835746247`** (the
`TextureID`). v4 (skin v2) was `80401218749683` → `115366221483568`; v3 was `120331040807954` → `110782102234723`, v2
`88256641133314`, v1 `87519201884536`.

Distant city window grid (2026-11-08, retired the same day for the `city.py` towers):
decal `115304423103431` → image `75759991359237`.

Z-fight re-upload (2026-11-08): `env_ruin_building`, `env_bus`, `env_guard_tower`,
`env_tent`, `env_wreck_humvee`, `env_twall`, `env_hesco_tall` and the five vehicles were
rebuilt with `Builder.resolve_zfight` and uploaded again; their rows carry the new ids.

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
| wpn_revolver | 133525801275343 | 110455613061010 | 0.25 x 0.76 x 1.0 | S&W 686 sample gun (guns.py, in-game size); offset/muzzle in MeshAssets |
| wpn_sniper | 86507403821540 | 138249511970708 | 0.46 x 1.07 x 3.65 | M2010 ESR sample gun |
| wpn_goose | 82637563176152 | 80902890703049 | 0.6 x 0.94 x 3.03 | M3 recoilless ("Goose") sample launcher |
| wpn_m16 | 74091027600803 | 104945563283109 | 0.27 x 1.02 x 3.09 | M16A4 (guns.py, in-game size) |
| wpn_mp5 | 84221584333359 | 112693756802429 | 0.23 x 0.87 x 2.19 | MP5A3 (guns.py, in-game size) |
| wpn_m249 | 106050421873423 | 129764792627355 | 0.32 x 0.95 x 2.89 | M249 SAW (guns.py, in-game size) |
| wpn_mossberg | 101866256014088 | 103329258934721 | 0.26 x 0.77 x 2.82 | Mossberg 590 (guns.py, in-game size) |
| wpn_m110 | 124848490890431 | 88359560754649 | 0.23 x 1.03 x 3.25 | M110 SASS (guns.py, in-game size) |
| wpn_m17 | 104797900074658 | 80875013937947 | 0.14 x 0.76 x 0.67 | M17 (guns.py, in-game size) |
| prop_plague_rat | 102065990394982 | 135041557109073 | 0.47 x 0.52 x 1.88 | 0.7x of Blender; PlagueRatService PrimaryPart, faces -Z |
| prop_car_sedan | 133589928038621 | 139871373094934 | 14.88 x 4.57 x 6.61 | offset (0, 2.286, -0.098); 2026-11-08, `props.py` |
| prop_car_hatch | 97663934153782 | 136632195416849 | 12.88 x 5.6 x 8.24 | offset (0, 2.8, -0.919) |
| prop_car_pickup | 117043997323617 | 94883927074894 | 18.14 x 5.4 x 7 | offset (0.38, 2.7, 0) |
| prop_car_van | 107756699293007 | 90984423879699 | 17.81 x 7.2 x 7.2 | offset (0.467, 3.6, 0) |
| prop_cargo_truck | 109079007816233 | 77214428896979 | 24.28 x 9.82 x 9.75 | offset (0.392, 4.912, 0); Open Cloud clamps the import to 2048, the in-game Size restores it |
| env_city_office | 99343457194346 | 114000808366452 | 65.6 x 178.5 x 45.6 | office slab; SkyService skyline, offsets in MeshAssets |
| env_city_office_lit | 137262251701871 | 114932257491485 | 64.34 x 146.1 x 44.34 | its lit windows (Neon) |
| env_city_residential | 105255167927156 | 100403444152439 | 52.2 x 126.5 x 37 | apartment block |
| env_city_residential_lit | 77011644815213 | 131589267004783 | 50.34 x 102.6 x 32.34 |  |
| env_city_deco | 74663241301810 | 96482232581851 | 58 x 253 x 58 | stepped deco tower |
| env_city_deco_lit | 108427367633529 | 88192651672325 | 56.34 x 252.5 x 56.34 |  |
| env_city_glass | 94468053772491 | 125300114956251 | 51.39 x 202.2 x 51.39 | glass curtain wall |
| env_city_glass_lit | 109060226686011 | 134878974427574 | 48.34 x 167.8 x 48.34 |  |
| env_city_ruined | 91159310318208 | 119279001694730 | 55.6 x 132.64 x 37.85 | burned-out shell |
| env_city_ruined_lit | 128244578925003 | 125945574546312 | 53.47 x 65.2 x 29.47 |  |
| env_city_midrise | 131802731205834 | 97416410693850 | 93.2 x 85 x 43.2 | wide mid-rise with a billboard |
| env_city_midrise_lit | 92670539790330 | 117149048575756 | 91.34 x 58.1 x 42.34 |  |
| env_barrier_jersey | 83842095201437 | 120043526542183 | 6 x 2.75 x 2 | solid; ArenaService dressing |
| env_sandbag_bunker (v2) | 72798329648015 | 104090605242659 | 12.8 x 6.3 x 10.8 | solid; rebuilt 2026-11-06 to character scale |
| env_guard_tower (v2, superseded) | 140295675948906 | 86672166489335 | 11 x 27.25 x 11 | solid; rebuilt 2026-11-06 |
| env_ruin_building (2026-11-06, superseded) | 112569589520919 | 75991267203586 | 32.73 x 24.6 x 25.35 | solid; rebuilt 2026-11-06 (10.5-stud storeys) |
| env_container_olive | 90739805417437 | 132200158345619 | 22.1 x 9.55 x 9.2 | solid |
| env_container_rust | 108583453603951 | 134169217220802 | 22.1 x 9.55 x 9.2 | solid |
| env_wreck_humvee | 87433680532014 | 93009747032303 | 17 x 7.11 x 8.1 | solid; nose toward -X |
| env_twall | 107388028009682 | 81832347321551 | 8.05 x 12.5 x 2.6 | solid |
| env_hesco | 76249676881241 | 85372982024960 | 6.22 x 4.58 x 4.72 | solid |
| env_crib_stack | 84277153513044 | 97934930804371 | 1.20 x 2.80 x 2.60 | pivot bottom, offset (0.000, 1.400, 0.000); cribbing under a lifted T-wall (Scrapes) |
| env_deck_plate | 87378908913829 | 75563930153038 | 12.00 x 0.33 x 5.00 | pivot bottom, offset (0.000, 0.165, 0.000); walkable road plate between roofs |
| env_guard_tower | 85279268257603 | 85957259038112 | 11.00 x 27.25 x 11.00 | pivot bottom, offset (0.000, 13.625, 0.000); v3 rail gate; composite colliders + TrussPart ladder; replaces 140295675948906 |
| env_hesco_tall | 80810183774155 | 71019273814951 | 6.32 x 8.88 x 4.72 | pivot bottom, offset (0.000, 4.440, 0.000); two-high hesco (the Pens ring) |
| env_ruin_building | 72875984069129 | 139021877568612 | 32.09 x 23.60 x 25.15 | pivot bottom, offset (0.847, 11.800, -0.517); v2 enterable; composite colliders, `shell` for outer ruins; replaces 112569589520919 |
| prop_body_bag | 138563921819343 | 73076169933777 | 6.60 x 0.95 x 2.20 | pivot bottom, offset (0.100, 0.475, 0.000); prop (Delta rework 2026-11-07) |
| prop_chainlink_panel | 135724153731021 | 125979502358349 | 12.06 x 7.00 x 0.30 | pivot bottom, offset (0.000, 3.500, 0.000); prop (Delta rework 2026-11-07) |
| prop_civilian_car (retired 2026-11-08) | 131007713996765 | 117334770094341 | 15.70 x 4.80 x 7.50 | replaced by the four `prop_car_*` |
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
| env_tent | 96064782371543 | 119391750870040 | 19.2 x 8.6 x 12 | solid; door on -X |
| env_checkpoint | 71573561117915 | 129215637928455 | 22.05 x 9.5 x 7.4 | Box + composite colliders (2026-11-07); booth at -X, boom along +X |
| env_dead_tree | 103119294791056 | 130464254006022 | 4.97 x 13.98 x 7.09 | Hull |
| env_lamp_post | 132474171948585 | 84369687950095 | 4.9 x 13 x 1.2 | Hull; arm along +X |
| inf_gore_stump | 85306816428466 | 84507882691071 | 0.42, 0.24, 0.44 | GoreService stump (gore.py 2026-11-08), offset 0.014, 0.070, 0 |
| inf_gore_chunk_a | 114738807263836 | 112453961195196 | 0.29, 0.32, 0.30 | GoreFX chunk |
| inf_gore_chunk_b | 101420964172693 | 102105594077537 | 0.36, 0.26, 0.27 | GoreFX chunk |
| inf_gore_chunk_c | 120197171903263 | 119620354840068 | 0.34, 0.18, 0.17 | GoreFX chunk (bone shard) |
| inf_walker_head | 100515274220050 | 96525896467639 | 1.22, 1.60, 1.48 | R15 limb (posture v3 2026-11-08), offset -0.000, -0.115, -0.344 |
| inf_walker_upper_torso | 133210664116166 | 77996586747509 | 2.00, 1.75, 1.20 | R15 limb (posture v3 2026-11-08), offset 0.000, 0.025, 0.000 |
| inf_walker_lower_torso | 78160694473395 | 71379557871731 | 2.05, 1.51, 1.53 | R15 limb (posture v3 2026-11-08), offset 0.000, -0.535, 0.036 |
| inf_walker_upper_arm_l | 88373539845018 | 99946853319148 | 0.92, 1.24, 0.92 | R15 limb (posture v3 2026-11-08), offset 0.000, 0.000, 0.000 |
| inf_walker_upper_arm_r | 80180134149538 | 82152410042337 | 0.92, 1.00, 0.92 | R15 limb (posture v3 2026-11-08), offset 0.000, -0.140, 0.000 |
| inf_walker_lower_arm | 119147668768706 | 113984093219431 | 0.85, 1.12, 0.85 | R15 limb (posture v3 2026-11-08), offset 0.000, 0.000, 0.000 |
| inf_walker_hand | 119988488149184 | 107551213918410 | 0.98, 0.48, 1.03 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.002, -0.002 |
| inf_walker_upper_leg | 100166126486572 | 110936558013718 | 0.89, 1.40, 0.99 | R15 limb (posture v3 2026-11-08), offset 0.000, -0.020, -0.052 |
| inf_walker_lower_leg | 104774868957400 | 78570732273452 | 0.99, 1.30, 0.97 | R15 limb (posture v3 2026-11-08), offset 0.000, 0.000, 0.000 |
| inf_walker_foot | 79144855233866 | 130560415633858 | 1.01, 0.31, 1.00 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_runner_head | 115350210417323 | 99527107231180 | 1.22, 1.36, 1.39 | R15 limb (posture v3 2026-11-08), offset 0.000, -0.320, -0.570 |
| inf_runner_upper_torso | 106499208970226 | 95211427405366 | 1.98, 2.36, 1.77 | R15 limb (posture v3 2026-11-08), offset 0.000, 0.158, -0.260 |
| inf_runner_lower_torso | 88359244284243 | 106695059140827 | 2.01, 0.40, 1.09 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, -0.035 |
| inf_runner_upper_arm | 99272691499999 | 95846443993846 | 0.89, 1.22, 0.90 | R15 limb (posture v3 2026-11-08), offset 0.000, 0.010, -0.460 |
| inf_runner_lower_arm | 125089922702221 | 81168002296799 | 0.74, 1.67, 0.77 | R15 limb (posture v3 2026-11-08), offset 0.000, -0.275, -0.455 |
| inf_runner_hand | 117210071350373 | 70427945799158 | 0.86, 0.88, 0.60 | R15 limb (posture v3 2026-11-08), offset 0.000, -0.860, -0.410 |
| inf_runner_upper_leg | 77353023411798 | 86901390883494 | 0.92, 1.40, 1.05 | R15 limb (skin v2 2026-11-07), offset 0.000, -0.020, -0.063 |
| inf_runner_lower_leg | 77168222660520 | 133065158250400 | 0.96, 1.30, 0.96 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_runner_foot | 101646860898946 | 139809077230027 | 1.01, 0.32, 1.15 | R15 limb (v2 2026-11-07), offset 0.000, 0.008, 0.075 |
| inf_brute_head | 103853795558690 | 112897071804721 | 1.27, 1.24, 1.30 | R15 limb (posture v3 2026-11-08), offset 0.015, -0.420, -0.110 |
| inf_brute_upper_torso | 99564421484824 | 95179129947227 | 2.86, 3.11, 1.87 | R15 limb (posture v3 2026-11-08), offset 0.000, 0.566, 0.094 |
| inf_brute_lower_torso | 70399681157365 | 104904832594345 | 2.40, 1.00, 1.28 | R15 limb (posture v3 2026-11-08), offset 0.000, -0.300, -0.040 |
| inf_brute_upper_arm_l | 128620933727692 | 75060819713309 | 0.86, 1.26, 0.82 | R15 limb (posture v3 2026-11-08), offset -0.420, 0.010, -0.001 |
| inf_brute_upper_arm_r | 109702256756531 | 125579605421087 | 0.86, 1.26, 0.82 | R15 limb (posture v3 2026-11-08), offset 0.420, 0.010, -0.001 |
| inf_brute_lower_arm_l | 89240920651366 | 83080707263655 | 1.19, 2.12, 1.01 | R15 limb (posture v3 2026-11-08), offset -0.515, -0.500, -0.006 |
| inf_brute_lower_arm_r | 102739257900431 | 123189366999280 | 1.19, 2.12, 1.01 | R15 limb (posture v3 2026-11-08), offset 0.515, -0.500, -0.006 |
| inf_brute_hand_l | 121604236987350 | 119142781439363 | 0.98, 0.53, 1.05 | R15 limb (posture v3 2026-11-08), offset -0.420, -1.145, -0.035 |
| inf_brute_hand_r | 99800347349644 | 71221605255685 | 0.98, 0.53, 1.05 | R15 limb (posture v3 2026-11-08), offset 0.420, -1.145, -0.035 |
| inf_brute_upper_leg | 105750520943611 | 97152603013989 | 1.04, 1.49, 1.13 | R15 limb (posture v3 2026-11-08), offset 0.030, -0.065, -0.076 |
| inf_brute_lower_leg | 88426621788507 | 105910953985160 | 1.04, 1.32, 1.07 | R15 limb (posture v3 2026-11-08), offset 0.000, 0.010, -0.025 |
| inf_brute_foot | 129900549102552 | 86637950340205 | 1.01, 0.37, 1.07 | R15 limb (v2 2026-11-07), offset 0.000, 0.027, -0.035 |
| inf_hocker_head | 108032089223800 | 121535036344975 | 1.33, 1.60, 1.70 | R15 limb (posture v3 2026-11-08), offset 0.000, -0.029, 0.189 |
| inf_hocker_upper_torso | 72787016240114 | 98330054096854 | 2.00, 1.77, 1.27 | R15 limb (posture v3 2026-11-08), offset 0.000, 0.035, -0.035 |
| inf_hocker_lower_torso | 78160694473395 | 138616337764196 | 2.05, 1.51, 1.53 | R15 limb (posture v3 2026-11-08), offset 0.000, -0.535, 0.036 |
| inf_hocker_upper_arm | 126385736674962 | 111804259787762 | 0.87, 1.24, 0.87 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_hocker_lower_arm | 76090964452945 | 93281343211347 | 0.74, 1.12, 0.74 | R15 limb (skin v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_hocker_hand | 107899889726305 | 119976682392082 | 0.98, 0.52, 1.15 | R15 limb (v2 2026-11-07), offset 0.000, -0.090, -0.067 |
| inf_hocker_upper_leg | 71651625363542 | 107450044108565 | 0.89, 1.52, 1.23 | R15 limb (posture v3 2026-11-08), offset 0.000, 0.012, -0.235 |
| inf_hocker_lower_leg | 78707080286405 | 125328826241010 | 0.99, 1.38, 1.11 | R15 limb (posture v3 2026-11-08), offset 0.000, -0.093, -0.074 |
| inf_hocker_foot | 79144855233866 | 139880549411227 | 1.01, 0.31, 1.00 | R15 limb (v2 2026-11-07), offset 0.000, 0.000, 0.000 |
| inf_warden_head | 114272288507850 | 137776244732745 | 1.03, 1.20, 1.10 | R15 limb (the Warden v2); 2026-11-07, offset 0.015, 0.050, -0.050 |
| inf_warden_upper_torso | 129465433234843 | 111029482210404 | 1.94, 2.60, 1.52 | R15 limb (the Warden v2); 2026-11-07, offset 0.000, 0.450, 0.000 |
| inf_warden_lower_torso | 95229929171070 | 122177919361179 | 2.24, 1.12, 1.09 | R15 limb (the Warden v2); 2026-11-07, offset -0.011, -0.350, -0.065 |
| inf_warden_upper_arm_l | 90178215038369 | 121014183188168 | 0.92, 1.27, 0.92 | R15 limb (the Warden v2, side-specific); 2026-11-07, offset 0.000, -0.015, 0.000 |
| inf_warden_upper_arm_r | 114663756538931 | 76432220093143 | 0.91, 1.32, 0.93 | R15 limb (the Warden v2, side-specific); 2026-11-07, offset 0.013, -0.040, 0.023 |
| inf_warden_lower_arm_l | 109428525195459 | 103450056135438 | 0.96, 1.21, 0.96 | R15 limb (the Warden v2, side-specific; wrist grown to the shield handle); 2026-11-07, offset 0.000, -0.025, 0.000 |
| inf_warden_lower_arm_r | 108686202348825 | 87978240518037 | 1.20, 1.17, 1.06 | R15 limb (the Warden v2, side-specific); 2026-11-07, offset 0.081, -0.025, -0.012 |
| inf_warden_hand_l | 87995320009567 | 138361026663887 | 0.90, 0.36, 0.70 | R15 limb (the Warden v2, side-specific); 2026-11-07, offset 0.000, 0.000, 0.100 |
| inf_warden_hand_r | 118060365841446 | 87200468963000 | 1.10, 0.44, 1.12 | R15 limb (the Warden v2, side-specific); 2026-11-07, offset 0.000, 0.000, -0.040 |
| inf_warden_upper_leg | 110518444449837 | 136268599288059 | 0.85, 1.43, 1.00 | R15 limb (the Warden v2); 2026-11-07, offset 0.000, -0.035, -0.078 |
| inf_warden_lower_leg | 83521572303302 | 136245909527183 | 0.86, 1.30, 1.01 | R15 limb (the Warden v2); 2026-11-07, offset 0.000, 0.000, -0.075 |
| inf_warden_foot | 108286072751669 | 132546098095942 | 1.05, 0.34, 1.08 | R15 limb (the Warden v2); 2026-11-07, offset 0.000, 0.020, -0.010 |
| inf_warden_plate_helmet | 131116560609697 | 109284303024409 | 1.44, 1.46, 2.20 | Warden v2 plate (IndexService welds it to Head); 2026-11-07, offset 0.019, 0.060, 0.250 |
| inf_warden_plate_chest | 126497846796573 | 105012452580269 | 1.56, 1.56, 0.59 | Warden v2 plate (IndexService welds it to UpperTorso); 2026-11-07, offset 0.000, -0.010, -0.755 |
| inf_warden_plate_back | 93038447341544 | 91772239198090 | 1.59, 2.72, 0.57 | Warden v2 plate (IndexService welds it to UpperTorso); 2026-11-07, offset -0.015, 0.590, 0.745 |
| inf_warden_plate_shoulder_l | 78932474946165 | 97144883804954 | 1.66, 1.06, 1.66 | Warden v2 plate (IndexService welds it to LeftUpperArm); 2026-11-07, offset 0.000, 0.280, 0.000 |
| inf_warden_plate_shoulder_r | 94157814542903 | 118728353896085 | 1.11, 0.30, 1.11 | Warden v2 plate (IndexService welds it to RightUpperArm); 2026-11-07, offset 0.000, 0.480, 0.000 |
| inf_warden_plate_shield | 126685145123461 | 102529640193242 | 0.48 x 2.28 x 4.28 | v3 2026-11-07: strapped along the outer forearm (face -X), offset (-0.67, -0.2, 0.3) |
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
| env_bus | 132803646952127 | 113262814642765 | 42.9 x 12.75 x 10.9 | solid; the Gate bus line (ArenaService), Mile 14 later; 2026-11-07 |

Open Cloud imports the FBX at 100x (1 Blender unit → 100 studs) and clamps any axis to 2048,
so the imported size is meaningless; `MeshAssets.luau` sets the intended stud size (Blender
dimensions X, Z, Y) and the MeshPart scales the mesh to it.
