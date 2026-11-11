# assets/3d — Roblox asset ids

Mesh ids the game loads, all wired into `src/shared/MeshAssets.luau` (server-built MeshPart
templates; pipeline in [README.md](README.md)). Mesh ids are read in Studio with
`InsertService:LoadAsset(<modelAssetId>)`. Superseded and retired uploads (old palettes, the
v1/v2 env meshes, the window-grid texture, `prop_civilian_car`) were removed 2026-11-09; git
history has them.

Palette texture (v5, cells 0-60): decal `120194869942486` → image **`121741835746247`**
(the `TextureID`).

Rows marked "unused in game" are still registered in `MeshAssets` but no service clones
them.

| Mesh | MeshId | Model asset (upload) | In-game Size (studs) | Placement note |
|---|---|---|---|---|
| pick_xp_orb | 95196197176639 | 134499655967097 | 1.0 x 1.0 x 1.0 | unused in game (XP orbs retired) |
| prop_ammo_crate | 70908704628683 | 111854712064143 | 2.86 x 1.68 x 1.92 | pivot bottom: place at ground + 0.84 |
| prop_repulsor_mine | 122106813224951 | 102515645095030 | 1.9 x 0.97 x 2.0 | pivot bottom: place at ground + 0.485 |
Lobby meshes (12 `env_fallow_*`, 4 `veh_lantern_*`) uploaded 2026-11-09 to the group (270506601); MeshIds read in Studio through the built-in Studio MCP; rows at the end of the table. Re-uploaded the same day pre-mirrored in X (`build_assets.MIRROR_X_COLLECTIONS`: Roblox showed the first upload mirrored left-right); the rows carry the v2 ids.

