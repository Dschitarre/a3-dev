// Training screens: kill sound and score display (derived from the UI_* blocks of ui\ui.hpp).

class CfgSounds {
    sounds[] = {};

    class kill {
        name = "kill";
        sound[] = {"TR\kill.ogg", 1.5, 1};
        titles[] = {0, ""};
    };
};

class RscTitles {
    class ScoreDisplay {
        idd = 5000;
        movingEnable = false;
        enableSimulation = true;
        duration = 999999;
        fadeIn = 0;
        fadeOut = 0;
        onLoad = "uiNamespace setVariable [""ScoreDisplay"", _this select 0]";

        class controlsBackground {
            // top center, set by TR_fnc_onKill
            class score: UI_HudText {
                idc = 1100;
                style = ST_CENTER;
                text = "Score: 0";
                x = UI_X(18);
                y = safeZoneY + UI_H(0.5);
                w = UI_W(4);
                h = UI_H(UI_ROW);
                sizeEx = UI_TEXT;
                colorBackground[] = UI_COLOR_HUD_PANEL;
            };
        };
    };
};
