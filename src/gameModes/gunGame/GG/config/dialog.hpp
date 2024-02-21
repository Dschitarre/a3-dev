class RscTitles {
    class GG_var_GUI {
        idd = 5000;
        movingenable = false;
        enableSimulation = true;
        duration = 999999;
        fadein = 0;
        fadeout = 0;
        onLoad = "uiNamespace setVariable [""GG_var_GUI"",_this select 0]";
        class controlsBackground {
            class RscFrame_4 : RscFrame {
                idc = 4;
                style = 96;
                x = 0.89 * safezoneW + safezoneX;
                y = 0.962 * safezoneH + safezoneY;
                w = 0.1 * safezoneW;
                h = 0.022 * safezoneH;
            };
            class hpBackground : RscStructuredText {
                idc = 1200;
                x = 0.89 * safezoneW + safezoneX;
                y = 0.962 * safezoneH + safezoneY;
                w = 0.1 * safezoneW;
                h = 0.022 * safezoneH;
                colorBackground[] = {0, 0.8, 0, 0.7};
            };
            class hpText : RscStructuredText {
                idc = 1201;
                text = "0 HP";
                x = 0.89 * safezoneW + safezoneX;
                y = 0.962 * safezoneH + safezoneY;
                w = 0.1 * safezoneW;
                h = 0.022 * safezoneH;
                colorBackground[] = {0, 0, 0, 0};
            };
            class killsKd {
                idc = 1002;
                type = 0;
                style = 2;
                text = "";
                x = 0.89 * safezoneW + safezoneX;
                y = 0.895 * safezoneH + safezoneY;
                w = 0.1 * safezoneW;
                h = 0.04 * safezoneH;
                font = "PuristaMedium";
                sizeEx = 0.04;
                colorBackground[] = {0, 0, 0, 0};
                colorText[] = {1, 1, 1, 1};
            };
            class GG_var_deaths {
                idc = 1003;
                type = 0;
                style = 2;
                text = "";
                x = 0.89 * safezoneW + safezoneX;
                y = 0.92 * safezoneH + safezoneY;
                w = 0.1 * safezoneW;
                h = 0.04 * safezoneH;
                font = "PuristaMedium";
                sizeEx = 0.04;
                colorBackground[] = {0, 0, 0, 0};
                colorText[] = {1, 1, 1, 1};
            };
        };
    };
};