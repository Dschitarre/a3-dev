// TDM screens: HUD (RscTitles DM_rscHud), notifications and debriefings. Controls derive from the UI_* blocks of ui\ui.hpp.

// ---- HUD ----
// Top center: west points | timer | east points, below them the alive units per side.
// Bottom right: health bar, as in GunGame.
// Sizes in grid cells; the score rows hang from the top edge of the screen, the health bar sits in the bottom right corner.

#define DM_HUD_SCORE_Y      (safeZoneY + UI_H(0.5))
#define DM_HUD_ALIVE_Y      (safeZoneY + UI_H(0.5 + UI_ROW + UI_GAP))
#define DM_HUD_ALIVE_H      0.8
#define DM_HUD_HEALTH_W     7
#define DM_HUD_HEALTH_H     0.8
#define DM_HUD_HEALTH_X     (safeZoneX + safeZoneW - UI_W(DM_HUD_HEALTH_W + 0.5))
#define DM_HUD_HEALTH_Y     (safeZoneY + safeZoneH - UI_H(1.5))

class RscTitles {
    class DM_rscHud {
        idd = 5000;
        movingEnable = false;
        enableSimulation = true;
        duration = 999999;
        fadeIn = 0;
        fadeOut = 0;
        onLoad = "uiNamespace setVariable [""DM_rscHud"", _this select 0]";

        class controlsBackground {
            // panels behind the score row and the health bar, the points in the side colors
            class westPointsPanel: UI_HudPanel {
                idc = 1;
                x = UI_X(16.4);
                y = DM_HUD_SCORE_Y;
                w = UI_W(2);
                h = UI_H(UI_ROW);
                colorBackground[] = UI_COLOR_BLUFOR;
            };
            class eastPointsPanel: UI_HudPanel {
                idc = 2;
                x = UI_X(21.6);
                y = DM_HUD_SCORE_Y;
                w = UI_W(2);
                h = UI_H(UI_ROW);
                colorBackground[] = UI_COLOR_OPFOR;
            };
            class timerPanel: UI_HudPanel {
                idc = 3;
                x = UI_X(18.5);
                y = DM_HUD_SCORE_Y;
                w = UI_W(3);
                h = UI_H(UI_ROW);
            };
            class healthPanel: UI_HudPanel {
                idc = 4;
                x = DM_HUD_HEALTH_X;
                y = DM_HUD_HEALTH_Y;
                w = UI_W(DM_HUD_HEALTH_W);
                h = UI_H(DM_HUD_HEALTH_H);
            };
            class westTickets: UI_HudText {
                idc = 1100;
                style = ST_CENTER;
                text = "0";
                x = UI_X(16.4);
                y = DM_HUD_SCORE_Y;
                w = UI_W(2);
                h = UI_H(UI_ROW);
                sizeEx = UI_TEXT;
                colorText[] = UI_COLOR_TEXT;
            };
            class eastTickets: UI_HudText {
                idc = 1102;
                style = ST_CENTER;
                text = "0";
                x = UI_X(21.6);
                y = DM_HUD_SCORE_Y;
                w = UI_W(2);
                h = UI_H(UI_ROW);
                sizeEx = UI_TEXT;
                colorText[] = UI_COLOR_TEXT;
            };
            class timer: UI_HudText {
                idc = 1101;
                style = ST_CENTER;
                text = "0:00";
                x = UI_X(18.5);
                y = DM_HUD_SCORE_Y;
                w = UI_W(3);
                h = UI_H(UI_ROW);
                sizeEx = UI_TEXT;
            };
            class westPlayerCount: UI_HudText {
                idc = 1000;
                style = ST_CENTER;
                text = "0";
                x = UI_X(16.4);
                y = DM_HUD_ALIVE_Y;
                w = UI_W(2);
                h = UI_H(DM_HUD_ALIVE_H);
                colorBackground[] = UI_COLOR_HUD_PANEL;
            };
            class eastPlayerCount: UI_HudText {
                idc = 1001;
                style = ST_CENTER;
                text = "0";
                x = UI_X(21.6);
                y = DM_HUD_ALIVE_Y;
                w = UI_W(2);
                h = UI_H(DM_HUD_ALIVE_H);
                colorBackground[] = UI_COLOR_HUD_PANEL;
            };
            class vs: UI_HudText {
                idc = 1002;
                style = ST_CENTER;
                text = "VS";
                x = UI_X(18.5);
                y = DM_HUD_ALIVE_Y;
                w = UI_W(3);
                h = UI_H(DM_HUD_ALIVE_H);
                colorBackground[] = UI_COLOR_HUD_PANEL;
            };
            // health fill in green (the only green bar); DM_fnc_guiLoop scales its width (full = 100 HP)
            class hpBackground: UI_HudPanel {
                idc = 1200;
                x = DM_HUD_HEALTH_X;
                y = DM_HUD_HEALTH_Y;
                w = UI_W(DM_HUD_HEALTH_W);
                h = UI_H(DM_HUD_HEALTH_H);
                colorBackground[] = UI_COLOR_HEALTH;
            };
            class hpText: UI_HudText {
                idc = 1201;
                style = ST_CENTER;
                text = "0 HP";
                x = DM_HUD_HEALTH_X;
                y = DM_HUD_HEALTH_Y;
                w = UI_W(DM_HUD_HEALTH_W);
                h = UI_H(DM_HUD_HEALTH_H);
                colorText[] = UI_COLOR_TEXT;
            };
        };
    };
};

// ---- notifications and debriefings ----

class CfgNotifications {
    class outsidePlayzone {
        title = "Playzone";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Go back into the playZone or you will suffer damage";
        color[] = UI_COLOR_TEXT;
        duration = 3;
        priority = 1;
    };
    class backInPlayzone {
        title = "Playzone";
        iconPicture = "\A3\ui_f\data\map\mapcontrol\taskIconDone_ca.paa";
        description = "You are back in the playzone";
        color[] = UI_COLOR_TEXT;
        duration = 3;
        priority = 1;
    };
    class teamDeathmatch {
        title = "Team Deathmatch";
        iconPicture = "\A3\ui_f\data\IGUI\RscTitles\MPProgress\timer_ca.paa";
        description = "%1";
        color[] = UI_COLOR_TEXT;
        duration = 3;
        priority = 1;
    };
    class zone {
        title = "Zone";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Zone shrinks now";
        color[] = UI_COLOR_TEXT;
        duration = 3;
        priority = 1;
    };
    class bluforWonThisRound {
        title = "Team Deathmatch";
        iconPicture = "\A3\ui_f\data\Map\Markers\NATO\b_installation.paa";
        description = "Blufor won this round";
        color[] = UI_COLOR_TEXT;
        duration = 3;
        priority = 1;
    };
    class opforWonThisRound {
        title = "Team Deathmatch";
        iconPicture = "\A3\ui_f\data\Map\Markers\NATO\o_installation.paa";
        description = "Opfor won this round";
        color[] = UI_COLOR_TEXT;
        duration = 3;
        priority = 1;
    };
};

class CfgDebriefing {
    class west {
        title = "Blufor won";
        description = "Blufor won the match.";
    };
    class east {
        title = "Opfor won";
        description = "Opfor won the match.";
    };
};
