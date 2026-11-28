// SC dialogs and displays, built from the UI_* blocks of ui\ui.hpp (vanilla look, player's UI colors).
// Layout in grid cells of the centered 40 x 25 area: title bar, body panel with 0.5 padding, 0.1 gaps, button row.

// ---- local building blocks (no matching UI_* block in ui\ui.hpp) ----

#ifndef CT_CONTROLS_TABLE
    #define CT_CONTROLS_TABLE 19
#endif

// row height of the tables (cells): high enough for readable weapon pictures
#define SC_ROW_H 2

// controls table; its scrollbar classes (VScrollbar / HScrollbar) come from UI_Group (RscControlsGroup)
class SC_ControlsTable: UI_Group {
    type = CT_CONTROLS_TABLE;
    style = SL_TEXTURES;
    lineSpacing = 0;
    rowHeight = UI_H(SC_ROW_H);
    headerHeight = UI_H(UI_ROW);
    firstIDC = 42000;
    lastIDC = 900000;
    selectedRowColorFrom[] = {1, 1, 1, 0.1};
    selectedRowColorTo[] = {1, 1, 1, 0.25};
    selectedRowAnimLength = 1.2;
};

// table cells in the body text size (rows SC_ROW_H, header 1 cell high); the row / header background colors are set by
// script (SC_fnc_styleTableRow / SC_fnc_styleTableHeader)
class SC_TableText: UI_Text {
    colorBackground[] = {0, 0, 0, 0};
};

// cell with a long list (the perks of a stored loadout, up to 6 "[ABBR]" in 13.2 cells): wraps into a second line of
// the SC_ROW_H high row
class SC_TableTextSmall: SC_TableText {
    style = ST_MULTI + ST_NO_RECT;
    sizeEx = UI_TEXT_SMALL;
};

class SC_TablePicture: UI_PictureKeepAspect {};

// clickable table row background / sortable header cell: ui.hpp has no plain button (UI_Button is a menu button)
class SC_TableButton: RscButton {
    style = ST_LEFT;
    font = GUI_FONT_NORMAL;
    sizeEx = UI_TEXT;
    shadow = 0;
    colorText[] = UI_COLOR_TEXT;
    colorDisabled[] = UI_COLOR_DISABLED;
    colorBackground[] = {0, 0, 0, 0};
    colorBackgroundActive[] = {1, 1, 1, 0.1};
    colorBackgroundDisabled[] = {0, 0, 0, 0};
    colorFocused[] = {0, 0, 0, 0};
    colorShadow[] = {0, 0, 0, 0};
    colorBorder[] = {0, 0, 0, 0};
    offsetX = 0;
    offsetY = 0;
    offsetPressedX = 0;
    offsetPressedY = 0;
};

// title bar and body panel of a dialog: position, width and body height in cells
#define SC_DIALOG_FRAME(PX, PY, PW, PBODY, PTITLE) \
    class SC_Body: UI_Panel { \
        idc = 1000; \
        x = UI_X(PX); \
        y = UI_Y((PY) + UI_ROW); \
        w = UI_W(PW); \
        h = UI_H(PBODY); \
    }; \
    class SC_Title: UI_Title { \
        idc = 1002; \
        text = PTITLE; \
        x = UI_X(PX); \
        y = UI_Y(PY); \
        w = UI_W(PW); \
    };

// table column: template class name, base class, x and width in cells, height
#define SC_TABLE_COLUMN(PNAME, PBASE, PX, PW, PH) \
    class PNAME { \
        controlBaseClassPath[] = {PBASE}; \
        columnX = UI_W(PX); \
        columnW = UI_W(PW); \
        controlH = UI_H(PH); \
        controlOffsetY = 0; \
    };

// string of an SQF expression (no commas in the argument)
#define SC_QUOTE(PCODE) #PCODE

// ---- HUD building blocks (sectorControlDisplay in SC\hud\hudDisplay.hpp); positions are set by script ----

// pure white text with a dark outline (shadow 2), readable on the light accent / side colored bars
class SC_HudText: UI_HudText {
    style = ST_CENTER;
    shadow = 2;
    x = safeZoneX - safeZoneW;
    y = safeZoneY - safeZoneH;
    w = 0;
    h = 0;
};

class SC_HudPanel: SC_HudText {
    colorBackground[] = UI_COLOR_HUD_PANEL;
};

// player stats and spawn vehicles (the general UI style like the TDM / GunGame health bar):
// every box on the player's HUD panel color (SC_HudPanel), bars filled grey (stamina turning red when low), rank and
// perks grey like the fills, only the player's health green, white text, no colored backgrounds; the sides are told
// apart by their NATO symbols
// (SC_fnc_hudLayoutPlayerStats)
class SC_HudBarFill: SC_HudText {
    colorBackground[] = UI_COLOR_BAR_FILL;
};

class SC_HudHpFill: SC_HudText {
    colorBackground[] = UI_COLOR_HEALTH;
};

// not yet captured part of a sector bar
class SC_HudSectorRemaining: SC_HudText {
    colorBackground[] = {0, 0, 0, 0.35};
};

// background of a group overview row and its thin health bar (error color at low health, set by script)
class SC_HudShade: SC_HudText {
    colorBackground[] = {0, 0, 0, 0.45};
};

class SC_HudHealth: SC_HudText {
    colorBackground[] = UI_COLOR_HUD_TEXT;
};

// sector letters of the sector overview: the original size, larger than the other HUD texts
class SC_HudSectorLetter: SC_HudText {
    sizeEx = 0.03915;
};

class SC_HudTextLeft: SC_HudText {
    style = ST_LEFT;
};

class SC_HudTextRight: SC_HudText {
    style = ST_RIGHT;
};

// structured text (force ratio of the capture info), alignment and colors by script
class SC_HudStructuredText: UI_StructuredText {
    size = UI_TEXT_SMALL;
    x = safeZoneX - safeZoneW;
    y = safeZoneY - safeZoneH;
    w = 0;
    h = 0;

