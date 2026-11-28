// GunGame screens: HUD (RscTitles GG_rscHud) and notifications. Controls derive from the UI_* blocks of ui\ui.hpp.

// ---- HUD ----
// Bottom right, top to bottom: weapon (stage) with progress bar, kills and deaths, K/D and unit count, health bar.
// Sizes in grid cells, anchored to the bottom right corner of the screen.

#define GG_HUD_W            7
#define GG_HUD_ROW_H        0.8
#define GG_HUD_X            (safeZoneX + safeZoneW - UI_W(GG_HUD_W + 0.5))
#define GG_HUD_HEALTH_Y     (safeZoneY + safeZoneH - UI_H(1.5))
#define GG_HUD_RATIO_Y      (GG_HUD_HEALTH_Y - UI_H(GG_HUD_ROW_H + UI_GAP))
#define GG_HUD_KILLS_Y      (GG_HUD_RATIO_Y - UI_H(GG_HUD_ROW_H + UI_GAP))
#define GG_HUD_STAGE_Y      (GG_HUD_KILLS_Y - UI_H(GG_HUD_ROW_H + UI_GAP))

class RscTitles {
    class GG_rscHud {
        idd = 5000;
        movingEnable = false;
        enableSimulation = true;
        duration = 999999;
        fadeIn = 0;
        fadeOut = 0;
        onLoad = "uiNamespace setVariable [""GG_rscHud"", _this select 0]";

        class controlsBackground {
            class healthPanel: UI_HudPanel {
                idc = 4;
                x = GG_HUD_X;
                y = GG_HUD_HEALTH_Y;
                w = UI_W(GG_HUD_W);
                h = UI_H(GG_HUD_ROW_H);
            };
            // health fill in green (the only green bar); GG_fnc_guiLoop scales its width (full = 100 HP)
            class hpBackground: UI_HudPanel {
                idc = 1200;
                x = GG_HUD_X;
                y = GG_HUD_HEALTH_Y;
                w = UI_W(GG_HUD_W);
                h = UI_H(GG_HUD_ROW_H);
                colorBackground[] = UI_COLOR_HEALTH;
            };
            class hpText: UI_HudText {
                idc = 1201;
                style = ST_CENTER;
                text = "0 HP";
                x = GG_HUD_X;
                y = GG_HUD_HEALTH_Y;
                w = UI_W(GG_HUD_W);
                h = UI_H(GG_HUD_ROW_H);
                colorText[] = UI_COLOR_TEXT;
            };
            class stagePanel: UI_HudPanel {
                idc = 5;
                x = GG_HUD_X;
                y = GG_HUD_STAGE_Y;
                w = UI_W(GG_HUD_W);
                h = UI_H(GG_HUD_ROW_H);
            };
            // ladder progress in grey like every fill level bar; GG_fnc_guiLoop scales its width (full = end of the ladder)
            class stageBar: UI_HudPanel {
                idc = 1300;
                x = GG_HUD_X;
                y = GG_HUD_STAGE_Y;
                w = UI_W(GG_HUD_W);
                h = UI_H(GG_HUD_ROW_H);
                colorBackground[] = UI_COLOR_BAR_FILL;
            };
            class stageText: UI_HudText {
                idc = 1301;
                style = ST_CENTER;
                text = "";
                x = GG_HUD_X;
                y = GG_HUD_STAGE_Y;
                w = UI_W(GG_HUD_W);
                h = UI_H(GG_HUD_ROW_H);
                colorText[] = UI_COLOR_TEXT;
            };
            class killsKd: UI_HudText {
                idc = 1002;
                style = ST_CENTER;
                text = "";
                x = GG_HUD_X;
                y = GG_HUD_KILLS_Y;
                w = UI_W(GG_HUD_W);
                h = UI_H(GG_HUD_ROW_H);
                colorBackground[] = UI_COLOR_HUD_PANEL;
            };
            class kdAndUnits: UI_HudText {
                idc = 1003;
                style = ST_CENTER;
                text = "";
                x = GG_HUD_X;
                y = GG_HUD_RATIO_Y;
                w = UI_W(GG_HUD_W);
                h = UI_H(GG_HUD_ROW_H);
                colorBackground[] = UI_COLOR_HUD_PANEL;
            };
        };
    };
};

// ---- notifications ----

class CfgNotifications {
    class gunGame {
        title = "GunGame";
        iconText = "%1";
        iconPicture = "%2";
        description = "%3";
        color[] = UI_COLOR_TEXT;
        duration = 3;
        priority = 1;
    };
    // last stages and kill streaks (GG_fnc_announce)
    class gunGameAnnouncement {
        title = "GunGame";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "%1";
        color[] = UI_COLOR_TEXT;
        duration = 4;
        priority = 2;
    };
    class inventoryDisabled {
        title = "GunGame";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "You are not allowed to access your inventory";
        color[] = UI_COLOR_TEXT;
        duration = 5;
        priority = 0;
    };
    class spawnProtectionDisabled {
        title = "Spawn Protection";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Spawnprotection disabled";
        color[] = UI_COLOR_TEXT;
        duration = 3;
        priority = 0;
    };
};
