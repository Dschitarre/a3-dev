/*
    Shared dialog / HUD building blocks for all game modes, in the vanilla Arma 3 look.
    The build copies src\shared\ui into each mission as ui\ (cfg\sharedLibs.txt: ui|ui).
    Include it once at the top of Description.ext:  #include "ui\ui.hpp"

    The colors follow the player's own settings (Options > Game > Colors / Layout), exactly like the vanilla menus:
        accent (title bars, selection, progress)  GUI_BCG_RGB_*       orange with the default "Arma 3" preset, green with "Apex", ...
        title text                                GUI_TITLETEXT_RGB_*
        HUD panels                                IGUI_BCG_RGB_*, warning/error IGUI_WARNING/ERROR_RGB_*
    except the HUD text (pure white) and the side colors (a fixed palette shared with the
    mods, UI_COLOR_BLUFOR ... below, ui.sqf).
    Positions and sizes use the BI GUI grid (40 x 25 cells, GUI_GRID_*), so dialogs scale with the interface size option.
    Scripted UI (structured text, drawIcon, ctrlSetBackgroundColor) gets the same colors from ui\ui.sqf.

    Layout rules (vanilla):
        title bar 1 cell high directly above the body, body panel, then a 0.1 cell gap and a 1 cell button row;
        0.5 cell padding inside panels, 0.1 cell gap between neighbouring controls.

    Fonts and text sizes per role, as in the vanilla menus (pause menu, options, controls, lobby, arsenal, field manual);
    the blocks inherit them from the vanilla classes, so a dialog normally sets no font and no sizeEx:
        title bar        UI_Title (RscTitle)            PuristaMedium, UI_TEXT, text as written (Title Case)
        buttons          UI_Button* (RscButtonMenu)     PuristaLight, UI_TEXT, drawn in UPPER CASE by the button style
        labels, content  UI_Text, lists, combo, edit    RobotoCondensed, UI_TEXT (labels in front of a value end with ":")
        structured text  UI_StructuredText              RobotoCondensed, UI_TEXT; headings in it
                                                        <t font='RobotoCondensedBold' size='1.2'>
        secondary/dense  UI_TextSmall                   RobotoCondensed, UI_TEXT_SMALL: stat labels, many-column tables,
                                                        side info (vanilla lobby / server browser / arsenal stats)
        HUD              UI_HudText                     RobotoCondensed, UI_TEXT_SMALL (vanilla IGUI text size)
        screen texts     UI_ScreenText                  RobotoCondensed, UI_TEXT_SCREEN: the plain texts on the screen
                                                        (leaderboards, centered messages, ...), shown by script with
                                                        UI_fnc_showTextBlocks (ui.sqf); headings in them
                                                        <t font='RobotoCondensedBold' size='1.4'>
        tooltips         engine (CfgInGameUI)           RobotoCondensed, UI_TEXT_SMALL
    Sizes: UI_TEXT_SMALL (0.8, also UI_TEXT_SCREEN: HUD and screen texts alike) / UI_TEXT (1) / UI_TEXT_LARGE (1.2 cells),
    a font needs a control at least as high.
*/
#include "\a3\ui_f\hpp\defineCommon.inc"
#include "\a3\ui_f\hpp\defineResincl.inc"   // ST_* / CT_* / IDC constants (guarded, safe to include more than once)

// ---- vanilla base classes, imported from the game config instead of copied ----
import RscText;
import RscTitle;
import RscStructuredText;
import RscPicture;
import RscPictureKeepAspect;
import RscEdit;
import RscCombo;
import RscListBox;
import RscListNBox;
import RscTree;
import RscCheckBox;
import RscButton;
import RscButtonMenu;
import RscButtonMenuOK;
import RscButtonMenuCancel;
import RscControlsGroup;
import RscControlsGroupNoScrollbars;
import RscMapControl;
import RscProgress;
import RscXSliderH;
import RscToolbox;
import RscFrame;

// ---- layout (grid units -> screen) ----
#define UI_W(n)                 ((n) * GUI_GRID_W)
#define UI_H(n)                 ((n) * GUI_GRID_H)
#define UI_X(n)                 ((n) * GUI_GRID_W + GUI_GRID_CENTER_X)     // n cells from the left edge of the centered 40 x 25 area
#define UI_Y(n)                 ((n) * GUI_GRID_H + GUI_GRID_CENTER_Y)     // n cells from its top edge
#define UI_GAP                  0.1                                        // cells between title/body/buttons and neighbouring controls
#define UI_PADDING              0.5                                        // cells between a panel edge and its content
#define UI_ROW                  1                                          // cells, standard control and title height

#define UI_TEXT_SMALL           GUI_TEXT_SIZE_SMALL
#define UI_TEXT_SCREEN          UI_TEXT_SMALL                              // every plain screen text, as large as the HUD texts (read by ui.sqf)
#define UI_TEXT                 GUI_TEXT_SIZE_MEDIUM
#define UI_TEXT_LARGE           GUI_TEXT_SIZE_LARGE

// ---- colors ----
#define UI_COLOR_ACCENT         GUI_BCG_COLOR
#define UI_COLOR_ACCENT_DIM     GUI_BCG_COLOR_SELECTED
#define UI_COLOR_TITLE_TEXT     GUI_TITLETEXT_COLOR
#define UI_COLOR_PANEL          {0, 0, 0, 0.7}         // dialog body (vanilla GUI_BCG_MENU)
#define UI_COLOR_FIELD          {0, 0, 0, 0.4}         // lists, edit fields, inner panels on the body; never stack a
                                                       // third layer