    class Attributes {
        font = GUI_FONT_NORMAL;
        color = "#ffffff";
        align = "center";
        shadow = 1;
    };
};

class SC_HudPicture: UI_Picture {
    colorText[] = UI_COLOR_HUD_TEXT;
    x = safeZoneX - safeZoneW;
    y = safeZoneY - safeZoneH;
    w = 0;
    h = 0;
};

// vehicle pictures of the group overview (different aspect ratios)
class SC_HudPictureKeepAspect: UI_PictureKeepAspect {
    colorText[] = UI_COLOR_HUD_TEXT;
    x = safeZoneX - safeZoneW;
    y = safeZoneY - safeZoneH;
    w = 0;
    h = 0;
};

// round panel behind the direction arrow of a spawn vehicle (SC\hud\circle_ca.paa: a white disc filling its texture)
class SC_HudCircle: SC_HudPictureKeepAspect {
    text = "SC\hud\circle_ca.paa";
    colorText[] = UI_COLOR_HUD_PANEL;
};

// outline of a bar (160 = ST_WITH_RECT) and separator line (96 = ST_SHADOW)
class SC_HudFrame: UI_Frame {
    style = 160;
    colorText[] = {0, 0, 0, 0.6};
    x = safeZoneX - safeZoneW;
    y = safeZoneY - safeZoneH;
    w = 0;
    h = 0;
};

class SC_HudLine: SC_HudFrame {
    style = 96;
};

// ---- information boards (base): topic list and the text of the chosen topic (SC\infoBoards.sqf) ----

class infoDialog {
    idd = 3000;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "uiNamespace setVariable [""SC_var_infoDialog"", _this select 0]";

    class ControlsBackground {
        SC_DIALOG_FRAME(4, 2, 32, 19.5, "Information")
        class SC_TextBackground: UI_Field {
            x = UI_X(12.6);
            y = UI_Y(3.5);
            w = UI_W(22.9);
            h = UI_H(18.5);
        };
    };

    class Controls {
        class SC_Topics: UI_List {
            idc = 1500;
            onLBSelChanged = "[_this select 1] call SC_fnc_showInfoTopic";
            x = UI_X(4.5);
            y = UI_Y(3.5);
            w = UI_W(8);
            h = UI_H(18.5);
        };
        // scrollable text: SC_fnc_showInfoTopic sets the height of SC_Text to its text height
        class SC_TextGroup: UI_Group {
            idc = 2300;
            x = UI_X(12.6);
            y = UI_Y(3.5);
            w = UI_W(22.9);
            h = UI_H(18.5);

            class Controls {
                class SC_Text: UI_StructuredText {
                    idc = 1100;
                    x = UI_W(UI_PADDING);
                    y = UI_H(UI_PADDING);
                    w = UI_W(21.4);
                    h = UI_H(17.5);
                };
            };
        };
        class SC_ButtonOk: UI_ButtonOK {
            idc = 4504;
            text = "OK";
            action = "closeDialog 0;";
            x = UI_X(30);
            y = UI_Y(22.6);
            w = UI_W(6);
        };
    };
};

// ---- arsenal ----

// rank and next unlock above the arsenal (created by SC_fnc_decorateArsenalTab), between the item lists like the
// arsenal's own message line
#define SC_ARSENAL_HEADER_W ((safeZoneW - UI_W(36)) max 0.4)

class SC_ArsenalHeader: UI_TextSmall {
    style = ST_CENTER;
    colorBackground[] = UI_COLOR_PANEL;
    x = safeZoneX + 0.5 * (safeZoneW - SC_ARSENAL_HEADER_W);
    y = safeZoneY + UI_H(0.5);
    w = SC_ARSENAL_HEADER_W;
};

// ---- settings (F4) ----

// Settings in sections: a row of tabs at the top of the body, below it the rows of the chosen section
// (SC_fnc_settingsShowSection). All sections use the same rows, from SC_SETTINGS_TOP on; the earplugs section is created
// by the earplugs mod (E_fnc_embedSettings). The width set here fits the labels at the usual interface sizes;
// SC_fnc_fitSettingsDialog narrows or widens the dialog to its longest row and centres it.
#define SC_SETTINGS_X 9
#define SC_SETTINGS_W 22
#define SC_SETTINGS_ROWS 15                       // rows of the largest section (HUD)
#define SC_SETTINGS_BODY_H (UI_PADDING + UI_ROW + UI_PADDING + SC_SETTINGS_ROWS + UI_PADDING)
#define SC_SETTINGS_Y ((25 - UI_ROW - SC_SETTINGS_BODY_H) / 2)
#define SC_SETTINGS_TABS_Y (SC_SETTINGS_Y + UI_ROW + UI_PADDING)
#define SC_SETTINGS_TOP (SC_SETTINGS_TABS_Y + UI_ROW + UI_PADDING)
#define SC_SETTINGS_TAB_W ((SC_SETTINGS_W - 2 * UI_PADDING - 3 * UI_GAP) / 4)

// setting PINDEX (SC_var_settings) in row PROW of its section
#define SC_SETTING(PINDEX, PROW, PIDC, PLABEL_IDC, PLABEL) \
    class SC_CheckBox##PINDEX: UI_CheckBox { \
        idc = PIDC; \
        onCheckedChanged = SC_QUOTE([PINDEX] call SC_fnc_toggleSetting); \
        x = UI_X(SC_SETTINGS_X + UI_PADDING); \
        y = UI_Y(SC_SETTINGS_TOP + PROW); \
    }; \
    class SC_Label##PINDEX: UI_Text { \
        idc = PLABEL_IDC; \
        text = PLABEL; \
        x = UI_X(SC_SETTINGS_X + UI_PADDING + UI_ROW + UI_GAP); \
        y = UI_Y(SC_SETTINGS_TOP + PROW); \
        w = UI_W(SC_SETTINGS_W - 2 * UI_PADDING - UI_ROW - UI_GAP); \
    };

