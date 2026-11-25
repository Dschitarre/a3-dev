// AIS progress bar with title (revive, stabilize, ...) as a dialog, in the player's HUD / accent colors (ui\ui.hpp).
class AIS_Core_Progress_BarDlg {
    idd = -1;
    movingEnable = 0;
    onLoad = "uiNamespace setVariable ['AIS_Core_Progress_ProgressBar', (_this select 0) displayCtrl 1]; uiNamespace setVariable ['AIS_Core_Progress_ProgressTitle', (_this select 0) displayCtrl 2];";

    class ControlsBackground {
        // the AIS scripts animate the bar width with the same safezone geometry
        class Background: UI_HudPanel {
            x = 0.298906 * safeZoneW + safeZoneX;
            y = 0.082 * safeZoneH + safeZoneY;
            w = 0.407344 * safeZoneW;
            h = 0.011 * safeZoneH;
        };
        class ProgressBar: UI_HudText {
            idc = 1;
            style = ST_CENTER;
            colorBackground[] = UI_COLOR_ACCENT;
            x = 0.298906 * safeZoneW + safeZoneX;
            y = 0.082 * safeZoneH + safeZoneY;
            w = 0.001 * safeZoneW;
            h = 0.011 * safeZoneH;
        };
        class TitleBar: UI_HudText {
            idc = 2;
            style = ST_LEFT;
            x = 0.298906 * safeZoneW + safeZoneX;
            y = 0.093 * safeZoneH + safeZoneY;
            w = 0.407344 * safeZoneW;
            h = 0.022 * safeZoneH;
        };
    };
};
