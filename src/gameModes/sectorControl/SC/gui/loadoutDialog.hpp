class loadoutDialog {
    idd = 3001;
    movingenable = true;
    enableSimulation = true;
    duration = 999999;
    fadein = 0;
    fadeout = 0;
    onLoad = "uiNamespace setVariable [""SC_var_loadoutDialog"",_this select 0]; call SC_fnc_setupLoadoutDialog;";

    class ControlsBackground {
        class RscText_1000: RscText
        {
            idc = 1000;
            x = 0.4175 * safezoneW + safezoneX;
            y = 0.467 * safezoneH + safezoneY;
            w = 0.165 * safezoneW;
            h = 0.099 * safezoneH;
            colorBackground[] = {0,0,0,0.8};
        };
        class RscText_1001: RscText
        {
            idc = 1001;
            x = 0.4175 * safezoneW + safezoneX;
            y = 0.445 * safezoneH + safezoneY;
            w = 0.165 * safezoneW;
            h = 0.022 * safezoneH;
            colorBackground[] = {0.6,0.6,0,0.8};
        };
        class RscText_1002: RscText
        {
            idc = 1002;
            text = "Load/Store Loadouts";
            x = 0.4175 * safezoneW + safezoneX;
            y = 0.445 * safezoneH + safezoneY;
            w = 0.165 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscCombo_2100: RscCombo
        {
            idc = 2100;
            x = 0.427812 * safezoneW + safezoneX;
            y = 0.522 * safezoneH + safezoneY;
            w = 0.144375 * safezoneW;
            h = 0.022 * safezoneH;
        };
        class RscButton_1600: RscButton
        {
            idc = 1600;
            text = "Load";
            x = 0.432969 * safezoneW + safezoneX;
            y = 0.489 * safezoneH + safezoneY;
            w = 0.0360937 * safezoneW;
            h = 0.022 * safezoneH;
            colorBackground[] = {0.3,0.3,0.3,1};
            onButtonClick = "call SC_fnc_loadLoadout;";
        };
        class RscButton_1601: RscButton
        {
            idc = 1601;
            text = "Store";
            x = 0.482708 * safezoneW + safezoneX;
            y = 0.489 * safezoneH + safezoneY;
            w = 0.0360937 * safezoneW;
            h = 0.022 * safezoneH;
            colorBackground[] = {0.3,0.3,0.3,1};
            onButtonClick = "call SC_fnc_storeLoadout;";
        };
        class RscButton_1602: RscButton
        {
            idc = 1602;
            text = "Delete";
            x = 0.530937 * safezoneW + safezoneX;
            y = 0.489 * safezoneH + safezoneY;
            w = 0.0360937 * safezoneW;
            h = 0.022 * safezoneH;
            colorBackground[] = {0.3,0.3,0.3,1};
            onButtonClick = "call SC_fnc_deleteLoadout;";
        };
    };
};