// slider row: slider (vanilla slider height, centred in the row) and its label on the right
#define SC_SETTINGS_SLIDER_W 8

#define SC_SETTINGS_SLIDER(PNAME, PROW, PIDC, PLABEL_IDC, PLABEL, PCODE) \
    class PNAME: UI_Slider { \
        idc = PIDC; \
        onSliderPosChanged = PCODE; \
        x = UI_X(SC_SETTINGS_X + UI_PADDING); \
        y = UI_Y(SC_SETTINGS_TOP + PROW + 0.125); \
        w = UI_W(SC_SETTINGS_SLIDER_W); \
        h = UI_H(0.75); \
    }; \
    class PNAME##Label: UI_Text { \
        idc = PLABEL_IDC; \
        text = PLABEL; \
        x = UI_X(SC_SETTINGS_X + UI_PADDING + SC_SETTINGS_SLIDER_W + UI_GAP); \
        y = UI_Y(SC_SETTINGS_TOP + PROW); \
        w = UI_W(SC_SETTINGS_W - 2 * UI_PADDING - SC_SETTINGS_SLIDER_W - UI_GAP); \
    };

// tab of section PINDEX (idc 1610 + PINDEX): the chosen one in the accent color (SC_fnc_settingsShowSection), the
// others on the field color; focused (just clicked) in the accent color too, so it doesn't blink
class SC_SettingsTab: SC_TableButton {
    style = ST_CENTER;
    colorBackground[] = UI_COLOR_FIELD;
    colorBackgroundActive[] = UI_COLOR_ACCENT_DIM;
    colorFocused[] = UI_COLOR_ACCENT;
};

#define SC_SETTINGS_TAB(PINDEX, PTEXT) \
    class SC_SettingsTab##PINDEX: SC_SettingsTab { \
        idc = 161##PINDEX; \
        text = PTEXT; \
        onButtonClick = SC_QUOTE([PINDEX] call SC_fnc_settingsShowSection); \
        x = UI_X(SC_SETTINGS_X + UI_PADDING + PINDEX * (SC_SETTINGS_TAB_W + UI_GAP)); \
        y = UI_Y(SC_SETTINGS_TABS_Y); \
        w = UI_W(SC_SETTINGS_TAB_W); \
        h = UI_H(UI_ROW); \
    };

class settingsDialog {
    idd = 3000;
    onLoad = "uiNamespace setVariable [""SC_var_settingsDialog"", _this select 0]; call SC_fnc_setupSettingsDialog;";

    class ControlsBackground {
        SC_DIALOG_FRAME(SC_SETTINGS_X, SC_SETTINGS_Y, SC_SETTINGS_W, SC_SETTINGS_BODY_H, "Settings")
    };

    class Controls {
        SC_SETTINGS_TAB(0, "HUD")
        SC_SETTINGS_TAB(1, "Icons & Map")
        SC_SETTINGS_TAB(2, "Earplugs")
        SC_SETTINGS_TAB(3, "Other")

        // HUD
        SC_SETTING(0, 0, 2800, 1003, "HUD (press F2 to toggle)")
        SC_SETTING(1, 1, 2801, 1006, "Always show HUD when on map")
        SC_SETTING(2, 2, 2802, 1007, "Always show HUD when unconscious")
        SC_SETTING(3, 3, 2803, 1008, "Show all HUD components when on map")
        SC_SETTING(4, 4, 2804, 1009, "Show all HUD components when unconscious")
        SC_SETTING(5, 5, 2805, 1010, "Sector overview")
        SC_SETTING(6, 6, 2806, 1011, "Player stats")
        SC_SETTING(7, 7, 2807, 1012, "Group overview")
        SC_SETTING(8, 8, 2808, 1013, "Killfeed")
        SC_SETTING(9, 9, 2809, 1014, "Midfeed")
        SC_SETTING(10, 10, 2810, 1015, "Deathfeed")
        SC_SETTING(17, 11, 2817, 1022, "Vehicle-, soldier- and weapon info panels")
        SC_SETTING(18, 12, 2818, 1023, "Vehicle radar")
        SC_SETTING(19, 13, 2819, 1024, "Vehicle compass")
        SC_SETTING(20, 14, 2820, 1025, "GPS-/vehicle panel (press F3 to toggle)")

        // Icons & Map
        SC_SETTING(11, 0, 2811, 1016, "Unit names below 3D unit icons")
        SC_SETTING(12, 1, 2812, 1017, "Hide invisible 3D group icons")
        SC_SETTING(13, 2, 2813, 1018, "Limit 3D group icon draw distance")
        SC_SETTING(14, 3, 2814, 1019, "Sector 3D icons")
        SC_SETTING(15, 4, 2815, 1020, "Airdrop 3D icons")
        SC_SETTING(16, 5, 2816, 1021, "Show unit names on map only when hovered over")

        // Other (Earplugs: created by the earplugs mod)
        SC_SETTINGS_SLIDER(SC_ViewDistance, 0, 1900, 1004, "Ground: objects 2000 m, view 2500 m", "_this call SC_fnc_settingsViewDistanceChanged")
        SC_SETTINGS_SLIDER(SC_FlightViewDistance, 1, 1901, 1027, "Flight: objects 3500 m, view 4375 m", "_this call SC_fnc_settingsViewDistanceChanged")
        SC_SETTING(21, 2, 2821, 1026, "Show locked items in the arsenal")
    };
};

// ---- tall table dialogs: statistics, vehicle spawn, equipment and groups share one vertical extent ----

// height in cells from the top of the title bar to the bottom edge (a button row included), centered in the 25 rows;
// half a cell stays free at the top and the bottom (at the largest interface size the grid fills the screen height)
#define SC_TALL_DIALOG_H 24
#define SC_TALL_DIALOG_Y ((25 - SC_TALL_DIALOG_H) / 2)
// first content row (below the title bar and the padding) and the content height between the paddings of a body
// without a button row; the controls are placed relative to these, so they follow SC_TALL_DIALOG_H
#define SC_TALL_DIALOG_TOP (SC_TALL_DIALOG_Y + UI_ROW + UI_PADDING)
#define SC_TALL_DIALOG_CONTENT_H (SC_TALL_DIALOG_H - UI_ROW - 2 * UI_PADDING)

