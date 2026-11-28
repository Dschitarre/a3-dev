// Battle Royale screens: HUD (RscTitles BR_rscHud), results dialog, notifications and debriefing. Controls derive from
// the UI_* blocks of ui\ui.hpp.

// ---- HUD ----
// In the style of the other modes (TDM / GunGame / SC: vanilla fonts, HUD panel color, grey fill bars, only the
// health green):
//   top center      like the TDM score: alive count | zone timer | kills in large numbers, their labels in a row under
//                   them (the middle one the zone status); the timer's panel empties with the phase (grey fill)
//   bottom right    the health bar where TDM / GunGame have it, above it the boost (while one is active) and the
//                   distance to the safe zone (while outside of it); rows that are hidden leave no gap
//   bottom left     the team mates like the SC group overview: name and distance, a thin health bar along the row
// Sizes in grid cells. The rows of the right column and of the team are placed by BR_fnc_hudLayoutRows (BR\hud.sqf).

#define BR_HUD_TOP_Y            (safeZoneY + UI_H(0.5))
#define BR_HUD_LABEL_Y          (safeZoneY + UI_H(0.5 + UI_ROW + UI_GAP))
#define BR_HUD_LABEL_H          0.8
#define BR_HUD_SIDE_W           2.5
#define BR_HUD_TIMER_W          5
#define BR_HUD_LEFT_X           UI_X(20 - BR_HUD_TIMER_W / 2 - UI_GAP - BR_HUD_SIDE_W)
#define BR_HUD_TIMER_X          UI_X(20 - BR_HUD_TIMER_W / 2)
#define BR_HUD_RIGHT_X          UI_X(20 + BR_HUD_TIMER_W / 2 + UI_GAP)

#define BR_HUD_ROW_H            0.8
#define BR_HUD_RIGHT_W          7
#define BR_HUD_RIGHT_COLUMN_X   (safeZoneX + safeZoneW - UI_W(BR_HUD_RIGHT_W + 0.5))
#define BR_HUD_BOTTOM_Y         (safeZoneY + safeZoneH - UI_H(1.5))
#define BR_HUD_TEAM_W           9
#define BR_HUD_TEAM_X           (safeZoneX + UI_W(0.5))
#define BR_HUD_TEAM_BAR_H       0.12
#define BR_HUD_JUMP_W           9
#define BR_HUD_JUMP_X           UI_X(20 - BR_HUD_JUMP_W / 2)
#define BR_HUD_JUMP_Y           (safeZoneY + safeZoneH - UI_H(4.5))

// a text on its own HUD panel
class BR_HudBox: UI_HudText {
    colorBackground[] = UI_COLOR_HUD_PANEL;
};

// a box of the top row / label row (BASE: BR_HudBox, or UI_HudText for a text over other panels)
#define BR_HUD_BOX(NAME, BASE, IDC, X, Y, W, H, SIZE) \
    class NAME: BASE { \
        idc = IDC; \
        style = ST_CENTER; \
        text = ""; \
        x = X; \
        y = Y; \
        w = UI_W(W); \
        h = UI_H(H); \
        sizeEx = SIZE; \
    };

// a bar of the right column: panel, fill, text (placed by script)
#define BR_HUD_BAR(NAME, IDC, FILL_COLOR) \
    class NAME##Panel: UI_HudPanel { \
        idc = IDC; \
        x = BR_HUD_RIGHT_COLUMN_X; \
        y = BR_HUD_BOTTOM_Y; \
        w = UI_W(BR_HUD_RIGHT_W); \
        h = UI_H(BR_HUD_ROW_H); \
    }; \
    class NAME##Fill: UI_HudPanel { \
        idc = IDC + 1; \
        x = BR_HUD_RIGHT_COLUMN_X; \
        y = BR_HUD_BOTTOM_Y; \
        w = UI_W(BR_HUD_RIGHT_W); \
        h = UI_H(BR_HUD_ROW_H); \
        colorBackground[] = FILL_COLOR; \
    }; \
    class NAME##Text: UI_HudText { \
        idc = IDC + 2; \
        style = ST_CENTER; \
        text = ""; \
        x = BR_HUD_RIGHT_COLUMN_X; \
        y = BR_HUD_BOTTOM_Y; \
        w = UI_W(BR_HUD_RIGHT_W); \
        h = UI_H(BR_HUD_ROW_H); \
    };

