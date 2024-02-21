class settingsDialog {
    idd = 3000;
    movingenable = true;
    enableSimulation = true;
    duration = 999999;
    fadein = 0;
    fadeout = 0;
    onLoad = "uiNamespace setVariable [""SC_var_settingsDialog"",_this select 0]; call SC_fnc_setupSettingsDialog;";

    class ControlsBackground {
        class RscText_1000: RscText
        {
            idc = 1000;
            x = 0.386562 * safezoneW + safezoneX;
            y = 0.247 * safezoneH + safezoneY;
            w = 0.20625 * safezoneW;
            h = 0.55 * safezoneH;
            colorBackground[] = {0,0,0,0.8};
        };
        class RscText_1001: RscText
        {
            idc = 1001;
            x = 0.386562 * safezoneW + safezoneX;
            y = 0.225 * safezoneH + safezoneY;
            w = 0.20625 * safezoneW;
            h = 0.022 * safezoneH;
            colorBackground[] = {0.6,0.6,0,0.8};
        };
        class RscText_1002: RscText
        {
            idc = 1002;
            text = "Settings";
            x = 0.386562 * safezoneW + safezoneX;
            y = 0.225 * safezoneH + safezoneY;
            w = 0.04125 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1003: RscText
        {
            idc = 1003;
            text = "HUD (press F2 to toggle)";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.258 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscCheckbox_2800: RscCheckbox
        {
            idc = 2800;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.258 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[0] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2801: RscCheckbox
        {
            idc = 2801;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.28 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[1] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2802: RscCheckbox
        {
            idc = 2802;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.302 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[2] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2803: RscCheckbox
        {
            idc = 2803;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.324 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[3] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2804: RscCheckbox
        {
            idc = 2804;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.346 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[4] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2805: RscCheckbox
        {
            idc = 2805;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.368 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[5] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2806: RscCheckbox
        {
            idc = 2806;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.39 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[6] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2807: RscCheckbox
        {
            idc = 2807;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.412 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[7] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2808: RscCheckbox
        {
            idc = 2808;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.434 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[8] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2809: RscCheckbox
        {
            idc = 2809;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.456 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[9] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2810: RscCheckbox
        {
            idc = 2810;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.478 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[10] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2811: RscCheckbox
        {
            idc = 2811;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.5 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[11] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2812: RscCheckbox
        {
            idc = 2812;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.522 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[12] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2813: RscCheckbox
        {
            idc = 2813;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.544 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[13] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2814: RscCheckbox
        {
            idc = 2814;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.566 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[14] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2815: RscCheckbox
        {
            idc = 2815;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.588 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[15] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2816: RscCheckbox
        {
            idc = 2816;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.61 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[16] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2817: RscCheckbox
        {
            idc = 2817;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.632 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[17] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2818: RscCheckbox
        {
            idc = 2818;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.654 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[18] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2819: RscCheckbox
        {
            idc = 2819;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.676 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[19] call SC_fnc_toggleSetting;";
        };
        class RscCheckbox_2820: RscCheckbox
        {
            idc = 2820;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.698 * safezoneH + safezoneY;
            w = 0.0154688 * safezoneW;
            h = 0.028 * safezoneH;
            onCheckedChanged = "[20] call SC_fnc_toggleSetting;";
        };
        class RscSlider_1900: RscSlider
        {
            idc = 1900;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.731 * safezoneH + safezoneY;
            w = 0.108281 * safezoneW;
            h = 0.022 * safezoneH;
            onSliderPosChanged = "[_this select 1] call SC_fnc_setViewDistance";
        };
        class RscSlider_1901: RscSlider
        {
            idc = 1901;
            x = 0.391719 * safezoneW + safezoneX;
            y = 0.764 * safezoneH + safezoneY;
            w = 0.108281 * safezoneW;
            h = 0.022 * safezoneH;
            onSliderPosChanged = "[_this select 1] call SC_fnc_setGrassViewDistance";
        };
        class RscText_1004: RscText
        {
            idc = 1004;
            text = "View Distance";
            x = 0.502083 * safezoneW + safezoneX;
            y = 0.72637 * safezoneH + safezoneY;
            w = 0.0825 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1005: RscText
        {
            idc = 1005;
            text = "Grass View Distance";
            x = 0.501823 * safezoneW + safezoneX;
            y = 0.758333 * safezoneH + safezoneY;
            w = 0.0825 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1006: RscText
        {
            idc = 1006;
            text = "Always show HUD when on map";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.28 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1007: RscText
        {
            idc = 1007;
            text = "Always show HUD when unconscious";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.302 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1008: RscText
        {
            idc = 1008;
            text = "Show all HUD components when on map";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.324 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1009: RscText
        {
            idc = 1009;
            text = "Show all HUD components when unconscious";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.346 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1010: RscText
        {
            idc = 1010;
            text = "Sector overview";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.368 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1011: RscText
        {
            idc = 1011;
            text = "Player stats";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.39 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1012: RscText
        {
            idc = 1012;
            text = "Group overview";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.412 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1013: RscText
        {
            idc = 1013;
            text = "Killfeed";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.434 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1014: RscText
        {
            idc = 1014;
            text = "Midfeed";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.456 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1015: RscText
        {
            idc = 1015;
            text = "Deathfeed";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.478 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1016: RscText
        {
            idc = 1016;
            text = "Unit names below 3D unit icons";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.5 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1017: RscText
        {
            idc = 1017;
            text = "Hide invisible 3D group icons";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.522 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1018: RscText
        {
            idc = 1018;
            text = "Limit 3D group icon draw distance";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.544 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1019: RscText
        {
            idc = 1019;
            text = "Sector 3D icons";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.566 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1020: RscText
        {
            idc = 1020;
            text = "Airdrop 3D icons";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.588 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1021: RscText
        {
            idc = 1021;
            text = "Show unit names on map only when hovered over";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.61 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1022: RscText
        {
            idc = 1022;
            text = "Vehicle-, soldier- and weapon info panels";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.632 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1023: RscText
        {
            idc = 1023;
            text = "Vehicle radar";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.654 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1024: RscText
        {
            idc = 1024;
            text = "Vehicle compass";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.676 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscText_1025: RscText
        {
            idc = 1025;
            text = "GPS-/vehicle panel (press F3 to toggle)";
            x = 0.407187 * safezoneW + safezoneX;
            y = 0.698 * safezoneH + safezoneY;
            w = 0.180469 * safezoneW;
            h = 0.022 * safezoneH;
        };
    };
};