// ---- player statistics ----

// stat tiles: background, small label and large value (idc, set by SC_fnc_showStatistics), the full name as tooltip;
// 5 columns x 2 rows over the 27 cells between the paddings: w = (27 - 4 * UI_GAP) / 5 = 5.32, rows 2.4 + UI_GAP apart;
// below them the two buttons and the table, which takes the remaining height
class SC_StatLabel: UI_TextSmall {
    style = ST_CENTER;
    h = UI_H(0.8);
};

class SC_StatValue: UI_Text {
    style = ST_CENTER;
    font = GUI_FONT_BOLD;
    sizeEx = UI_TEXT_LARGE;
    h = UI_H(1.2);
};

#define SC_STAT_TILE(PIDC, PLABEL, PTOOLTIP, PCOLUMN, PROW) \
    class SC_StatTile##PIDC: UI_Field { \
        x = UI_X(6.5 + (PCOLUMN) * 5.42); \
        y = UI_Y(SC_TALL_DIALOG_TOP + (PROW) * 2.5); \
        w = UI_W(5.32); \
        h = UI_H(2.4); \
    }; \
    class SC_StatLabel##PIDC: SC_StatLabel { \
        text = PLABEL; \
        tooltip = PTOOLTIP; \
        x = UI_X(6.5 + (PCOLUMN) * 5.42); \
        y = UI_Y(SC_TALL_DIALOG_TOP + 0.2 + (PROW) * 2.5); \
        w = UI_W(5.32); \
    }; \
    class SC_Stat##PIDC: SC_StatValue { \
        idc = PIDC; \
        tooltip = PTOOLTIP; \
        x = UI_X(6.5 + (PCOLUMN) * 5.42); \
        y = UI_Y(SC_TALL_DIALOG_TOP + 1 + (PROW) * 2.5); \
        w = UI_W(5.32); \
    };

class statisticsDialog {
    idd = 3002;
    onLoad = "uiNamespace setVariable [""SC_var_statisticsDialog"", _this select 0]; [false, 1] call SC_fnc_showStatistics;";

    class ControlsBackground {
        SC_DIALOG_FRAME(6, SC_TALL_DIALOG_Y, 28, SC_TALL_DIALOG_H - UI_ROW, "Player Statistics")
    };

    class Controls {
        // combat (K/D highlighted in the accent color), then teamplay
        SC_STAT_TILE(1003, "Kills", "Kills", 0, 0)
        SC_STAT_TILE(1004, "Deaths", "Deaths", 1, 0)
        SC_STAT_TILE(1008, "K/D", "Kills per death", 2, 0)
        SC_STAT_TILE(1006, "Headshot Rate", "Share of your kills and assists by headshot", 3, 0)
        SC_STAT_TILE(1005, "Assists", "Assists / finally killed units", 4, 0)
        SC_STAT_TILE(1007, "Captures", "Sectors captured", 0, 1)
        SC_STAT_TILE(1009, "Revives", "Units you revived", 1, 1)
        SC_STAT_TILE(1010, "Times Revived", "Revives you received", 2, 1)
        SC_STAT_TILE(1011, "Heals", "Units you healed", 3, 1)
        SC_STAT_TILE(1012, "Self Heals", "Times you healed yourself", 4, 1)

        class SC_ShowKills: UI_Button {
            idc = 1600;
            text = "Show Kill Statistics";
            onButtonClick = "[false, 1] call SC_fnc_showStatistics;";
            x = UI_X(6.5);
            y = UI_Y(SC_TALL_DIALOG_TOP + 5);
            w = UI_W(13.45);
        };
        class SC_ShowDeaths: UI_Button {
            idc = 1601;
            text = "Show Death Statistics";
            onButtonClick = "[true, 1] call SC_fnc_showStatistics;";
            x = UI_X(20.05);
            y = UI_Y(SC_TALL_DIALOG_TOP + 5);
            w = UI_W(13.45);
        };
        class SC_Table: SC_ControlsTable {
            idc = 1500;
            x = UI_X(6.5);
            y = UI_Y(SC_TALL_DIALOG_TOP + 6.1);
            w = UI_W(27);
            h = UI_H(SC_TALL_DIALOG_CONTENT_H - 6.1);

            class RowTemplate {
                SC_TABLE_COLUMN(RowBackground, "SC_TableText", 0, 27, SC_ROW_H)
                SC_TABLE_COLUMN(Picture, "SC_TablePicture", 0, 5.4, SC_ROW_H)
                SC_TABLE_COLUMN(Kills, "SC_TableText", 5.4, 2.97, SC_ROW_H)
                SC_TABLE_COLUMN(Assists, "SC_TableText", 8.37, 3.51, SC_ROW_H)
                SC_TABLE_COLUMN(Headshot_Rate, "SC_TableText", 11.88, 4.59, SC_ROW_H)
                SC_TABLE_COLUMN(Avg_Distance, "SC_TableText", 16.47, 6.21, SC_ROW_H)
                SC_TABLE_COLUMN(XP, "SC_TableText", 22.68, 4.32, SC_ROW_H)
            };
            class HeaderTemplate {
                SC_TABLE_COLUMN(RowBackground, "SC_TableText", 0, 27, UI_ROW)
                SC_TABLE_COLUMN(Picture, "SC_TableText", 0, 5.4, UI_ROW)
                SC_TABLE_COLUMN(Kills, "SC_TableButton", 5.4, 2.97, UI_ROW)
                SC_TABLE_COLUMN(Assists, "SC_TableButton", 8.37, 3.51, UI_ROW)
                SC_TABLE_COLUMN(Headshot_Rate, "SC_TableButton", 11.88, 4.59, UI_ROW)
                SC_TABLE_COLUMN(Avg_Distance, "SC_TableButton", 16.47, 6.21, UI_ROW)
                SC_TABLE_COLUMN(XP, "SC_TableButton", 22.68, 4.32, UI_ROW)
            };
        };
    };
};