#define UI_COLOR_TEXT           {1, 1, 1, 1}
#define UI_COLOR_TEXT_DIM       {1, 1, 1, 0.5}
#define UI_COLOR_DISABLED       {1, 1, 1, 0.25}
#define UI_COLOR_HUD_PANEL      IGUI_BCG_COLOR
#define UI_COLOR_HUD_TEXT       {1, 1, 1, 1}           // pure white (not the transparent IGUI_TEXT)
#define UI_COLOR_WARNING        IGUI_WARNING_COLOR
#define UI_COLOR_ERROR          IGUI_ERROR_COLOR
// HUD bars with a fill level: grey on the HUD panel, only the player's health green (same as ui.sqf
// "barFill" / "health")
#define UI_COLOR_BAR_FILL       {0.3, 0.3, 0.3, 0.55}
#define UI_COLOR_HEALTH         {0, 0.8, 0, 0.55}
// side colors: a fixed palette (same as ui.sqf, mapmarker, tdicons, killfeed), not the player's map color settings
#define UI_COLOR_BLUFOR         {0, 0.5, 1, 1}
#define UI_COLOR_OPFOR          {1, 0, 0, 1}
#define UI_COLOR_INDEPENDENT    {0, 0.8, 0.27, 1}
#define UI_COLOR_CIVILIAN       {0.75, 0.75, 0.75, 1}

// ---- building blocks: derive every dialog control from these ----
class UI_Text: RscText {
    font = GUI_FONT_NORMAL;
    sizeEx = UI_TEXT;
    colorText[] = UI_COLOR_TEXT;
    h = UI_H(UI_ROW);
};

class UI_TextSmall: UI_Text {
    sizeEx = UI_TEXT_SMALL;
};

// vanilla title bar font (RscTitle: PuristaMedium, UI_TEXT), not the RobotoCondensed of the body text
class UI_Title: RscTitle {
    colorBackground[] = UI_COLOR_ACCENT;
    colorText[] = UI_COLOR_TITLE_TEXT;
    h = UI_H(UI_ROW);
};

class UI_Panel: RscText {
    colorBackground[] = UI_COLOR_PANEL;
};

class UI_Field: RscText {
    colorBackground[] = UI_COLOR_FIELD;
};

class UI_StructuredText: RscStructuredText {
    size = UI_TEXT;

    class Attributes {
        font = GUI_FONT_NORMAL;
        color = "#ffffff";
        align = "left";
        shadow = 1;
    };
};

class UI_Picture: RscPicture {};
class UI_PictureKeepAspect: RscPictureKeepAspect {};

class UI_Button: RscButtonMenu {
    h = UI_H(UI_ROW);
};

class UI_ButtonOK: RscButtonMenuOK {
    h = UI_H(UI_ROW);
};

class UI_ButtonCancel: RscButtonMenuCancel {
    h = UI_H(UI_ROW);
};

class UI_List: RscListBox {
    sizeEx = UI_TEXT;
    colorBackground[] = UI_COLOR_FIELD;
    colorSelectBackground[] = UI_COLOR_ACCENT;
    colorSelectBackground2[] = UI_COLOR_ACCENT_DIM;
};

class UI_ListN: RscListNBox {
    sizeEx = UI_TEXT;
    colorBackground[] = UI_COLOR_FIELD;
    colorSelectBackground[] = UI_COLOR_ACCENT;
    colorSelectBackground2[] = UI_COLOR_ACCENT_DIM;
};

class UI_Tree: RscTree {
    sizeEx = UI_TEXT;
    colorBackground[] = UI_COLOR_FIELD;
};

class UI_Combo: RscCombo {
    sizeEx = UI_TEXT;
    h = UI_H(UI_ROW);
};

class UI_Edit: RscEdit {
    sizeEx = UI_TEXT;
    colorBackground[] = UI_COLOR_FIELD;
    h = UI_H(UI_ROW);
};

class UI_CheckBox: RscCheckBox {
    w = UI_W(UI_ROW);
    h = UI_H(UI_ROW);
};

class UI_Slider: RscXSliderH {
    h = UI_H(UI_ROW);
};

class UI_Progress: RscProgress {
    colorBar[] = UI_COLOR_ACCENT;
    colorFrame[] = {0, 0, 0, 0};
};

class UI_Toolbox: RscToolbox {
    sizeEx = UI_TEXT;
    colorBackground[] = UI_COLOR_FIELD;
    colorSelectedBg[] = UI_COLOR_ACCENT;
};

class UI_Group: RscControlsGroup {};
class UI_GroupNoScrollbars: RscControlsGroupNoScrollbars {};
class UI_Map: RscMapControl {};
class UI_Frame: RscFrame {};

// HUD (RscTitles) elements: transparent panel and text in the player's HUD colors
class UI_HudPanel: RscText {
    colorBackground[] = UI_COLOR_HUD_PANEL;
};

class UI_HudText: UI_Text {
    sizeEx = UI_TEXT_SMALL;
    colorText[] = UI_COLOR_HUD_TEXT;
    shadow = 1;
};

// plain screen texts (white with shadow, UI_TEXT_SCREEN), created by UI_fnc_showTextBlocks (ui.sqf) on a UI_HudPanel
class UI_ScreenText: UI_StructuredText {
    size = UI_TEXT_SCREEN;
};

#include "settings.hpp"
