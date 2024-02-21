class RscTitles {
    class GUI {
        idd = 5000;
        movingenable = false;
        enableSimulation = true;
        duration = 999999;
        fadein = 0;
        fadeout = 0;
        onLoad = "uiNamespace setVariable [ ""GUI"", _this select 0 ]";
        class controlsBackground {
            class RscFrame_1 : RscFrame {
                idc = 1;
                style = 96;
                x = 0.464 * safezoneW + safezoneX;
                y = 0.00500001 * safezoneH + safezoneY;
                w = 0.020625 * safezoneW;
                h = 0.033 * safezoneH;
            };
            class RscFrame_2 : RscFrame {
                idc = 2;
                style = 96;
                x = 0.515375 * safezoneW + safezoneX;
                y = 0.00500001 * safezoneH + safezoneY;
                w = 0.020625 * safezoneW;
                h = 0.033 * safezoneH;
            };
            class RscFrame_3 : RscFrame {
                idc = 3;
                style = 96;
                x = 0.484531 * safezoneW + safezoneX;
                y = 0.00500001 * safezoneH + safezoneY;
                w = 0.0309375 * safezoneW;
                h = 0.033 * safezoneH;
            };
            class RscFrame_4 : RscFrame {
                idc = 4;
                style = 96;
                x = safeZoneX + (0.5 * safeZoneW) - (0.5 * 0.12375 * safezoneW);
                y = 0.962 * safezoneH + safezoneY;
                w = 0.12375 * safezoneW;
                h = 0.022 * safezoneH;
            };
            class westTickets : RscStructuredText {
                idc = 1100;
                text = "0";
                x = 0.464 * safezoneW + safezoneX;
                y = 0.00500001 * safezoneH + safezoneY;
                w = 0.020625 * safezoneW;
                h = 0.033 * safezoneH;
                colorBackground[] = {0, 0.4, 0.7, 0.85};
            };
            class eastTickets : RscStructuredText {
                idc = 1102;
                text = "0";
                x = 0.515375 * safezoneW + safezoneX;
                y = 0.00500001 * safezoneH + safezoneY;
                w = 0.020625 * safezoneW;
                h = 0.033 * safezoneH;
                colorText[] = {1, 1, 1, 1};
                colorBackground[] = {0.7, 0, 0, 0.65};
            };
            class timer : RscStructuredText {
                idc = 1101;
                text = "0:00";
                x = 0.484531 * safezoneW + safezoneX;
                y = 0.00500001 * safezoneH + safezoneY;
                w = 0.0309375 * safezoneW;
                h = 0.033 * safezoneH;
                colorBackground[] = {0.1, 0.1, 0.1, 1};
            };
            class westPlayerCount : RscStructuredText {
                idc = 1000;
                text = "0";
                x = 0.482288 * safezoneW + safezoneX;
                y = 0.038 * safezoneH + safezoneY;
                w = 0.0103125 * safezoneW;
                h = 0.022 * safezoneH;
                colorText[] = {1, 1, 1, 1};
                colorBackground[] = {0.4, 0.4, 0.4, 1};
            };
            class eastPlayerCount : RscStructuredText {
                idc = 1001;
                text = "0";
                x = 0.5078 * safezoneW + safezoneX;
                y = 0.038 * safezoneH + safezoneY;
                w = 0.0103125 * safezoneW;
                h = 0.022 * safezoneH;
                colorText[] = {1, 1, 1, 1};
                colorBackground[] = {0.4, 0.4, 0.4, 1};
            };
            class vs : RscStructuredText {
                idc = 1002;
                text = "VS";
                x = 0.4926 * safezoneW + safezoneX;
                y = 0.038 * safezoneH + safezoneY;
                w = 0.0154688 * safezoneW;
                h = 0.022 * safezoneH;
                sizeEx = 0.035;
                colorText[] = {1, 1, 1, 1};
                colorBackground[] = {0.1, 0.1, 0.1, 1};
            };
            class hpBackground : RscStructuredText {
                idc = 1200;
                x = safeZoneX + (0.5 * safeZoneW) - (0.5 * 0.12375 * safezoneW);
                y = 0.962 * safezoneH + safezoneY;
                w = 0.12375 * safezoneW;
                h = 0.022 * safezoneH;
                colorBackground[] = {0, 0.8, 0, 0.7};
            };
            class hpText : RscStructuredText {
                idc = 1201;
                text = "0 HP";
                x = safeZoneX + (0.5 * safeZoneW) - (0.5 * 0.12375 * safezoneW);
                y = 0.962 * safezoneH + safezoneY;
                w = 0.12375 * safezoneW;
                h = 0.022 * safezoneH;
                colorBackground[] = {0, 0, 0, 0};
            };
        };
    };
};