// ---- vehicle spawn (base, sectors, airfields) ----

// status line, the vehicle line (the side's vehicles and their limit), the table (remaining height) and the Spawn
// button row below the body
class vehicleSpawnDialog {
    idd = 3001;
    onLoad = "uiNamespace setVariable [""SC_var_vehicleSpawnDialog"", _this select 0];";

    class ControlsBackground {
        SC_DIALOG_FRAME(8, SC_TALL_DIALOG_Y, 24, SC_TALL_DIALOG_H - 2 * UI_ROW - UI_GAP, "Vehicles & Aircraft")
    };

    class Controls {
        class SC_Status: UI_Text {
            idc = 1003;
            style = ST_CENTER;
            text = "";
            x = UI_X(8.5);
            y = UI_Y(SC_TALL_DIALOG_TOP);
            w = UI_W(23);
        };
        // set by SC_fnc_updateVehicleSpawnDialog
        class SC_VehicleCount: UI_Text {
            idc = 1004;
            style = ST_CENTER;
            text = "";
            x = UI_X(8.5);
            y = UI_Y(SC_TALL_DIALOG_TOP + UI_ROW);
            w = UI_W(23);
        };
        class SC_Table: SC_ControlsTable {
            idc = 1500;
            x = UI_X(8.5);
            y = UI_Y(SC_TALL_DIALOG_TOP + 2.5);
            w = UI_W(23);
            h = UI_H(SC_TALL_DIALOG_CONTENT_H - UI_ROW - UI_GAP - 2.5);

            class RowTemplate {
                SC_TABLE_COLUMN(RowBackground, "SC_TableButton", 0, 23, SC_ROW_H)
                SC_TABLE_COLUMN(Picture, "SC_TablePicture", 0, 4.6, SC_ROW_H)
                SC_TABLE_COLUMN(Name, "SC_TableText", 4.6, 13.8, SC_ROW_H)
                SC_TABLE_COLUMN(Rank, "SC_TableText", 18.4, 4.6, SC_ROW_H)
            };
            class HeaderTemplate {
                SC_TABLE_COLUMN(RowBackground, "SC_TableText", 0, 23, UI_ROW)
                SC_TABLE_COLUMN(Picture, "SC_TableText", 0, 4.6, UI_ROW)
                SC_TABLE_COLUMN(Name, "SC_TableText", 4.6, 13.8, UI_ROW)
                SC_TABLE_COLUMN(Rank, "SC_TableText", 18.4, 4.6, UI_ROW)
            };
        };
        class SC_Spawn: UI_Button {
            idc = 1600;
            text = "Spawn";
            x = UI_X(26);
            y = UI_Y(SC_TALL_DIALOG_Y + SC_TALL_DIALOG_H - UI_ROW);
            w = UI_W(6);
        };
    };
};

// ---- round end: overlay over the circling round end camera (result, MVPs, leaderboard, vote for the next map) ----

// panel with a title bar on top: class prefix, x, y (of the title), width and body height in cells, title
#define SC_OVERLAY_PANEL(PNAME, PX, PY, PW, PBODY, PTITLE) \
    class PNAME##Body: UI_Panel { \
        x = UI_X(PX); \
        y = UI_Y((PY) + UI_ROW); \
        w = UI_W(PW); \
        h = UI_H(PBODY); \
    }; \
    class PNAME##Title: UI_Title { \
        text = PTITLE; \
        x = UI_X(PX); \
        y = UI_Y(PY); \
        w = UI_W(PW); \
    };

// the centre stays free for the camera; Escape is blocked (the screen stays open until the mission ends)
class roundEndDialog {
    idd = 3003;
    onLoad = "uiNamespace setVariable [""SC_var_roundEndDialog"", _this select 0];";
    onKeyDown = "(_this select 1) == 1";

    class ControlsBackground {
        SC_OVERLAY_PANEL(SC_Result, 5, 0.5, 30, 6.8, "Round Over")
        SC_OVERLAY_PANEL(SC_Stats, 0.5, 8.7, 17, 13.8, "Leaderboard")
        SC_OVERLAY_PANEL(SC_Vote, 26.5, 8.7, 13, 13.8, "Vote for the Next Map")
    };

    class Controls {
        class SC_Result: UI_StructuredText {
            idc = 1101;
            x = UI_X(5.5);
            y = UI_Y(1.7);
            w = UI_W(29);
            h = UI_H(2.2);
        };
        // secondary line (all MVP titles in one row) and the 6-column leaderboard: small like vanilla lobby tables
        class SC_Mvps: UI_StructuredText {
            idc = 1102;
            size = UI_TEXT_SMALL;
            x = UI_X(5.5);
            y = UI_Y(4);
            w = UI_W(29);
            h = UI_H(1);
        };
        // the killfeed's kill info: longest kills (one line each) and most kills in a row, inside the result panel (its
        // body reaches down to 8.3; the leaderboard and the vote start below it)
        class SC_KillInfo: UI_StructuredText {
            idc = 1103;
            size = UI_TEXT_SMALL;
            x = UI_X(5.5);
            y = UI_Y(5);
            w = UI_W(29);
            h = UI_H(2.6);
        };
        class SC_Stats: UI_ListN {
            idc = 1500;
            sizeEx = UI_TEXT_SMALL;
            columns[] = {0, 0.3, 0.44, 0.58, 0.72, 0.86};
            x = UI_X(1);
            y = UI_Y(10.2);
            w = UI_W(16);
            h = UI_H(12.8);
        };
        class SC_Votes: UI_List {
            idc = 1501;
            onLBSelChanged = "_this call SC_fnc_onMapVoteSelected";
            x = UI_X(27);
            y = UI_Y(10.2);
            w = UI_W(12);
            h = UI_H(11.6);
        };
        class SC_VoteStatus: UI_Text {
            idc = 1104;
            x = UI_X(27);
            y = UI_Y(21.9);
            w = UI_W(12);
        };
    };
};

