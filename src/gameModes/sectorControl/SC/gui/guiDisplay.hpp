class sectorControlDisplay {
    idd = 5000;
    movingenable = false;
    enableSimulation = true;
    duration = 999999;
    fadein = 0;
    fadeout = 0;
    onLoad = "uiNamespace setVariable [""SC_var_sectorControlDisplay"", _this select 0]";
    class ControlsBackground {
        // GROUP HP BARS

        class groupHpBar0 : RscStructuredText {
            idc = 4350;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.35, 0.35, 0.35, 0.6};
        };
        class groupHpBar1 : RscStructuredText {
            idc = 4350;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.35, 0.35, 0.35, 0.6};
        };
        class groupHpBar2 : RscStructuredText {
            idc = 4351;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.35, 0.35, 0.35, 0.6};
        };
        class groupHpBar3 : RscStructuredText {
            idc = 4352;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.35, 0.35, 0.35, 0.6};
        };
        class groupHpBar4 : RscStructuredText {
            idc = 4353;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.35, 0.35, 0.35, 0.6};
        };

        class rankText : RscStructuredText {
            idc = 1005;
            text = "Lvl: 1";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {1, 0.5, 0, 0.7};
        };
        class xpBackground : RscStructuredText {
            idc = 998;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.75, 0.75, 0.75, 0.7};
        };
        class xpText : RscStructuredText {
            idc = 1000;
            text = "XP: 0/600";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
        };
        class hpBackround : RscStructuredText {
            idc = 999;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0.8, 0, 0.7};
        };
        class hpText : RscStructuredText {
            idc = 1001;
            text = "HP: 0";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
        };
        class bluforScoreText : RscStructuredText {
            idc = 1002;
            text = "0";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0.4, 0.7, 0.85};
            SizeEx = 0.03915;
        };
        class opforScoreText : RscStructuredText {
            idc = 1003;
            text = "0";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.7, 0, 0, 0.85};
            SizeEx = 0.03915;
        };
        class independentScoreText : RscStructuredText {
            idc = 1004;
            text = "0";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0.6, 0.3, 0.85};
            SizeEx = 0.03915;
        };
        class staminaBackround : RscStructuredText {
            idc = 5005;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {1, 0.9, 0, 0.7};
            SizeEx = 0.03915;
        };
        class staminaText : RscStructuredText {
            idc = 5006;
            text = "Stamina";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };

        // unit/vehicle count backgrounds

        class numEntitiesBackgroundWest : RscStructuredText {
            idc = 2000;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.2, 0.2, 0.2, 0.4};
            SizeEx = 0.03915;
        };
        class numEntitiesBackgroundEast : RscStructuredText {
            idc = 2001;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.2, 0.2, 0.2, 0.4};
            SizeEx = 0.03915;
        };
        class numEntitiesBackgroundGuer : RscStructuredText {
            idc = 2002;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.2, 0.2, 0.2, 0.4};
            SizeEx = 0.03915;
        };

        // perks

        class perk1Text : RscStructuredText {
            idc = 6001;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.25, 0.25, 0.25, 0.7};
            SizeEx = 0.03;
        };
        class perk2Text : RscStructuredText {
            idc = 6002;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.25, 0.25, 0.25, 0.7};
            SizeEx = 0.03;
        };
        class perk3Text : RscStructuredText {
            idc = 6003;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.25, 0.25, 0.25, 0.7};
            SizeEx = 0.03;
        };
        class perk4Text : RscStructuredText {
            idc = 6004;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.25, 0.25, 0.25, 0.7};
            SizeEx = 0.03;
        };
        class perk5Text : RscStructuredText {
            idc = 6005;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.25, 0.25, 0.25, 0.7};
            SizeEx = 0.03;
        };
        class perk6Text : RscStructuredText {
            idc = 6006;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0.25, 0.25, 0.25, 0.7};
            SizeEx = 0.03;
        };

        // unit count texts

        class numUnitsTextWest : RscStructuredText {
            idc = 2003;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class numUnitsTextEast : RscStructuredText {
            idc = 2004;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class numUnitsTextGuer : RscStructuredText {
            idc = 2005;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };

        // vehicle count texts

        class numVehiclesTextWest : RscStructuredText {
            idc = 2006;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class numVehiclesTextEast : RscStructuredText {
            idc = 2007;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class numVehiclesTextGuer : RscStructuredText {
            idc = 2008;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };

        // unit icons

        class unitIconWest : RscPicture {
            idc = 2009;
            text = "\A3\Ui_f\data\GUI\Rsc\RscDisplayMain\profile_player_ca.paa";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class unitIconEast : RscPicture {
            idc = 2010;
            text = "\A3\Ui_f\data\GUI\Rsc\RscDisplayMain\profile_player_ca.paa";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class unitIconGuer : RscPicture {
            idc = 2011;
            text = "\A3\Ui_f\data\GUI\Rsc\RscDisplayMain\profile_player_ca.paa";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };

        // vehicle icons

        class vehicleIconWest : RscPicture {
            idc = 2012;
            text = "\A3\Ui_f\data\GUI\Rsc\RscDisplayGarage\car_ca.paa";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class vehicleIconEast : RscPicture {
            idc = 2013;
            text = "\A3\Ui_f\data\GUI\Rsc\RscDisplayGarage\car_ca.paa";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class vehicleIconGuer : RscPicture {
            idc = 2014;
            text = "\A3\Ui_f\data\GUI\Rsc\RscDisplayGarage\car_ca.paa";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };

        // GROUP ICONS

        class groupIcon0 : RscPicture {
            idc = 2150;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class groupIcon1 : RscPicture {
            idc = 2151;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class groupIcon2 : RscPicture {
            idc = 2152;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class groupIcon3 : RscPicture {
            idc = 2153;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class groupIcon4 : RscPicture {
            idc = 2154;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };

        // UPPER Transparent

        class sectorAUpperColor : RscStructuredText {
            idc = 1020;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorBUpperColor : RscStructuredText {
            idc = 1021;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorCUpperColor : RscStructuredText {
            idc = 1022;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorDUpperColor : RscStructuredText {
            idc = 1023;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorEUpperColor : RscStructuredText {
            idc = 1024;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorFUpperColor : RscStructuredText {
            idc = 1025;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorGUpperColor : RscStructuredText {
            idc = 1026;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorHUpperColor : RscStructuredText {
            idc = 1027;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorIUpperColor : RscStructuredText {
            idc = 1028;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorJUpperColor : RscStructuredText {
            idc = 1029;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorKUpperColor : RscStructuredText {
            idc = 1030;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorLUpperColor : RscStructuredText {
            idc = 1031;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorMUpperColor : RscStructuredText {
            idc = 1032;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorNUpperColor : RscStructuredText {
            idc = 1033;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorOUpperColor : RscStructuredText {
            idc = 1034;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorPUpperColor : RscStructuredText {
            idc = 1035;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorQUpperColor : RscStructuredText {
            idc = 1036;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorRUpperColor : RscStructuredText {
            idc = 1037;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorSUpperColor : RscStructuredText {
            idc = 1038;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorTUpperColor : RscStructuredText {
            idc = 1039;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };

        // LOWER COLORS

        class sectorALowerColor : RscStructuredText {
            idc = 8030;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorBLowerColor : RscStructuredText {
            idc = 8031;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorCLowerColor : RscStructuredText {
            idc = 8032;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorDLowerColor : RscStructuredText {
            idc = 8033;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorELowerColor : RscStructuredText {
            idc = 8034;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorFLowerColor : RscStructuredText {
            idc = 8035;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorGLowerColor : RscStructuredText {
            idc = 8036;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorHLowerColor : RscStructuredText {
            idc = 8037;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorILowerColor : RscStructuredText {
            idc = 8038;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorJLowerColor : RscStructuredText {
            idc = 8039;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorKLowerColor : RscStructuredText {
            idc = 8040;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorLLowerColor : RscStructuredText {
            idc = 8041;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorMLowerColor : RscStructuredText {
            idc = 8042;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorNLowerColor : RscStructuredText {
            idc = 8043;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorOLowerColor : RscStructuredText {
            idc = 8044;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorPLowerColor : RscStructuredText {
            idc = 8045;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorQLowerColor : RscStructuredText {
            idc = 8046;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorRLowerColor : RscStructuredText {
            idc = 8047;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorSLowerColor : RscStructuredText {
            idc = 8048;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };
        class sectorTLowerColor : RscStructuredText {
            idc = 8049;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0.35};
            SizeEx = 0.03915;
        };

        //SECTORTEXTS

        class sectorAText : RscStructuredText {
            idc = 3040;
            text = "A";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorBText : RscStructuredText {
            idc = 3041;
            text = "B";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorCText : RscStructuredText {
            idc = 3042;
            text = "C";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorDText : RscStructuredText {
            idc = 3043;
            text = "D";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorEText : RscStructuredText {
            idc = 3044;
            text = "E";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorFText : RscStructuredText {
            idc = 3045;
            text = "F";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorGText : RscStructuredText {
            idc = 3046;
            text = "G";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorHText : RscStructuredText {
            idc = 3047;
            text = "H";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorIText : RscStructuredText {
            idc = 3048;
            text = "I";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorJText : RscStructuredText {
            idc = 3049;
            text = "J";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorKText : RscStructuredText {
            idc = 3050;
            text = "K";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorLText : RscStructuredText {
            idc = 3051;
            text = "L";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorMText : RscStructuredText {
            idc = 3052;
            text = "M";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorNText : RscStructuredText {
            idc = 3053;
            text = "N";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorOText : RscStructuredText {
            idc = 3054;
            text = "O";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorPText : RscStructuredText {
            idc = 3055;
            text = "P";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorQText : RscStructuredText {
            idc = 3056;
            text = "Q";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorRText : RscStructuredText {
            idc = 3057;
            text = "R";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorSText : RscStructuredText {
            idc = 3058;
            text = "S";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };
        class sectorTText : RscStructuredText {
            idc = 3059;
            text = "T";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorBackground[] = {0, 0, 0, 0};
            SizeEx = 0.03915;
        };

        // GROUP TEXTS/BACKGROUNDS

        class groupText1 : RscStructuredText {
            idc = 4058;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            SizeEx = 0.03915;
        };
        class groupText2 : RscStructuredText {
            idc = 4059;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            SizeEx = 0.03915;
        };
        class groupText3 : RscStructuredText {
            idc = 4060;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            SizeEx = 0.03915;
        };
        class groupText4 : RscStructuredText {
            idc = 4061;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            SizeEx = 0.03915;
        };
        class groupText5 : RscStructuredText {
            idc = 4062;
            text = "";
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
            colorText[] = {1, 1, 1, 1};
            SizeEx = 0.03915;
        };

        // FRAMES

        class RscFrame_1800 : RscFrame {
            idc = 1800;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1801 : RscFrame {
            idc = 1801;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1802 : RscFrame {
            idc = 1802;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1803 : RscFrame {
            idc = 1803;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1804 : RscFrame {
            idc = 1804;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1805 : RscFrame {
            idc = 1805;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        
        class RscFrame_1807 : RscFrame {
            idc = 1807;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1808 : RscFrame {
            idc = 1808;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1809 : RscFrame {
            idc = 1809;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1810 : RscFrame {
            idc = 1810;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1811 : RscFrame {
            idc = 1811;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1812 : RscFrame {
            idc = 1812;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1813 : RscFrame {
            idc = 1813;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1814 : RscFrame {
            idc = 1814;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1815 : RscFrame {
            idc = 1815;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1816 : RscFrame {
            idc = 1816;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1817 : RscFrame {
            idc = 1817;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1818 : RscFrame {
            idc = 1818;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1819 : RscFrame {
            idc = 1819;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1820 : RscFrame {
            idc = 1820;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1821 : RscFrame {
            idc = 1821;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1822 : RscFrame {
            idc = 1822;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1823 : RscFrame {
            idc = 1823;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1824 : RscFrame {
            idc = 1824;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1825 : RscFrame {
            idc = 1825;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1826 : RscFrame {
            idc = 1826;
            style = 96;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };

        class RscFrame_1910 : RscFrame {
            idc = 1910;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1911 : RscFrame {
            idc = 1911;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1912 : RscFrame {
            idc = 1912;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1913 : RscFrame {
            idc = 1913;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1914 : RscFrame {
            idc = 1914;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1915 : RscFrame {
            idc = 1915;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1916 : RscFrame {
            idc = 1916;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1917 : RscFrame {
            idc = 1917;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1918 : RscFrame {
            idc = 1918;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1919 : RscFrame {
            idc = 1919;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1920 : RscFrame {
            idc = 1920;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1921 : RscFrame {
            idc = 1921;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1922 : RscFrame {
            idc = 1922;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1923 : RscFrame {
            idc = 1923;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1924 : RscFrame {
            idc = 1924;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1925 : RscFrame {
            idc = 1925;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1926 : RscFrame {
            idc = 1926;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1927 : RscFrame {
            idc = 1927;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1928 : RscFrame {
            idc = 1928;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1929 : RscFrame {
            idc = 1929;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_5735 : RscFrame {
            idc = 5735;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };

        // PERK FRAMES

        class RscFrame_7001 : RscFrame {
            idc = 7001;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_7002 : RscFrame {
            idc = 7002;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_7003 : RscFrame {
            idc = 7003;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_7004 : RscFrame {
            idc = 7004;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_7005 : RscFrame {
            idc = 7005;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_7006 : RscFrame {
            idc = 7006;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };

        // GROUP FRAMES

        class RscFrame_1930 : RscFrame {
            idc = 1930;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1931 : RscFrame {
            idc = 1931;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1932 : RscFrame {
            idc = 1932;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1933 : RscFrame {
            idc = 1933;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
        class RscFrame_1934 : RscFrame {
            idc = 1934;
            x = safezoneX - safezoneW;
            y = safezoneX - safezoneH;
            w = 0;
            h = 0;
        };
    };
};