// a team mate row: panel, thin health bar along its bottom edge, name (left), distance / state (right)
#define BR_HUD_TEAM_ROW(NAME, IDC) \
    class NAME##Panel: UI_HudPanel { \
        idc = IDC; \
        x = BR_HUD_TEAM_X; \
        y = BR_HUD_BOTTOM_Y; \
        w = UI_W(BR_HUD_TEAM_W); \
        h = UI_H(BR_HUD_ROW_H); \
    }; \
    class NAME##Health: UI_HudPanel { \
        idc = IDC + 1; \
        x = BR_HUD_TEAM_X; \
        y = BR_HUD_BOTTOM_Y; \
        w = UI_W(BR_HUD_TEAM_W); \
        h = UI_H(BR_HUD_TEAM_BAR_H); \
        colorBackground[] = UI_COLOR_HEALTH; \
    }; \
    class NAME##Name: UI_HudText { \
        idc = IDC + 2; \
        style = ST_LEFT; \
        text = ""; \
        x = BR_HUD_TEAM_X; \
        y = BR_HUD_BOTTOM_Y; \
        w = UI_W(BR_HUD_TEAM_W); \
        h = UI_H(BR_HUD_ROW_H); \
    }; \
    class NAME##Value: UI_HudText { \
        idc = IDC + 3; \
        style = ST_RIGHT; \
        text = ""; \
        x = BR_HUD_TEAM_X; \
        y = BR_HUD_BOTTOM_Y; \
        w = UI_W(BR_HUD_TEAM_W); \
        h = UI_H(BR_HUD_ROW_H); \
    };

class RscTitles {
    class BR_rscItemUse {
        idd=-1;duration=999999;fadeIn=0;fadeOut=0;
        onLoad="uiNamespace setVariable ['BR_rscItemUse',_this select 0]";
        onUnload="uiNamespace setVariable ['BR_rscItemUse',displayNull]";
        class controls {
            class progress: UI_Progress {
                idc=1500;x=UI_X(15);y=(safeZoneY+safeZoneH-UI_H(3));w=UI_W(10);h=UI_H(0.7);
                colorFrame[]={0,0,0,0.7};colorBar[]={1,1,1,1};
            };
            class label: UI_HudText {
                idc=1501;x=UI_X(15);y=(safeZoneY+safeZoneH-UI_H(4));w=UI_W(10);h=UI_H(1);
                style=ST_CENTER;text="";
            };
        };
    };
    class BR_rscHud {
        idd = 5000;
        movingEnable = false;
        enableSimulation = true;
        duration = 999999;
        fadeIn = 0;
        fadeOut = 0;
        onLoad = "uiNamespace setVariable [""BR_rscHud"", _this select 0]";

        // panels and fills first, texts last, so no bar ever covers a text
        class controlsBackground {
            // top center: alive | zone timer (panel, remaining time as grey fill, text) | kills, labels under them
            BR_HUD_BOX(leftCount, BR_HudBox, 1300, BR_HUD_LEFT_X, BR_HUD_TOP_Y, BR_HUD_SIDE_W, UI_ROW, UI_TEXT)
            class timerPanel: UI_HudPanel {
                idc = 1301;
                x = BR_HUD_TIMER_X;
                y = BR_HUD_TOP_Y;
                w = UI_W(BR_HUD_TIMER_W);
                h = UI_H(UI_ROW);
            };
            class timerFill: UI_HudPanel {
                idc = 1302;
                x = BR_HUD_TIMER_X;
                y = BR_HUD_TOP_Y;
                w = UI_W(BR_HUD_TIMER_W);
                h = UI_H(UI_ROW);
                colorBackground[] = UI_COLOR_BAR_FILL;
            };
            BR_HUD_BOX(rightCount, BR_HudBox, 1304, BR_HUD_RIGHT_X, BR_HUD_TOP_Y, BR_HUD_SIDE_W, UI_ROW, UI_TEXT)
            BR_HUD_BOX(leftLabel, BR_HudBox, 1310, BR_HUD_LEFT_X, BR_HUD_LABEL_Y, BR_HUD_SIDE_W, BR_HUD_LABEL_H, UI_TEXT_SMALL)
            BR_HUD_BOX(status, BR_HudBox, 1311, BR_HUD_TIMER_X, BR_HUD_LABEL_Y, BR_HUD_TIMER_W, BR_HUD_LABEL_H, UI_TEXT_SMALL)
            BR_HUD_BOX(rightLabel, BR_HudBox, 1312, BR_HUD_RIGHT_X, BR_HUD_LABEL_Y, BR_HUD_SIDE_W, BR_HUD_LABEL_H, UI_TEXT_SMALL)