// ---- stored loadouts ----

class loadoutDialog {
    idd = 3001;
    onLoad = "uiNamespace setVariable [""SC_var_loadoutDialog"", _this select 0]; call SC_fnc_setupLoadoutDialog;";

    class ControlsBackground {
        SC_DIALOG_FRAME(3, 3.25, 34, 17.5, "Change Loadout")
    };

    class Controls {
        class SC_Load: UI_Button {
            idc = 1600;
            text = "Load Loadout";
            onButtonClick = "call SC_fnc_loadLoadout";
            x = UI_X(3.5);
            y = UI_Y(4.75);
            w = UI_W(10.9);
        };
        class SC_Store: UI_Button {
            idc = 1601;
            text = "Overwrite Loadout";
            onButtonClick = "call SC_fnc_storeLoadout";
            x = UI_X(14.5);
            y = UI_Y(4.75);
            w = UI_W(10.9);
        };
        class SC_Delete: UI_Button {
            idc = 1602;
            text = "Delete Loadout";
            onButtonClick = "call SC_fnc_deleteLoadout";
            x = UI_X(25.5);
            y = UI_Y(4.75);
            w = UI_W(10.9);
        };
        class SC_Table: SC_ControlsTable {
            idc = 1500;
            x = UI_X(3.5);
            y = UI_Y(6.25);
            w = UI_W(33);
            h = UI_H(15);

            class RowTemplate {
                SC_TABLE_COLUMN(RowBackground, "SC_TableButton", 0, 33, SC_ROW_H)
                SC_TABLE_COLUMN(Weapon_1, "SC_TablePicture", 0, 3.96, SC_ROW_H)
                SC_TABLE_COLUMN(Weapon_2, "SC_TablePicture", 3.96, 3.96, SC_ROW_H)
                SC_TABLE_COLUMN(Weapon_3, "SC_TablePicture", 7.92, 3.96, SC_ROW_H)
                SC_TABLE_COLUMN(Uniform, "SC_TablePicture", 11.88, 1.98, SC_ROW_H)
                SC_TABLE_COLUMN(Headgear, "SC_TablePicture", 13.86, 1.98, SC_ROW_H)
                SC_TABLE_COLUMN(Vest, "SC_TablePicture", 15.84, 1.98, SC_ROW_H)
                SC_TABLE_COLUMN(Backpack, "SC_TablePicture", 17.82, 1.98, SC_ROW_H)
                SC_TABLE_COLUMN(Perks, "SC_TableTextSmall", 19.8, 13.2, SC_ROW_H)
            };
            class HeaderTemplate {
                SC_TABLE_COLUMN(RowBackground, "SC_TableText", 0, 33, UI_ROW)
                SC_TABLE_COLUMN(Weapon_1, "SC_TableText", 0, 3.96, UI_ROW)
                SC_TABLE_COLUMN(Weapon_2, "SC_TableText", 3.96, 3.96, UI_ROW)
                SC_TABLE_COLUMN(Weapon_3, "SC_TableText", 7.92, 3.96, UI_ROW)
                SC_TABLE_COLUMN(Apparel, "SC_TableText", 11.88, 7.92, UI_ROW)
                SC_TABLE_COLUMN(Perks, "SC_TableText", 19.8, 13.2, UI_ROW)
            };
        };
    };
};

// ---- equipment by rank / perk ----

#define SC_CATEGORY_BUTTON(PIDC, PTEXT, PCATEGORY, PX, PY, PW) \
    class SC_Category##PIDC: UI_Button { \
        idc = PIDC; \
        text = PTEXT; \
        onButtonClick = SC_QUOTE([PCATEGORY] spawn SC_fnc_setupEquipmentDialog); \
        x = UI_X(PX); \
        y = UI_Y(PY); \
        w = UI_W(PW); \
    };

class equipmentDialog {
    idd = 3001;
    onLoad = "uiNamespace setVariable [""SC_var_equipmentDialog"", _this select 0]; [""general""] spawn SC_fnc_setupEquipmentDialog;";

    class ControlsBackground {
        SC_DIALOG_FRAME(8, SC_TALL_DIALOG_Y, 24, SC_TALL_DIALOG_H - UI_ROW, "Equipment")
    };

    class Controls {
        // menu button texts are structured text: "&" must be written "&amp;" (a bare "&" showed up as "?")
        SC_CATEGORY_BUTTON(1600, "General Equipment", 'general', 8.5, SC_TALL_DIALOG_TOP, 11.45)
        SC_CATEGORY_BUTTON(1610, "Vehicles &amp; Aircraft", 'vehicles', 20.05, SC_TALL_DIALOG_TOP, 11.45)
        // perks in rank order, 2 rows x 5 in the 23 cells between the paddings: w = (23 - 4 * UI_GAP) / 5 = 4.52,
        // x = 8.5 + n * 4.62, rows UI_ROW + UI_GAP apart; labelled with the abbreviation (SC_fnc_setupEquipmentDialog
        // adds name and rank as tooltip)
        SC_CATEGORY_BUTTON(1602, "EXPR", 'experience', 8.5, SC_TALL_DIALOG_TOP + 1.1, 4.52)
        SC_CATEGORY_BUTTON(1603, "MEDC", 'medic', 13.12, SC_TALL_DIALOG_TOP + 1.1, 4.52)
        SC_CATEGORY_BUTTON(1609, "STAM", 'stamina', 17.74, SC_TALL_DIALOG_TOP + 1.1, 4.52)
        SC_CATEGORY_BUTTON(1601, "MRKS", 'marksman', 22.36, SC_TALL_DIALOG_TOP + 1.1, 4.52)
        SC_CATEGORY_BUTTON(1605, "MGNR", 'machinegunner', 26.98, SC_TALL_DIALOG_TOP + 1.1, 4.52)
        SC_CATEGORY_BUTTON(1606, "LNCR", 'launcher', 8.5, SC_TALL_DIALOG_TOP + 2.2, 4.52)
        SC_CATEGORY_BUTTON(1607, "ARMR", 'armor', 13.12, SC_TALL_DIALOG_TOP + 2.2, 4.52)
        SC_CATEGORY_BUTTON(1608, "GRND", 'grenadier', 17.74, SC_TALL_DIALOG_TOP + 2.2, 4.52)
        SC_CATEGORY_BUTTON(1612, "DEMO", 'explosives', 22.36, SC_TALL_DIALOG_TOP + 2.2, 4.52)
        SC_CATEGORY_BUTTON(1604, "SUPR", 'suppressor', 26.98, SC_TALL_DIALOG_TOP + 2.2, 4.52)

