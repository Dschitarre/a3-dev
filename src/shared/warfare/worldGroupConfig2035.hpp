// World-group specific settings. Variant config: the build replaces SC\worldGroupConfig.hpp
// by worldGroupConfig<mapGroup>.hpp or worldGroupConfig<map>.hpp, listed in cfg/variantConfigs.txt.
// Arrays indexed by side use the order of SC_var_sides: west, east, independent.
class SC_worldGroupConfig {
    name = "2035";                  // key for profile data (loadouts, statistics, perks)
    filterDlcItems = 1;             // drop *_lxws / *_rf / ef_* config entries when the DLC is not loaded
    oneTimeLaunchers = 0;           // re-add single-use launchers after firing
    classPrefixLength = 0;          // prefix skipped when grouping weapons by base name
    usesCupClasses = 0;             // statistics show only sources with (1) / without (0) the "CUP_" prefix
    uavTerminals[] = {"B_UavTerminal", "O_UavTerminal", "I_UavTerminal"};
    defaultNvgs[] = {"NVGoggles", "NVGoggles_OPFOR", "NVGoggles_INDEP"};

    // AI equipment filters: {prefixes (case-insensitive)}, {substrings}, {excluded substrings}
    // a class matches if it has one of the prefixes or contains one of the substrings, and contains no excluded substring
    aiUniformFilter[] = {{"U_"}, {}, {"Wetsuit", "Viper"}};
    aiVestFilter[] = {{"V_"}, {"vest"}, {"Rebreather"}};
    aiHelmetFilter[] = {{"H_"}, {"helmet"}, {"Viper", "H_PilotHelmetFighter_"}};
    aiAccessoryFilter[] = {{"acc_"}, {}, {}};

    baseLoadouts[] = {
        {{},{},{},{"U_B_CombatUniform_mcam",{{"HandGrenade",2,1}}},{"V_TacVest_khk",{}},{"B_AssaultPack_mcamo",{}},"H_HelmetB_light_sand","",{"","","","",{},{},""},{"ItemMap","B_UavTerminal","","ItemCompass","ItemWatch","NVGoggles"}},
        {{},{},{},{"U_O_CombatUniform_ocamo",{{"HandGrenade",2,1}}},{"V_TacVest_brn",{}},{"B_AssaultPack_ocamo",{}},"H_HelmetO_ocamo","",{"","","","",{},{},""},{"ItemMap","O_UavTerminal","","ItemCompass","ItemWatch","NVGoggles_OPFOR"}},
        {{},{},{},{"U_I_CombatUniform",{{"HandGrenade",2,1}}},{"V_TacVest_camo",{}},{"B_AssaultPack_dgtl",{}},"H_HelmetIA","",{"","","","",{},{},""},{"ItemMap","I_UavTerminal","","ItemCompass","ItemWatch","NVGoggles_INDEP"}}
    };