            // bottom right: health (green, the error color at low health), boost (grey), distance to the safe zone
            BR_HUD_BAR(health, 1200, UI_COLOR_HEALTH)
            BR_HUD_BAR(boost, 1210, UI_COLOR_BAR_FILL)
            BR_HUD_BOX(zoneDistance, BR_HudBox, 1220, BR_HUD_RIGHT_COLUMN_X, BR_HUD_BOTTOM_Y, BR_HUD_RIGHT_W, BR_HUD_ROW_H, UI_TEXT_SMALL)

            // bottom left: up to three team mates
            BR_HUD_TEAM_ROW(mate0, 1400)
            BR_HUD_TEAM_ROW(mate1, 1410)
            BR_HUD_TEAM_ROW(mate2, 1420)

            // bottom center while aboard the aircraft: the jump prompt
            BR_HUD_BOX(jumpPrompt, BR_HudBox, 1230, BR_HUD_JUMP_X, BR_HUD_JUMP_Y, BR_HUD_JUMP_W, UI_ROW, UI_TEXT)
        };

        class controls {
            BR_HUD_BOX(timer, UI_HudText, 1303, BR_HUD_TIMER_X, BR_HUD_TOP_Y, BR_HUD_TIMER_W, UI_ROW, UI_TEXT)
        };
    };
};

// ---- results dialog ----
// Title bar, body with the summary and the ranking (place, team, name, kills), close button bottom right.

#define BR_RESULTS_X        8
#define BR_RESULTS_W        24
#define BR_RESULTS_Y        3
#define BR_RESULTS_BODY_H   16

class BR_dialogResults {
    idd = 5100;
    movingEnable = false;
    onLoad = "uiNamespace setVariable [""BR_dialogResults"", _this select 0]";

    class controlsBackground {
        class title: UI_Title {
            idc = 1000;
            text = "Match Results";
            x = UI_X(BR_RESULTS_X);
            y = UI_Y(BR_RESULTS_Y);
            w = UI_W(BR_RESULTS_W);
            h = UI_H(UI_ROW);
        };
        class body: UI_Panel {
            idc = 1001;
            x = UI_X(BR_RESULTS_X);
            y = UI_Y(BR_RESULTS_Y + UI_ROW);
            w = UI_W(BR_RESULTS_W);
            h = UI_H(BR_RESULTS_BODY_H);
        };
    };

    class controls {
        class summary: UI_StructuredText {
            idc = 1501;
            x = UI_X(BR_RESULTS_X + UI_PADDING);
            y = UI_Y(BR_RESULTS_Y + UI_ROW + UI_PADDING);
            w = UI_W(BR_RESULTS_W - 2 * UI_PADDING);
            h = UI_H(2);
        };
        class ranking: UI_ListN {
            idc = 1500;
            columns[] = {0, 0.12, 0.32, 0.86};
            x = UI_X(BR_RESULTS_X + UI_PADDING);
            y = UI_Y(BR_RESULTS_Y + UI_ROW + UI_PADDING + 2 + UI_GAP);
            w = UI_W(BR_RESULTS_W - 2 * UI_PADDING);
            h = UI_H(BR_RESULTS_BODY_H - 2 * UI_PADDING - 2 - UI_GAP);
        };
        class close: UI_ButtonOK {
            text = "Close";
            x = UI_X(BR_RESULTS_X + BR_RESULTS_W - 6);
            y = UI_Y(BR_RESULTS_Y + UI_ROW + BR_RESULTS_BODY_H + UI_GAP);
            w = UI_W(6);
        };
    };
};

class CfgNotifications {
    class groupSystem {
        title="Group";description="%1";duration=4;priority=1;iconPicture="\A3\ui_f\data\map\vehicleicons\iconMan_ca.paa";
    };
    class brInfo {
        title = "Battle Royale";
        iconPicture = "\A3\ui_f\data\IGUI\RscTitles\MPProgress\timer_ca.paa";
        description = "%1";
        color[] = UI_COLOR_TEXT;
        duration = 4;
        priority = 1;
    };
    class brZone {
        title = "Safe Zone";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "%1";
        color[] = UI_COLOR_TEXT;
        duration = 4;
        priority = 2;
    };
    class brAirdrop {
        title = "Supply Drop";
        iconPicture = "\A3\ui_f\data\map\markers\military\box_CA.paa";
        description = "Supply drop at %1";
        color[] = UI_COLOR_TEXT;
        duration = 5;
        priority = 2;
    };
    class brEliminated {
        title = "Eliminated";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Placed #%1 of %2";
        color[] = UI_COLOR_TEXT;
        duration = 6;
        priority = 3;
    };
};

class CfgDebriefing {
    class BR_matchEnd {
        title = "Match over";
        description = "The last team standing has won.";
    };
};