| prop_drone | 132929388031760 | 93513427419630 | 1.94 x 0.43 x 1.94 | unused in game (drones retired) |
| prop_drone_beacon | 117405323536844 | 71937735064271 | 1.56 x 3.21 x 1.36 | unused in game |
| wpn_rifle | 86613539481097 | 77112302177721 | 0.195 x 0.84 x 2.9 | 0.65x of the Blender size; grip offset handled in PlayerSetup |
| wpn_revolver | 83543461161868 | 114514019723570 | 0.25 x 0.75 x 1.00 | S&W 686 sample gun (guns.py, in-game size); offset/muzzle in MeshAssets |
| wpn_sniper | 71899784449648 | 91471123884683 | 0.47 x 1.07 x 3.65 | M2010 ESR sample gun |
| wpn_goose | 91078392816733 | 84200379350190 | 0.62 x 0.94 x 3.03 | M3 recoilless ("Goose") sample launcher |
| wpn_m16 | 109914446546047 | 104914746717908 | 0.25 x 1.16 x 3.08 | M16A4 (guns.py, in-game size) |
| wpn_mp5 | 97053083297242 | 111456075554250 | 0.24 x 0.97 x 2.20 | MP5A3 (guns.py, in-game size) |
| wpn_m249 | 126749782608669 | 100923087686046 | 0.32 x 0.98 x 2.94 | M249 SAW (guns.py, in-game size) |
| wpn_mossberg | 74477534761633 | 95743569516175 | 0.26 x 0.80 x 2.86 | Mossberg 590 (guns.py, in-game size) |
| wpn_m110 | 87592748941938 | 87838172578916 | 0.23 x 1.11 x 3.27 | M110 SASS (guns.py, in-game size) |
| wpn_m17 | 113489832840781 | 133642910354030 | 0.14 x 0.76 x 0.67 | M17 (guns.py, in-game size) |
| veh_shrike_hull | 137109529997310 | 107275791771348 | 8.4 x 8.62 x 29.75 | the Shrike gunship (aircraft.py); offset from the fuselage centre in MeshAssets |
| veh_shrike_rotor | 137738331555839 | 103052309432570 | 18.96 x 0.35 x 18.89 | its main rotor, origin at the hub; spun by AirStrikeService |
| prop_plague_rat | 102065990394982 | 135041557109073 | 0.47 x 0.52 x 1.88 | unused in game (plague rat retired) |
| prop_car_sedan | 133589928038621 | 139871373094934 | 14.88 x 4.57 x 6.61 | offset (0, 2.286, -0.098); `props.py` |
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
| env_sandbag_bunker (v2) | 72798329648015 | 104090605242659 | 12.8 x 6.3 x 10.8 | solid |
| env_container_olive | 90739805417437 | 132200158345619 | 22.1 x 9.55 x 9.2 | solid |
| env_container_rust | 108583453603951 | 134169217220802 | 22.1 x 9.55 x 9.2 | solid |
| env_wreck_humvee | 87433680532014 | 93009747032303 | 17 x 7.11 x 8.1 | solid; nose toward -X |
| env_twall | 107388028009682 | 81832347321551 | 8.05 x 12.5 x 2.6 | solid |
| env_hesco | 76249676881241 | 85372982024960 | 6.22 x 4.58 x 4.72 | solid |
| env_crib_stack | 84277153513044 | 97934930804371 | 1.20 x 2.80 x 2.60 | pivot bottom, offset (0.000, 1.400, 0.000); cribbing under a lifted T-wall (Scrapes) |
| env_deck_plate | 87378908913829 | 75563930153038 | 12.00 x 0.33 x 5.00 | pivot bottom, offset (0.000, 0.165, 0.000); walkable road plate between roofs |
| env_guard_tower | 85279268257603 | 85957259038112 | 11.00 x 27.25 x 11.00 | pivot bottom, offset (0.000, 13.625, 0.000); composite colliders + TrussPart ladder |
| env_hesco_tall | 80810183774155 | 71019273814951 | 6.32 x 8.88 x 4.72 | pivot bottom, offset (0.000, 4.440, 0.000); two-high hesco (the Pens ring) |
| env_ruin_building | 72875984069129 | 139021877568612 | 32.09 x 23.60 x 25.15 | pivot bottom, offset (0.847, 11.800, -0.517); enterable, composite colliders, `shell` for outer ruins |
| prop_body_bag | 138563921819343 | 73076169933777 | 6.60 x 0.95 x 2.20 | pivot bottom, offset (0.100, 0.475, 0.000) |
| prop_chainlink_panel | 135724153731021 | 125979502358349 | 12.06 x 7.00 x 0.30 | pivot bottom, offset (0.000, 3.500, 0.000) |
| prop_concertina | 110184084591558 | 137827068150629 | 12.13 x 2.89 x 2.93 | pivot bottom, offset (0.000, 1.447, 0.000) |
| prop_cot | 111579390093659 | 137412438411439 | 6.50 x 2.10 x 2.95 | pivot bottom, offset (0.000, 1.048, 0.000) |
| prop_dumpster | 135179607691394 | 108883133700802 | 7.50 x 4.40 x 4.24 | pivot bottom, offset (0.000, 2.200, 0.000) |
| prop_fuel_bladder | 104420152748932 | 124744311184847 | 11.00 x 3.03 x 7.40 | pivot bottom, offset (0.000, 1.513, 0.000) |
| prop_generator | 102465817431781 | 126567041190669 | 8.00 x 5.20 x 4.50 | pivot bottom, offset (0.000, 2.600, 0.000) |
| prop_light_tower | 109327327787712 | 97029406002742 | 4.70 x 17.95 x 3.90 | pivot bottom, offset (0.350, 8.975, 0.000) |
| prop_pallet | 85849726914721 | 95269029743380 | 4.05 x 0.57 x 4.00 | pivot bottom, offset (0.000, 0.285, 0.000) |
| prop_plank | 85743587635839 | 81118116311720 | 10.00 x 0.40 x 2.00 | pivot bottom, offset (0.000, 0.200, 0.000) |
| prop_portable_toilet | 106338287683599 | 137067132484823 | 4.30 x 8.45 x 4.39 | pivot bottom, offset (0.000, 4.225, -0.045) |
| env_comm_tower | 121850127656343 | 136043833521905 | 8.04 x 44.7 x 8 | solid; landmark |
| env_tent | 96064782371543 | 119391750870040 | 19.2 x 8.6 x 12 | solid; door on -X |
| env_checkpoint | 71573561117915 | 129215637928455 | 22.05 x 9.5 x 7.4 | Box + composite colliders; booth at -X, boom along +X |
| env_dead_tree | 103119294791056 | 130464254006022 | 4.97 x 13.98 x 7.09 | Hull |
| env_lamp_post | 132474171948585 | 84369687950095 | 4.9 x 13 x 1.2 | Hull; arm along +X |
| inf_gore_stump | 85306816428466 | 84507882691071 | 0.42, 0.24, 0.44 | GoreService stump, offset 0.014, 0.070, 0 |
| env_fallow_bow | 79486262325305 | 104622065954343 | 84.00 x 46.00 x 67.00 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_bow_trim | 132397837700021 | 97023816902354 | 108.38 x 28.06 x 40.35 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_mid_port | 122409690040918 | 88646751785808 | 1.40 x 47.60 x 240.00 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_mid_stbd | 88469209943203 | 83063655665064 | 6.70 x 47.60 x 240.00 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_mid_trim | 89298549327422 | 137758694973401 | 98.19 x 47.71 x 240.00 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_stern | 82182009942595 | 93667458396006 | 82.00 x 47.60 x 80.60 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_stern_trim | 73421811886287 | 128754286386619 | 93.39 x 46.11 x 83.60 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_island | 130312060133465 | 107187435436606 | 23.50 x 45.98 x 60.00 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_island_trim | 77115099660902 | 82654754437766 | 22.60 x 75.90 x 58.50 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_radar | 122770221853253 | 132374836460710 | 7.30 x 7.20 x 2.12 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_catwalk | 84242427975777 | 70496787014665 | 6.05 x 4.35 x 23.25 | the Fallow (`FallowArt`); offset in MeshAssets |
| env_fallow_catwalk_rafts | 108793529856112 | 83467676322971 | 6.05 x 4.35 x 23.25 | the Fallow (`FallowArt`); offset in MeshAssets |
| veh_lantern_body | 96644034649925 | 115134036147611 | 7.50 x 11.50 x 41.11 | Lantern (`LanternBird`); offset in MeshAssets |
| veh_lantern_trim | 120258286814432 | 120432139146773 | 7.94 x 11.65 x 30.05 | Lantern (`LanternBird`); offset in MeshAssets |
| veh_lantern_rotor | 72210514497412 | 112438582167862 | 38.01 x 1.14 x 38.01 | Lantern (`LanternBird`); offset in MeshAssets |
| veh_lantern_tail_rotor | 130131221968255 | 134128773314348 | 0.40 x 5.20 x 0.60 | Lantern (`LanternBird`); offset in MeshAssets |
| dep_doorman_base | 88745683715018 | 105696327827016 | 4.05 x 1.93 x 4.13 | the Doorman's tripod (`doorman.py`, `SentryService`, `Config.CallIns.Doorman.Model = 2`); origin on the ground, offset in MeshAssets; exported pre-mirrored in X |
| dep_doorman_cradle | 70576240552981 | 127041957980191 | 1.36 x 0.96 x 1.09 | its yoke; origin on the traverse axis 1.9 up; yaws |
| dep_doorman_gun | 75248273049381 | 86670337644554 | 1.95 x 1.53 x 5.54 | its gun, ammo can and sensor head; origin at the trunnion 2.6 up; pitches; muzzle 3.52 ahead |
| inf_gore_chunk_a | 114738807263836 | 112453961195196 | 0.29, 0.32, 0.30 | GoreFX chunk |
| inf_gore_chunk_b | 101420964172693 | 102105594077537 | 0.36, 0.26, 0.27 | GoreFX chunk |
| inf_gore_chunk_c | 120197171903263 | 119620354840068 | 0.34, 0.18, 0.17 | GoreFX chunk (bone shard) |
| inf_walker_head | 100515274220050 | 96525896467639 | 1.22, 1.60, 1.48 | offset -0.000, -0.115, -0.344 |
| inf_walker_upper_torso | 133210664116166 | 77996586747509 | 2.00, 1.75, 1.20 | offset 0.000, 0.025, 0.000 |
| inf_walker_lower_torso | 78160694473395 | 71379557871731 | 2.05, 1.51, 1.53 | offset 0.000, -0.535, 0.036 |
| inf_walker_upper_arm_l | 88373539845018 | 99946853319148 | 0.92, 1.24, 0.92 | offset 0.000, 0.000, 0.000 |
| inf_walker_upper_arm_r | 80180134149538 | 82152410042337 | 0.92, 1.00, 0.92 | offset 0.000, -0.140, 0.000 |
| inf_walker_lower_arm | 119147668768706 | 113984093219431 | 0.85, 1.12, 0.85 | offset 0.000, 0.000, 0.000 |
| inf_walker_hand | 119988488149184 | 107551213918410 | 0.98, 0.48, 1.03 | offset 0.000, 0.002, -0.002 |
| inf_walker_upper_leg | 100166126486572 | 110936558013718 | 0.89, 1.40, 0.99 | offset 0.000, -0.020, -0.052 |
| inf_walker_lower_leg | 104774868957400 | 78570732273452 | 0.99, 1.30, 0.97 | offset 0.000, 0.000, 0.000 |
| inf_walker_foot | 79144855233866 | 130560415633858 | 1.01, 0.31, 1.00 | offset 0.000, 0.000, 0.000 |
| inf_runner_head | 115350210417323 | 99527107231180 | 1.22, 1.36, 1.39 | offset 0.000, -0.320, -0.570 |
| inf_runner_upper_torso | 106499208970226 | 95211427405366 | 1.98, 2.36, 1.77 | offset 0.000, 0.158, -0.260 |
| inf_runner_lower_torso | 88359244284243 | 106695059140827 | 2.01, 0.40, 1.09 | offset 0.000, 0.000, -0.035 |
| inf_runner_upper_arm | 99272691499999 | 95846443993846 | 0.89, 1.22, 0.90 | offset 0.000, 0.010, -0.460 |
| inf_runner_lower_arm | 125089922702221 | 81168002296799 | 0.74, 1.67, 0.77 | offset 0.000, -0.275, -0.455 |
| inf_runner_hand | 117210071350373 | 70427945799158 | 0.86, 0.88, 0.60 | offset 0.000, -0.860, -0.410 |
| inf_runner_upper_leg | 77353023411798 | 86901390883494 | 0.92, 1.40, 1.05 | offset 0.000, -0.020, -0.063 |
| inf_runner_lower_leg | 77168222660520 | 133065158250400 | 0.96, 1.30, 0.96 | offset 0.000, 0.000, 0.000 |
| inf_runner_foot | 101646860898946 | 139809077230027 | 1.01, 0.32, 1.15 | offset 0.000, 0.008, 0.075 |
| inf_brute_head | 103853795558690 | 112897071804721 | 1.27, 1.24, 1.30 | offset 0.015, -0.420, -0.110 |
| inf_brute_upper_torso | 99564421484824 | 95179129947227 | 2.86, 3.11, 1.87 | offset 0.000, 0.566, 0.094 |
| inf_brute_lower_torso | 70399681157365 | 104904832594345 | 2.40, 1.00, 1.28 | offset 0.000, -0.300, -0.040 |
| inf_brute_upper_arm_l | 128620933727692 | 75060819713309 | 0.86, 1.26, 0.82 | offset -0.420, 0.010, -0.001 |
| inf_brute_upper_arm_r | 109702256756531 | 125579605421087 | 0.86, 1.26, 0.82 | offset 0.420, 0.010, -0.001 |
| inf_brute_lower_arm_l | 89240920651366 | 83080707263655 | 1.19, 2.12, 1.01 | offset -0.515, -0.500, -0.006 |
| inf_brute_lower_arm_r | 102739257900431 | 123189366999280 | 1.19, 2.12, 1.01 | offset 0.515, -0.500, -0.006 |
| inf_brute_hand_l | 121604236987350 | 119142781439363 | 0.98, 0.53, 1.05 | offset -0.420, -1.145, -0.035 |
| inf_brute_hand_r | 99800347349644 | 71221605255685 | 0.98, 0.53, 1.05 | offset 0.420, -1.145, -0.035 |
| inf_brute_upper_leg | 105750520943611 | 97152603013989 | 1.04, 1.49, 1.13 | offset 0.030, -0.065, -0.076 |
| inf_brute_lower_leg | 88426621788507 | 105910953985160 | 1.04, 1.32, 1.07 | offset 0.000, 0.010, -0.025 |
| inf_brute_foot | 129900549102552 | 86637950340205 | 1.01, 0.37, 1.07 | offset 0.000, 0.027, -0.035 |
| inf_hocker_head | 108032089223800 | 121535036344975 | 1.33, 1.60, 1.70 | offset 0.000, -0.029, 0.189 |
| inf_hocker_upper_torso | 72787016240114 | 98330054096854 | 2.00, 1.77, 1.27 | offset 0.000, 0.035, -0.035 |
| inf_hocker_lower_torso | 78160694473395 | 138616337764196 | 2.05, 1.51, 1.53 | offset 0.000, -0.535, 0.036 |
| inf_hocker_upper_arm | 126385736674962 | 111804259787762 | 0.87, 1.24, 0.87 | offset 0.000, 0.000, 0.000 |
| inf_hocker_lower_arm | 76090964452945 | 93281343211347 | 0.74, 1.12, 0.74 | offset 0.000, 0.000, 0.000 |
| inf_hocker_hand | 107899889726305 | 119976682392082 | 0.98, 0.52, 1.15 | offset 0.000, -0.090, -0.067 |
| inf_hocker_upper_leg | 71651625363542 | 107450044108565 | 0.89, 1.52, 1.23 | offset 0.000, 0.012, -0.235 |
| inf_hocker_lower_leg | 78707080286405 | 125328826241010 | 0.99, 1.38, 1.11 | offset 0.000, -0.093, -0.074 |
| inf_hocker_foot | 79144855233866 | 139880549411227 | 1.01, 0.31, 1.00 | offset 0.000, 0.000, 0.000 |
| inf_v2_walker_head | 106046525739295 | 76977696227889 | 1.38, 1.92, 1.40 | offset 0.165, -0.179, -0.358 The remade bodies (`infected_v2.py`), uploaded 2026-11-11 pre-mirrored in X (`MIRROR_X_PREFIXES`); worn when `Config.Enemies.BodyVersion` is 2, the `inf_<form>_*` rows above when it is 1 |
| inf_v2_walker_upper_torso | 130984694916153 | 89017958935363 | 2.10, 2.04, 1.23 | offset 0.048, 0.170, -0.015 |
| inf_v2_walker_lower_torso | 116673965788066 | 80906151254901 | 2.05, 1.51, 1.53 | offset 0.000, -0.535, 0.036 |
| inf_v2_walker_upper_arm_l | 113808700591325 | 91675238648185 | 0.92, 1.24, 0.92 | offset 0.000, 0.000, 0.000 |
| inf_v2_walker_upper_arm_r | 77497709366262 | 72557237502062 | 0.92, 0.92, 0.92 | offset 0.000, -0.160, 0.000 |
| inf_v2_walker_lower_arm_l | 110020715905919 | 71724120696455 | 0.85, 1.12, 0.85 | offset 0.000, 0.000, 0.000 |
| inf_v2_walker_lower_arm_r | 122085562689176 | 107145228827460 | 0.89, 1.47, 0.98 | offset 0.000, -0.155, -0.048 |
| inf_v2_walker_hand_l | 132475899202414 | 134121077861207 | 0.98, 0.48, 1.03 | offset 0.000, 0.002, -0.002 |
| inf_v2_walker_hand_r | 86081304835633 | 108100816160761 | 1.06, 0.63, 1.05 | offset 0.000, -0.315, -0.013 |
| inf_v2_walker_upper_leg_l | 74493617508481 | 88259359260194 | 0.89, 1.40, 0.99 | offset 0.000, -0.020, -0.052 |
| inf_v2_walker_upper_leg_r | 118173706075340 | 133081136439639 | 0.92, 1.48, 1.03 | offset 0.000, -0.060, -0.051 |
| inf_v2_walker_lower_leg_l | 89226940260983 | 75676483540007 | 0.99, 1.30, 0.97 | offset 0.000, 0.000, 0.000 |
| inf_v2_walker_lower_leg_r | 130488390819949 | 101373566223369 | 0.82, 1.32, 0.78 | offset 0.018, 0.010, -0.001 |
| inf_v2_walker_foot_l | 89851504280755 | 130130481540412 | 1.01, 0.31, 1.00 | offset 0.000, 0.000, 0.000 |
| inf_v2_walker_foot_r | 103085284485495 | 91645402337491 | 0.86, 0.24, 1.02 | offset 0.000, 0.000, -0.020 |
| inf_v2_runner_head | 92992241182272 | 119564644087330 | 1.23, 1.49, 1.45 | offset 0.000, -0.382, -0.602 |
| inf_v2_runner_upper_torso | 112205940493491 | 74886176765658 | 2.03, 2.37, 1.85 | offset 0.000, 0.211, -0.259 |
| inf_v2_runner_lower_torso | 126259712134046 | 89991471033814 | 2.03, 0.51, 1.11 | offset 0.000, 0.055, -0.035 |
| inf_v2_runner_upper_arm | 129209031197714 | 73481599973842 | 0.85, 1.21, 0.90 | offset 0.000, -0.005, -0.460 |
| inf_v2_runner_lower_arm | 122188743008383 | 128171892615453 | 0.74, 1.71, 0.74 | offset 0.000, -0.295, -0.450 |
| inf_v2_runner_hand | 97826414704368 | 71308604138601 | 0.90, 1.01, 0.60 | offset 0.000, -0.925, -0.410 |
| inf_v2_runner_upper_leg | 97805557700329 | 113349210045929 | 0.92, 1.42, 1.07 | offset 0.000, -0.030, -0.071 |
| inf_v2_runner_lower_leg | 106415508101028 | 136872799475575 | 0.96, 1.30, 0.96 | offset 0.000, 0.000, 0.000 |
| inf_v2_runner_foot | 121298677483978 | 130478122650452 | 1.01, 0.33, 1.15 | offset 0.000, 0.008, 0.075 |
| inf_v2_brute_head | 76553837381211 | 124944684847008 | 1.44, 1.32, 1.33 | offset 0.048, -0.410, -0.125 |
| inf_v2_brute_upper_torso | 124063376133641 | 84883874929036 | 3.29, 3.40, 1.91 | offset 0.064, 0.714, 0.094 |
| inf_v2_brute_lower_torso | 77149886757059 | 82148222597340 | 2.40, 1.00, 1.28 | offset 0.000, -0.300, -0.040 |
| inf_v2_brute_upper_arm_l | 76176836206722 | 117557196527847 | 0.86, 1.26, 0.82 | offset -0.420, 0.010, -0.001 |
| inf_v2_brute_upper_arm_r | 124758308397002 | 92652226470288 | 0.92, 1.26, 0.82 | offset 0.450, 0.010, -0.001 |
| inf_v2_brute_lower_arm_l | 79780586870672 | 129436091872291 | 1.19, 2.12, 1.06 | offset -0.515, -0.500, -0.032 |
| inf_v2_brute_lower_arm_r | 131988248316791 | 114771819295336 | 1.48, 2.12, 1.34 | offset 0.586, -0.500, 0.000 |
| inf_v2_brute_hand_l | 96571432842893 | 129139231347890 | 0.98, 0.53, 1.05 | offset -0.420, -1.145, -0.035 |
| inf_v2_brute_hand_r | 109046248505404 | 76989621475430 | 1.36, 0.81, 1.27 | offset 0.420, -1.255, -0.045 |
| inf_v2_brute_upper_leg | 76191672765321 | 131707543727441 | 1.04, 1.49, 1.13 | offset 0.030, -0.065, -0.076 |
| inf_v2_brute_lower_leg | 86489818051367 | 112332897571268 | 1.04, 1.32, 1.07 | offset 0.000, 0.010, -0.025 |
| inf_v2_brute_foot | 130043563819891 | 71201311804512 | 1.01, 0.36, 1.07 | offset 0.000, 0.027, -0.035 |
| inf_v2_hocker_head | 140161122857322 | 97478838411507 | 1.84, 1.56, 1.90 | offset 0.000, -0.011, 0.174 |
| inf_v2_hocker_upper_torso | 138173749193214 | 109159537121829 | 2.16, 2.23, 1.59 | offset 0.000, 0.265, 0.104 |
| inf_v2_hocker_lower_torso | 116673965788066 | 112474680238891 | 2.05, 1.51, 1.53 | offset 0.000, -0.535, 0.036 |
| inf_v2_hocker_upper_arm | 103111103864201 | 97101204999702 | 0.83, 1.23, 0.83 | offset 0.000, -0.015, 0.000 |
| inf_v2_hocker_lower_arm | 110555669059770 | 76786357304301 | 0.70, 1.10, 0.71 | offset 0.000, -0.010, -0.004 |
| inf_v2_hocker_hand | 117772985136475 | 125282456998603 | 0.90, 0.60, 1.17 | offset 0.000, -0.129, -0.093 |
| inf_v2_hocker_upper_leg | 84470153407726 | 140112367072665 | 0.89, 1.52, 1.23 | offset 0.000, 0.012, -0.235 |
| inf_v2_hocker_lower_leg | 105574227113144 | 84270922535712 | 0.99, 1.38, 1.11 | offset 0.000, -0.093, -0.074 |
| inf_v2_hocker_foot | 89851504280755 | 80020769461600 | 1.01, 0.31, 1.00 | offset 0.000, 0.000, 0.000 |
| inf_warden_head | 114272288507850 | 137776244732745 | 1.03, 1.20, 1.10 | offset 0.015, 0.050, -0.050 |
| inf_warden_upper_torso | 129465433234843 | 111029482210404 | 1.94, 2.60, 1.52 | offset 0.000, 0.450, 0.000 |
| inf_warden_lower_torso | 95229929171070 | 122177919361179 | 2.24, 1.12, 1.09 | offset -0.011, -0.350, -0.065 |
| inf_warden_upper_arm_l | 90178215038369 | 121014183188168 | 0.92, 1.27, 0.92 | sided; offset 0.000, -0.015, 0.000 |
| inf_warden_upper_arm_r | 114663756538931 | 76432220093143 | 0.91, 1.32, 0.93 | sided; offset 0.013, -0.040, 0.023 |
| inf_warden_lower_arm_l | 109428525195459 | 103450056135438 | 0.96, 1.21, 0.96 | sided, wrist grown to the shield handle; offset 0.000, -0.025, 0.000 |
| inf_warden_lower_arm_r | 108686202348825 | 87978240518037 | 1.20, 1.17, 1.06 | sided; offset 0.081, -0.025, -0.012 |
| inf_warden_hand_l | 87995320009567 | 138361026663887 | 0.90, 0.36, 0.70 | sided; offset 0.000, 0.000, 0.100 |
| inf_warden_hand_r | 118060365841446 | 87200468963000 | 1.10, 0.44, 1.12 | sided; offset 0.000, 0.000, -0.040 |
| inf_warden_upper_leg | 110518444449837 | 136268599288059 | 0.85, 1.43, 1.00 | offset 0.000, -0.035, -0.078 |
| inf_warden_lower_leg | 83521572303302 | 136245909527183 | 0.86, 1.30, 1.01 | offset 0.000, 0.000, -0.075 |
| inf_warden_foot | 108286072751669 | 132546098095942 | 1.05, 0.34, 1.08 | offset 0.000, 0.020, -0.010 |
| inf_warden_plate_helmet | 131116560609697 | 109284303024409 | 1.44, 1.46, 2.20 | plate welded to Head, offset 0.019, 0.060, 0.250 |
| inf_warden_plate_chest | 126497846796573 | 105012452580269 | 1.56, 1.56, 0.59 | plate welded to UpperTorso, offset 0.000, -0.010, -0.755 |
| inf_warden_plate_back | 93038447341544 | 91772239198090 | 1.59, 2.72, 0.57 | plate welded to UpperTorso, offset -0.015, 0.590, 0.745 |
| inf_warden_plate_shoulder_l | 78932474946165 | 97144883804954 | 1.66, 1.06, 1.66 | plate welded to LeftUpperArm, offset 0.000, 0.280, 0.000 |
| inf_warden_plate_shoulder_r | 94157814542903 | 118728353896085 | 1.11, 0.30, 1.11 | plate welded to RightUpperArm, offset 0.000, 0.480, 0.000 |
| inf_warden_plate_shield | 126685145123461 | 102529640193242 | 0.48 x 2.28 x 4.28 | plate strapped along the outer forearm (face -X), offset (-0.67, -0.2, 0.3) |
| pc_assault_head | 113120416771558 | 108816968954550 | 1.34, 1.24, 1.54 | offset 0.000, 0.030, -0.060 |
| pc_assault_upper_torso | 109606627346841 | 101027325915224 | 1.94, 1.70, 1.51 | offset 0.000, 0.000, -0.025 |
| pc_assault_lower_torso | 130324769107274 | 103310952242998 | 2.01, 0.40, 1.12 | offset 0.000, 0.000, -0.050 |
| pc_assault_upper_arm | 137615567202319 | 129827927152847 | 1.04, 1.44, 1.10 | offset 0.000, -0.098, -0.030 |
| pc_assault_lower_arm | 135982743004456 | 114217511098805 | 1.00, 1.12, 1.00 | offset 0.000, 0.000, 0.000 |
| pc_assault_hand | 78025074389286 | 102964661396130 | 0.82, 0.33, 0.88 | offset 0.000, 0.000, -0.010 |
| pc_assault_upper_leg | 96325067678523 | 114031815727891 | 1.08, 1.59, 1.09 | offset 0.043, -0.115, -0.058 |
| pc_assault_lower_leg | 131875477288797 | 108866156558305 | 1.01, 1.30, 0.99 | offset 0.000, 0.000, 0.000 |
| pc_assault_foot | 79144855233866 | 112575972731289 | 1.01, 0.31, 1.00 | offset 0.000, 0.000, 0.000 |
| pc_assault_skinned (skin) | 106205735830249 | 87236345847400 | 3.98, 5.45, 1.26 | switched off (`Config.Player.SkinnedBody`); `MeshAssets.SKINNED_BODIES.body` loads the model id |
| pc_assault_skinned_parts (hidden rig) | 15 meshes | 89768415142935 | R15 boxes | switched off; `SKINNED_BODIES.parts` |
| pc_assault_gear_helmet | 106002887456604 | 115206275662165 | 1.34, 1.11, 1.54 | rigid gear for the skinned body, on Head, offset 0.000, 0.095, -0.060 |
| pc_assault_gear_carrier | 136938794151000 | 103203928656779 | 1.53, 1.44, 1.51 | rigid gear for the skinned body, on UpperTorso, offset -0.025, 0.120, -0.025 |
| env_bus | 132803646952127 | 113262814642765 | 42.9 x 12.75 x 10.9 | solid; the Gate bus line |

Open Cloud imports the FBX at 100x (1 Blender unit → 100 studs) and clamps any axis to 2048,
so the imported size is meaningless; `MeshAssets.luau` sets the intended stud size (Blender
dimensions X, Z, Y) and the MeshPart scales the mesh to it.