    // ammo that deals the reduced "vehicleDamage" param damage to vehicles
    launcherAmmos[] = {
        "B_35mm_AA_Tracer_Yellow", "M_Jian_AT", "Gatling_30mm_HE_Plane_CAS_01_F", "B_20mm",
        "B_30mm_HE_Tracer_Red", "Sh_125mm_APFSDS_T_Green", "B_30mm_MP_Tracer_Green", "ammo_ShipCannon_120mm_HE",
        "Sh_120mm_HEAT_MP_T_Red", "R_80mm_HE", "M_Air_AA_MI06", "Sh_105mm_APFSDS_T_Yellow",
        "G_40mm_HE", "Sh_82mm_AMOS_guided", "R_230mm_fly", "Sh_105mm_HEAT_MP",
        "Sh_125mm_HEAT_T_Yellow", "ammo_ShipCannon_120mm_HE_cluster", "Sh_125mm_HE_T_Green", "M_127mm_Firefist_AT",
        "R_MRAAWS_HEAT55_F", "Bomb_04_F", "Sh_125mm_HEAT_T_Red", "Sh_82mm_AMOS",
        "B_35mm_AA", "Sh_155mm_AMOS_LG", "B_30mm_APFSDS_Tracer_Green", "G_20mm_HE",
        "Sh_120mm_HE", "Missile_AA_03_F", "M_PGM_AT", "Bo_Mk82_MI08",
        "ammo_ShipCannon_120mm_HE_LG", "B_30mm_APFSDS_Tracer_Red", "Sh_120mm_APFSDS_Tracer_Yellow", "Bo_Mk82",
        "ammo_Missile_AMRAAM_D", "B_30mm_HE_Tracer_Green", "Sh_125mm_APFSDS_T_Red", "Rocket_03_HE_F",
        "M_Titan_AT_long", "Bo_GBU12_LGB", "R_MRAAWS_HEAT_F", "Missile_AA_04_F",
        "M_Vorona_HE", "M_RIM_7", "Sh_120mm_HEAT_MP_T_Yellow", "B_40mm_GPR_Tracer_Red",
        "Sh_120mm_HEAT_MP", "M_Scalpel_AT", "Sh_75mm_Railgun_APFSDS", "ammo_Penetrator_120mm",
        "M_Mo_155mm_AT", "Sh_120mm_APFSDS_Tracer_Red", "ammo_Missile_s750", "Sh_120mm_APFSDS_Tracer_Green",
        "Rocket_04_HE_F", "Sh_155mm_AMOS", "R_230mm_Cluster", "Sh_125mm_APFSDS",
        "ammo_Missile_AA_R73", "Rocket_04_AP_F", "ammo_ShipCannon_120mm_HE_guided", "G_40mm_HEDP",
        "B_35mm_AA_Tracer_Green", "Sh_125mm_HEAT_T_Green", "ammo_Penetrator_Titan_AT", "Sh_120mm_APFSDS",
        "ammo_Missile_rim116", "R_PG32V_F", "M_125mm_cannon_ATGM", "Sh_120mm_HE_Tracer_Red",
        "M_SPG9_HE", "M_AT", "B_30mm_HE", "M_Titan_AA_long",
        "M_RIM_116", "Sh_155mm_AMOS_guided", "M_Titan_AP", "B_35mm_AA_Tracer_Red",
        "B_30mm_MP_Tracer_Red", "Sh_125mm_APFSDS_T_Yellow", "M_Air_AA", "Cannon_30mm_HE_Plane_CAS_02_F",
        "B_40mm_APFSDS_Tracer_Red", "Sh_125mm_HE", "ammo_Missile_rim162", "M_70mm_SAAMI",
        "B_20mm_Tracer_Green", "Missile_AGM_02_F", "R_TBG32V_F", "Sh_105mm_HEAT_MP_T_Green",
        "Sh_105mm_APFSDS_T_Red", "M_Titan_AA", "R_230mm_HE", "M_120mm_cannon_ATGM_LG",
        "ammo_Missile_AA_R77", "B_25mm", "R_PG7_F", "M_PG_AT",
        "M_Mo_155mm_AT_LG", "Missile_AGM_01_F", "ammo_Missile_AMRAAM_C", "Cluster_155mm_AMOS",
        "ammo_Missile_mim145", "Sh_125mm_HE_T_Yellow", "Sh_120mm_HE_Tracer_Green", "ammo_ShipCannon_120mm_mine",
        "M_Titan_AA_static", "M_Air_AA_MI02", "Sh_82mm_AMOS_LG", "Sh_120mm_HE_Tracer_Yellow",
        "B_30mm_MP_Tracer_Yellow", "M_NLAW_AT_F", "ammo_Missile_BIM9X", "ammo_Bomb_SDB",
        "M_Titan_AT", "M_120mm_cannon_ATGM", "Bomb_03_F", "Sh_120mm_HEAT_MP_T_Green",
        "Sh_105mm_APFSDS", "Sh_105mm_HEAT_MP_T_Yellow", "B_30mm_APFSDS_Tracer_Yellow", "M_Vorona_HEAT",
        "B_20mm_Tracer_Yellow", "M_SPG9_HEAT", "ammo_Missile_KH58", "M_Zephyr",
        "ammo_Penetrator_120mm_missile", "Sh_125mm_HEAT", "Sh_105mm_APFSDS_T_Green", "Rocket_03_AP_F",
        "R_MRAAWS_HE_F", "B_20mm_Tracer_Red", "M_Titan_AT_static", "Sh_105mm_HEAT_MP_T_Red",
        "Sh_125mm_HE_T_Red"
    };
};