        // the table takes the remaining height
        class SC_Table: SC_ControlsTable {
            idc = 1611;
            x = UI_X(8.5);
            y = UI_Y(SC_TALL_DIALOG_TOP + 3.7);
            w = UI_W(23);
            h = UI_H(SC_TALL_DIALOG_CONTENT_H - 3.7);

            class RowTemplate {
                SC_TABLE_COLUMN(RowBackground, "SC_TableText", 0, 23, SC_ROW_H)
                SC_TABLE_COLUMN(Picture, "SC_TablePicture", 0, 4.6, SC_ROW_H)
                SC_TABLE_COLUMN(Name, "SC_TableText", 4.6, 13.8, SC_ROW_H)
                SC_TABLE_COLUMN(Rank, "SC_TableText", 18.4, 4.6, SC_ROW_H)
            };
            class HeaderTemplate {
                SC_TABLE_COLUMN(RowBackground, "SC_TableText", 0, 23, UI_ROW)
                SC_TABLE_COLUMN(Picture, "SC_TableText", 0, 4.6, UI_ROW)
                SC_TABLE_COLUMN(Name, "SC_TableText", 4.6, 13.8, UI_ROW)
                SC_TABLE_COLUMN(Rank, "SC_TableText", 18.4, 4.6, UI_ROW)
            };
        };
    };
};

#include "..\ui\groupMenu.hpp"

// ---- perks ----

// one row per perk slot: label and combo. The label is the body text block (UI_Text) in the large size; when the dialog
// opens, SC_fnc_fitPerkDialog makes the labels as wide as the widest text and puts the combos UI_GAP behind them (no
// empty space on the left). The combo is centred on the 1.2 high label, rows 0.5 apart. The dialog is centred
// vertically (body height = 6 rows - the last space + the paddings). Label idcs 1102 - 1107 (1002 is the title).
#define SC_PERK_ROW_H 1.7
#define SC_PERK_LABEL_W 3.5
#define SC_PERK_COMBO_X (12.5 + SC_PERK_LABEL_W + UI_GAP)
#define SC_PERK_COMBO_W (15 - SC_PERK_LABEL_W - UI_GAP)
#define SC_PERK_BODY_H (6 * SC_PERK_ROW_H - 0.5 + 2 * UI_PADDING)
#define SC_PERK_DIALOG_Y ((25 - UI_ROW - SC_PERK_BODY_H) / 2)
#define SC_PERK_ROW_Y(PROW) (SC_PERK_DIALOG_Y + UI_ROW + UI_PADDING + (PROW) * SC_PERK_ROW_H)

#define SC_PERK_LABEL(PIDC, PTEXT, PROW) \
    class SC_PerkLabel##PIDC: UI_Text { \
        idc = PIDC; \
        sizeEx = UI_TEXT_LARGE; \
        text = PTEXT; \
        x = UI_X(12.5); \
        y = UI_Y(SC_PERK_ROW_Y(PROW)); \
        w = UI_W(SC_PERK_LABEL_W); \
        h = UI_H(1.2); \
    };

class perkDialog {
    idd = 3002;
    onLoad = "uiNamespace setVariable [""SC_var_perkDialog"", _this select 0]; call SC_fnc_setupPerkDialog;";

    class ControlsBackground {
        SC_DIALOG_FRAME(12, SC_PERK_DIALOG_Y, 16, SC_PERK_BODY_H, "Perks")
    };

    class Controls {
        SC_PERK_LABEL(1102, "Perk 1", 0)
        class SC_PerkCombo2100: UI_Combo {
            idc = 2100;
            onLBSelChanged = "[0, (_this select 1)] call SC_fnc_changePerk;";
            x = UI_X(SC_PERK_COMBO_X);
            y = UI_Y(SC_PERK_ROW_Y(0) + 0.1);
            w = UI_W(SC_PERK_COMBO_W);
        };
        SC_PERK_LABEL(1103, "Perk 2", 1)
        class SC_PerkCombo2101: UI_Combo {
            idc = 2101;
            onLBSelChanged = "[1, (_this select 1)] call SC_fnc_changePerk;";
            x = UI_X(SC_PERK_COMBO_X);
            y = UI_Y(SC_PERK_ROW_Y(1) + 0.1);
            w = UI_W(SC_PERK_COMBO_W);
        };
        SC_PERK_LABEL(1104, "Perk 3", 2)
        class SC_PerkCombo2102: UI_Combo {
            idc = 2102;
            onLBSelChanged = "[2, (_this select 1)] call SC_fnc_changePerk;";
            x = UI_X(SC_PERK_COMBO_X);
            y = UI_Y(SC_PERK_ROW_Y(2) + 0.1);
            w = UI_W(SC_PERK_COMBO_W);
        };
        SC_PERK_LABEL(1105, "Perk 4", 3)
        class SC_PerkCombo2103: UI_Combo {
            idc = 2103;
            onLBSelChanged = "[3, (_this select 1)] call SC_fnc_changePerk;";
            x = UI_X(SC_PERK_COMBO_X);
            y = UI_Y(SC_PERK_ROW_Y(3) + 0.1);
            w = UI_W(SC_PERK_COMBO_W);
        };
        SC_PERK_LABEL(1106, "Perk 5", 4)
        class SC_PerkCombo2104: UI_Combo {
            idc = 2104;
            onLBSelChanged = "[4, (_this select 1)] call SC_fnc_changePerk;";
            x = UI_X(SC_PERK_COMBO_X);
            y = UI_Y(SC_PERK_ROW_Y(4) + 0.1);
            w = UI_W(SC_PERK_COMBO_W);
        };
        SC_PERK_LABEL(1107, "Perk 6", 5)
        class SC_PerkCombo2105: UI_Combo {
            idc = 2105;
            onLBSelChanged = "[5, (_this select 1)] call SC_fnc_changePerk;";
            x = UI_X(SC_PERK_COMBO_X);
            y = UI_Y(SC_PERK_ROW_Y(5) + 0.1);
            w = UI_W(SC_PERK_COMBO_W);
        };
    };
};

