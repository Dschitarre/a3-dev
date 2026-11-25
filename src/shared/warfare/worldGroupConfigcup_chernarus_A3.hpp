// World-group specific settings. Variant config: the build replaces SC\worldGroupConfig.hpp
// by worldGroupConfig<mapGroup>.hpp or worldGroupConfig<map>.hpp, listed in cfg/variantConfigs.txt.
// Arrays indexed by side use the order of SC_var_sides: west, east, independent.
class SC_worldGroupConfig {
    name = "Chernarus";             // key for profile data (loadouts, statistics, perks)
    filterDlcItems = 0;
    oneTimeLaunchers = 1;
    classPrefixLength = 4;
    usesCupClasses = 1;
    uavTerminals[] = {"ItemGPS", "ItemGPS", "ItemGPS"};
    defaultNvgs[] = {"", "", ""};

    aiUniformFilter[] = {{"CUP_U_"}, {}, {}};
    aiVestFilter[] = {{"CUP_V_"}, {}, {}};
    aiHelmetFilter[] = {{"CUP_H_"}, {}, {}};
    aiAccessoryFilter[] = {{"CUP_acc_"}, {}, {}};

    baseLoadouts[] = {
        {{},{},{},{"CUP_U_B_BAF_MTP_UBACSLONG_Gloves",{{"CUP_HandGrenade_M67",2,1}}},{"CUP_V_B_BAF_DPM_Osprey_Mk3_Pilot",{}},{"CUP_B_AssaultPack_Coyote",{}},"CUP_H_USArmy_Helmet_M1_plain_Vine","",{"Binocular","","","",{},{},""},{"ItemMap","ItemGPS","","ItemCompass","ItemWatch","CUP_NVG_PVS15_Hide"}},
        {{},{},{},{"CUP_U_O_RUS_EMR_1",{{"CUP_HandGrenade_RGO",2,1}}},{"CUP_V_CZ_vest15",{}},{"CUP_B_RUS_Backpack",{}},"CUP_H_RUS_SSH68_green","",{"Binocular","","","",{},{},""},{"ItemMap","ItemGPS","","ItemCompass","ItemWatch","CUP_NVG_1PN138_Hide"}},
        {{},{},{},{"CUP_U_I_GUE_Flecktarn",{{"CUP_HandGrenade_L109A1_HE",2,1}}},{"CUP_V_CZ_vest20",{}},{"CUP_B_RUS_Backpack",{}},"CUP_H_SLA_Helmet_DES","",{"Binocular","","","",{},{},""},{"ItemMap","ItemGPS","","ItemCompass","ItemWatch","CUP_NVG_HMNVS_Hide"}}
    };