// ---- respawn map and spectator (displays over the main display) ----

// These two keep their own look on purpose: they sit on top of the vanilla respawn screen and copy its style
// (orange button, PuristaLight, white on hover) instead of the UI_* blocks; layout as the original GUI editor export.
// as the original local RscButton copy: no text outline (the vanilla RscButton has shadow 2), fixed size, menu sounds
class SC_RespawnStyleButton: RscButton {
    style = ST_CENTER;
    font = "PuristaLight";
    sizeEx = 0.04;
    shadow = 0;
    soundEnter[] = {"\A3\ui_f\data\sound\RscButtonMenu\soundEnter", 0.09, 1};
    soundPush[] = {"\A3\ui_f\data\sound\RscButtonMenu\soundPush", 0.09, 1};
    soundClick[] = {"\A3\ui_f\data\sound\RscButtonMenu\soundClick", 0.09, 1};
    soundEscape[] = {"\A3\ui_f\data\sound\RscButtonMenu\soundEscape", 0.09, 1};
    colorFocused[] = {0.6484375, 0.44140625, 0.08984375, 0.95};
    colorFocusedSecondary[] = {0.6484375, 0.44140625, 0.08984375, 0.95};
    colorBackground[] = {0.6484375, 0.44140625, 0.08984375, 0.95};
    colorFocused2[] = {0.6484375, 0.44140625, 0.08984375, 0.95};
    colorBackgroundActive[] = {1, 1, 1, 1};
    colorActive[] = {0, 0, 0, 1};
    colorTextActive[] = {0, 0, 0, 1};
    colorText[] = {1, 1, 1, 1};
    onMouseEnter = "(_this select 0) ctrlSetTextColor [0, 0, 0, 1];";
    onMouseExit = "(_this select 0) ctrlSetTextColor [1, 1, 1, 1];";
};

class SC_RespawnStylePanel: RscText {
    colorBackground[] = {0.1, 0.1, 0.1, 0.7};
};

class respawnMapDisplay {
    idd = 5000;
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "uiNamespace setVariable [""SC_var_respawnMapDisplay"", _this select 0]";

    class Controls {
        class SC_Panel: SC_RespawnStylePanel {
            idc = 1000;
            x = 0.4175 * safezoneW + safezoneX;
            y = 0.709 * safezoneH + safezoneY;
            w = 0.165 * safezoneW;
            h = 0.077 * safezoneH;
        };
        class SC_Spectate: SC_RespawnStyleButton {
            idc = 1600;
            text = "SPECTATE";
            onButtonClick = "[] spawn SC_fnc_spectate;";
            x = 0.422656 * safezoneW + safezoneX;
            y = 0.72 * safezoneH + safezoneY;
            w = 0.154687 * safezoneW;
            h = 0.055 * safezoneH;
        };
    };
};

class spectatorDisplay {
    idd = 5000;
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "uiNamespace setVariable [""SC_var_spectatorDisplay"", _this select 0]";

    class Controls {
        // the button row split in two: open map (back to the respawn menu) | respawn at the spectated group member
        class SC_ButtonPanel: SC_RespawnStylePanel {
            idc = 1000;
            x = 0.395 * safezoneW + safezoneX;
            y = 0.918 * safezoneH + safezoneY;
            w = 0.21 * safezoneW;
            h = 0.077 * safezoneH;
        };
        class SC_OpenMap: SC_RespawnStyleButton {
            idc = 1600;
            text = "OPEN MAP";
            onButtonClick = "(uiNamespace getVariable ""SC_var_spectatorDisplay"") closeDisplay 1;";
            x = 0.400156 * safezoneW + safezoneX;
            y = 0.929 * safezoneH + safezoneY;
            w = 0.0974 * safezoneW;
            h = 0.055 * safezoneH;
        };
        // enabled by SC_fnc_spectate once the respawn delay is over and the spectated unit is a respawn position
        class SC_RespawnHere: SC_RespawnStyleButton {
            idc = 1601;
            text = "RESPAWN HERE";
            onButtonClick = "call SC_fnc_respawnHere;";
            x = 0.502556 * safezoneW + safezoneX;
            y = 0.929 * safezoneH + safezoneY;
            w = 0.0974 * safezoneW;
            h = 0.055 * safezoneH;
        };
        class SC_UnitPanel: SC_RespawnStylePanel {
            idc = 1001;
            x = 0.432969 * safezoneW + safezoneX;
            y = 0.874 * safezoneH + safezoneY;
            w = 0.134062 * safezoneW;
            h = 0.044 * safezoneH;
        };
        class SC_Unit: RscCombo {
            idc = 2100;
            x = 0.438125 * safezoneW + safezoneX;
            y = 0.885 * safezoneH + safezoneY;
            w = 0.12375 * safezoneW;
            h = 0.022 * safezoneH;
        };
    };
};