    launcherAmmos[] = {
        "CUP_B_30x113mm_M789_HEDP_Yellow_Tracer", "CUP_Sh_120mm_DM12A1", "CUP_M_RIM7_Frigate", "CUP_Sh_125mm_3BK29",
        "CUP_Sh_OG15V", "CUP_Sh_105mm_M1040", "CUP_Sh_120mm_M829A3", "CUP_M_Shturm_9M114_AT6_Spiral_AT",
        "CUP_P_KH29L_AT", "CUP_P_MEEWS_HEAT", "CUP_B_30x113mm_M789_HEDP_Green_Tracer", "CUP_B_20mm_API_Tracer_Red",
        "CUP_Bo_KAB250_LGB", "CUP_R_CRV7_C18_HE", "CUP_P_9K115_2_AT13_Saxhorn_2_AT", "CUP_G_40mm_HE",
        "CUP_Sh_120mm_M1028", "CUP_Sh_120mm_DM33", "CUP_R_TOW2_AT", "CUP_M_9M311M_Tunguska_AA",
        "CUP_M_AIM_9L_Sidewinder_AA", "CUP_Sh_125mm_3BK12", "CUP_Sh_3UBK9_HEAT", "CUP_Sh_100mm_M1000A1",
        "CUP_M_RBS70_AA", "CUP_P_APILAS_AT", "CUP_R_CRV7_C15_HE", "CUP_P_3BK29_HEAT",
        "CUP_Mk_82", "CUP_Sh_125mm_3BK31", "CUP_Sh_120mm_M829", "CUP_M_9M119M_Refleks_AT11_Sniper_AT",
        "CUP_Sh_127_HE", "CUP_B_25mm_HE_Red_Tracer", "CUP_M_9M17P_AT2_Falanga_AT", "CUP_AGM84_AT",
        "CUP_Sh_OG9_HE", "CUP_P_3UBK9_HEAT", "CUP_Sh_125mm_3BM42M", "CUP_Sh_100mm_BM25",
        "CUP_Sh_122_HE", "CUP_R_TOW_AT", "CUP_M_AGM_114K_Hellfire_II_AT", "CUP_Sh_120mm_DM63A1",
        "CUP_M_Ataka_V_9M120_AT9_Spiral_2_AT", "CUP_R_PG7V_AT", "CUP_R_PG7VR_AT", "CUP_B_30mm_HEIF_Green_Tracer",
        "CUP_P_Ataka_V_9M120_AT9_Spiral_2_AT", "CUP_P_9K116_1_Bastion_AT10_Stabber_AT", "CUP_P_Javelin_AT", "CUP_Sh_125mm_3OF82",
        "CUP_B_23mm_AA", "CUP_Sh_105mm_M728", "CUP_B_20mm_API_Tracer_Yellow", "CUP_Sh_105mm_M900",
        "CUP_Sh_PG9_AT", "CUP_Sh_120mm_DM13A1", "CUP_B_20mm_AP_Tracer_Yellow", "CUP_R_70mm_Hydra_HE",
        "CUP_P_3BK31_HEAT", "CUP_Sh_UBK367_HEAT", "CUP_Sh_120mm_M830A1", "CUP_R_CRV7_FAT",
        "CUP_AGM65pod_AT", "CUP_Sh_120mm_DM13", "CUP_R_techical_HE", "CUP_B_30mm_CAS_Red_Tracer",
        "CUP_Bo_GBU12_LGB", "CUP_M_9M113_AT5_Spandrel_AT", "CUP_R_CRV7_C18_KEP", "CUP_B_25mm_APFSDS_Red_Tracer",
        "CUP_P_SMAW_HEDP", "CUP_P_DM12A1_HEAT", "CUP_Sh_105_HE", "CUP_Sh_105mm_M393A3",
        "CUP_B_20mm_API_Tracer_Green", "CUP_M_9M38_Igla_AA", "CUP_M_9M17P_AT3_Sagger_AT", "CUP_B_23mm_APHE_Tracer_Red",
        "CUP_B_23mm_APHE_Tracer_Yellow", "CUP_M_9M133_1_AT14_Spriggan_AT", "CUP_B_23mm_APHE_Tracer_Green", "CUP_B_20mm_APHE_Tracer_Green",
        "CUP_Sh_105_WP", "CUP_M_9K121_Vikhr_AT16_Scallion_AT", "CUP_B_25mm_CAS_Red_Tracer", "CUP_Sh_UO367_HEFRAG",
        "CUP_Sh_120mm_M908", "CUP_R_MLRS_DPICM", "CUP_Sh_105mm_M735", "CUP_Sh_100mm_BM8",
        "CUP_Sh_105mm_M833", "CUP_R_CRV7_C15_KEP", "CUP_Sh_120mm_DM11", "CUP_B_30mm_HE_Green_Tracer",
        "CUP_Sh_105mm_M456A1", "CUP_P_AGM_84_AT", "CUP_R_M136_AT", "CUP_M_Stinger_AA",
        "CUP_Sh_125mm_3OF26", "CUP_R_140mm_Ogon_HE", "CUP_Sh_100mm_M309", "CUP_Sh_105mm_M393A1",
        "CUP_R_SMAW_HEDP", "CUP_P_9K121_Vikhr_AT16_Scallion_AT", "CUP_P_MEEWS_HEDP", "CUP_Sh_125mm_3BM69",
        "CUP_Sh_125mm_3BK18", "CUP_Sh_125mm_3OF19", "CUP_M_AGM_114L_Hellfire_II_AT", "CUP_P_9M17P_AT2_Falanga_AT",
        "CUP_P_M1028_Tungsten_Ball", "CUP_P_105mm_M393A3", "CUP_P_AGM_114L_Hellfire_II_AT", "CUP_P_AGM_65D_AT",
        "CUP_B_37mm_Type76_HE", "CUP_Sh_3UOF10_HEFRAG", "CUP_B_30x113mm_M789_HEDP_White_Tracer", "CUP_B_20mm_AP_Tracer_Red",
        "CUP_M_9M311_Tunguska_AA", "CUP_Sh_120mm_M830", "CUP_R_GRAD_HE", "CUP_Sh_125mm_3BM32",
        "CUP_M_KH29L_AT", "CUP_R_SMAW_NE", "CUP_P_120mm_HESH", "CUP_P_M830A1_120mm",
        "CUP_Sh_120mm_DM53", "CUP_Sh_100mm_BR412D", "CUP_B_20mm_APHE_Tracer_Red", "CUP_Sh_120mm_HESH_Tracer_Red",
        "CUP_Sh_105mm_M456A2", "CUP_M_9M133_1_AT14_Spriggan_HE", "CUP_M_9K115_2_AT13_Saxhorn_2_AT", "CUP_M_9K116_1_Bastion_AT10_Stabber_AT",
        "CUP_Sh_105mm_M774", "CUP_Sh_PG15V", "CUP_B_20mm_AP_Tracer_Green", "CUP_Sh_120mm_M829A2",
        "CUP_M_9K32_Strela_2_AA", "CUP_P_UBK367_HEAT"
    };
};
