// AIS bleeding effects: bleeding, bleed-out camera and unconscious HUD (client), blood splatter on screen, bullet impact.
// AIS revive system by Psychobastard, consolidated; loaded by the game mode (SC\init\common.sqf) after AIS\setup.sqf.

/*
 * Author: Psycho
 * Visual bleeding effects and counter for revive time. Will self-run in a loop till unit get revived/stabilized or died.
 * Arguments:
    0: Unit (Object)
    1: Revive Time (Number)
 * Return value:
    -
*/
AIS_Effects_fnc_bleeding = {
    params ["_unit", "_revive_time"];

    // breack out if unit died or revived
    if (!alive _unit || {!(_unit getVariable ["ais_unconscious", false])}) exitWith {};

    // breack out if unit get stabilized
    if (_unit getVariable ["ais_stabilized", false]) exitWith {
        _unit setBleedingRemaining 10;

        // loop
        private _acc_time = diag_tickTime + 1.5;
        [{diag_tickTime >=(_this select 1)}, {_this call AIS_Effects_fnc_stabil},
            [_unit, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
    };

    // get the revive time
    _revive_time = [_unit] call AIS_System_fnc_calculateLifeTime;
    _unit setBleedingRemaining _revive_time;

    private _timeleft = AIS_BLEEDOUT_TIME - (time - ais_start_unc_time);

    // to late
    if (_timeleft <= 0) exitWith {
        [_unit, objNull, objNull] call AIS_Damage_fnc_goToDead;
        _unit setDamage 1;
    };

    [_unit] call AIS_Effects_fnc_startUnconsciousView;

    _unit setFatigue 1;

    // loop
    private _acc_time = diag_tickTime + 1;
    [{diag_tickTime >=(_this select 2)}, {_this call AIS_Effects_fnc_bleeding},
        [_unit, _revive_time, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
};

// The unconscious view: the bleed-out camera above the player and the HUD with the respawn key (Space). Called on every
// pass of the bleeding and the stabilized loop; it starts them once, but not during the kill cam of the going down
// (killfeed): the next pass after it starts them, and the respawn key can't fire with the key that skipped the kill cam.
AIS_Effects_fnc_startUnconsciousView = {
    params ["_unit"];

    if (!AIS_SHOW_COUNTDOWN || {!isNull AIS_BleedoutCameraScript} || {missionNamespace getVariable ["KF_var_killCamActive", false]}) exitWith {};

    terminate AIS_var_unconsciousHudScript;
    AIS_var_unconsciousHudScript = [_unit] spawn AIS_Effects_fnc_unconsciousHud;

    AIS_BleedoutCameraScript = [] spawn {
        _oldNvgoggles = SC_var_nvGogglesEnabled;
        _camera = "camera" camCreate (getPosATL player);
        _camera cameraEffect ["internal", "back"];
        _camera camSetFOV 0.5;
        showCinemaBorder true;
        SC_var_nvGogglesEnabled = _oldNvgoggles;
        SC_var_forcedMap = false;
        camUseNVG SC_var_nvGogglesEnabled;

        call {
            if (SC_var_alwaysShowHudWhenUnconscious && !SC_var_hudEnabled && !SC_var_hudShown) then {
                [true] call SC_fnc_setHud;
            };
        };

        _syncGpsEnabledLoopScript = [] spawn {
            disableSerialization;

            _gpsCtrl = (findDisplay 46) ctrlCreate ["RscMapControl", -420];
            _gpsCtrl ctrlAddEventHandler ["Draw", {
                params ["_display"];

                uiNamespace setVariable ["MM_var_currentDisplay", _display];
                MM_var_showUnitNamesOverride = false;

                if !MM_var_gpsOpened then {
                    MM_var_gpsOpened = true;

                    if !(scriptDone MM_var_updateDrawArrayScript) then {
                        terminate MM_var_updateDrawArrayScript;
                        MM_var_updateDrawArrayScript = scriptNull;
                    };

                    [false] call MM_fnc_updateDrawArray;
                };

                [_display] call MM_fnc_drawIcons;
            }];
            uiNamespace setVariable ["SC_var_customGPS", _gpsCtrl];
            _gpsCtrl ctrlMapSetPosition [1.4, 0.6, 0.295, 0.37];
            _gpsCtrl ctrlCommit 0;

            waitUntil {
                _gpsCtrl ctrlMapAnimAdd [0, (0.06 * SC_var_mapZoomFactor), player];
                ctrlMapAnimCommit _gpsCtrl;

                false
            };
        };

        _keyDownEhId = (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_key"];

            if ((_key in (actionKeys "nightVision")) || {_key in (actionKeys "TransportNightVision")}) then {
                SC_var_nvGogglesEnabled = !SC_var_nvGogglesEnabled;

                camUseNVG SC_var_nvGogglesEnabled;
                player action [(["nvGogglesOff", "nvGoggles"] select SC_var_nvGogglesEnabled), player];

                {
                    false setCamUseTI _x;
                } forEach [0, 1, 2, 3, 4, 5, 6, 7];

                true
            };
        }];

        waitUntil {
            _pelvisPos = ASLToATL (player modelToWorldVisualWorld (player selectionPosition "pelvis"));
            _camera camSetPos (_pelvisPos vectorAdd [0.01, 0.01, 5]);
            _camera camSetTarget _pelvisPos;
            _camera camCommit 0;

            (!(alive player) || {!(player getVariable ["AIS_unconscious", false])} || {player getVariable ["AIS_stabilized", false]})
        };

        if (alive player) then {
            call {
                if (!SC_var_hudEnabled && SC_var_hudShown) then {
                    [false] call SC_fnc_setHud;
                };
            };
        } else {
            // a kill cam (killfeed) starts from the dead player's own view: this camera goes at once
            if !(missionNamespace getVariable ["KF_var_killCamActive", false]) then {
                sleep 4;
            };
        };

        (findDisplay 46) displayRemoveEventHandler ["KeyDown", _keyDownEhId];
        terminate _syncGpsEnabledLoopScript;
        _gpsCtrl = uiNamespace getVariable ["SC_var_customGPS", controlNull];

        if !(isNull _gpsCtrl) then {
            ctrlDelete _gpsCtrl;
        };

        uiNamespace setVariable ["SC_var_customGPS", controlNull];
        _camera cameraEffect ["terminate", "back"];
        camDestroy _camera;
        player action [(["nvGogglesOff", "nvGoggles"] select SC_var_nvGogglesEnabled), player];

        AIS_BleedoutCameraScript = scriptNull;
    };
};

// ---- unconscious HUD (client): bleed-out bar, help status, respawn hint ----
// One-row panels in the vanilla HUD look (ui\ui.hpp UI_HudPanel / UI_HudText), created once per unconscious state on
// the mission display (visible while AIS hides the HUD) and then only updated. Sizes in cells of the vanilla GUI grid
// (40 x 25, scales with the interface size); a column centered at the bottom of the screen, clear of the SC HUD.
AIS_var_hudWidth = 16;
AIS_var_hudTextWidth = 7.5;         // "Bleeding out (100 %)", the bar fills the rest of the row
AIS_var_hudPadding = 0.25;          // inside the panels (rows are only one cell high)
AIS_var_hudGap = 0.1;               // between the panels (UI_GAP)
AIS_var_hudBottomMargin = 1.5;      // below the lowest panel
AIS_var_hudUpdateInterval = 0.5;    // seconds

// [cell width, cell height] of the vanilla GUI grid (GUI_GRID_W / GUI_GRID_H of \a3\ui_f\hpp\defineCommon.inc)
AIS_Effects_fnc_hudGridCell = {
    private _gridWidth = (safeZoneW / safeZoneH) min 1.2;

    [_gridWidth / 40, _gridWidth / 1.2 / 25]
};

// one-row panel as a controls group: background in the player's HUD color and a small text; returns [group, text]
AIS_Effects_fnc_hudCreatePanel = {
    params ["_display", "_text", "_textWidth"];

    disableSerialization;

    (call AIS_Effects_fnc_hudGridCell) params ["_cellW", "_cellH"];

    private _width = AIS_var_hudWidth * _cellW;
    private _group = _display ctrlCreate ["UI_GroupNoScrollbars", -1];
    _group ctrlSetPosition [safeZoneX + (safeZoneW - _width) / 2, safeZoneY + safeZoneH, _width, _cellH];
    _group ctrlCommit 0;

    private _background = _display ctrlCreate ["UI_HudPanel", -1, _group];
    _background ctrlSetPosition [0, 0, _width, _cellH];
    _background ctrlCommit 0;

    private _textCtrl = _display ctrlCreate ["UI_HudText", -1, _group];
    _textCtrl ctrlSetPosition [AIS_var_hudPadding * _cellW, 0, _textWidth * _cellW, _cellH];
    _textCtrl ctrlSetText _text;
    _textCtrl ctrlCommit 0;

    [_group, _textCtrl]
};

AIS_Effects_fnc_unconsciousHudCreate = {
    disableSerialization;

    (call AIS_Effects_fnc_hudGridCell) params ["_cellW", "_cellH"];

    private _display = findDisplay 46;
    private _fullTextWidth = AIS_var_hudWidth - 2 * AIS_var_hudPadding;

    ([_display, "", AIS_var_hudTextWidth] call AIS_Effects_fnc_hudCreatePanel) params ["_bleedingGroup", "_bleedingText"];
    ([_display, "", _fullTextWidth] call AIS_Effects_fnc_hudCreatePanel) params ["_statusGroup", "_statusText"];
    ([_display, "Press space to respawn", _fullTextWidth] call AIS_Effects_fnc_hudCreatePanel) params ["_respawnGroup"];

    // bleed-out bar right of its text: dark track, red bar as wide as the remaining life
    private _barPosition = [
        (AIS_var_hudPadding + AIS_var_hudTextWidth) * _cellW,
        AIS_var_hudPadding * _cellH,
        (AIS_var_hudWidth - AIS_var_hudTextWidth - 2 * AIS_var_hudPadding) * _cellW,
        (1 - 2 * AIS_var_hudPadding) * _cellH
    ];

    private _track = _display ctrlCreate ["UI_Field", -1, _bleedingGroup];
    _track ctrlSetPosition _barPosition;
    _track ctrlCommit 0;

    private _bar = _display ctrlCreate ["UI_HudPanel", -1, _bleedingGroup];
    _bar ctrlSetBackgroundColor (if (isNil "UI_fnc_color") then {[1, 0, 0, 1]} else {["error"] call UI_fnc_color});
    _bar ctrlSetPosition _barPosition;
    _bar ctrlCommit 0;

    uiNamespace setVariable [
        "AIS_var_unconsciousHud",
        [_bleedingGroup, _statusGroup, _respawnGroup, _bleedingText, _statusText, _bar, _barPosition select 2]
    ];

    [_bleedingGroup, _statusGroup, _respawnGroup] call AIS_Effects_fnc_unconsciousHudStack;
};

// stacks the shown panels bottom up (respawn hint, help status, bleeding out); hidden panels leave no gap
AIS_Effects_fnc_unconsciousHudStack = {
    params ["_bleedingGroup", "_statusGroup", "_respawnGroup"];

    disableSerialization;

    (call AIS_Effects_fnc_hudGridCell) params ["", "_cellH"];

    private _top = safeZoneY + safeZoneH - AIS_var_hudBottomMargin * _cellH;

    {
        if (ctrlShown _x) then {
            _top = _top - _cellH;
            _x ctrlSetPositionY _top;
            _x ctrlCommit 0;
            _top = _top - AIS_var_hudGap * _cellH;
        };
    } forEach [_respawnGroup, _statusGroup, _bleedingGroup];
};

// updates texts and bar width in place; _remaining: share of the bleed-out time left (0..1)
AIS_Effects_fnc_unconsciousHudUpdate = {
    params ["_unit", "_remaining"];

    disableSerialization;

    (uiNamespace getVariable ["AIS_var_unconsciousHud", []]) params [
        ["_bleedingGroup", controlNull],
        "_statusGroup",
        "_respawnGroup",
        "_bleedingText",
        "_statusText",
        "_bar",
        "_barWidth"
    ];

    if (isNull _bleedingGroup) exitWith {};

    // the bleed-out timer stops while stabilized
    private _bleeding = !(_unit getVariable ["ais_stabilized", false]);

    if (_bleeding) then {
        private _text = "Bleeding out (" + (str (round (_remaining * 100))) + " %)";

        if ((ctrlText _bleedingText) != _text) then {
            _bleedingText ctrlSetText _text;
        };

        _bar ctrlSetPositionW (_barWidth * _remaining);
        _bar ctrlCommit 0;
    };

    // nothing while someone treats the unit
    private _helper = _unit getVariable ["ais_hasHelper", objNull];
    private _plannedHelper = _unit getVariable ["AIS_plannedHelper", objNull];
    private _status = switch true do {
        case (!isNull _helper): {""};
        case (isNull _plannedHelper): {"There is no medic nearby"};
        default {"An AI medic is coming: " + (str (round (_unit distance _plannedHelper))) + "m"};
    };

    if ((ctrlText _statusText) != _status) then {
        _statusText ctrlSetText _status;
    };

    if ((ctrlShown _bleedingGroup) isNotEqualTo _bleeding || {(ctrlShown _statusGroup) isNotEqualTo (_status != "")}) then {
        _bleedingGroup ctrlShow _bleeding;
        _statusGroup ctrlShow (_status != "");
        [_bleedingGroup, _statusGroup, _respawnGroup] call AIS_Effects_fnc_unconsciousHudStack;
    };
};

// removes the HUD and the respawn key handler; also cleans up after a terminated AIS_Effects_fnc_unconsciousHud
AIS_Effects_fnc_unconsciousHudDelete = {
    disableSerialization;

    {
        ctrlDelete _x;
    } forEach ((uiNamespace getVariable ["AIS_var_unconsciousHud", []]) select [0, 3]);

    uiNamespace setVariable ["AIS_var_unconsciousHud", nil];

    if (!isNil "AIS_var_respawnKeyEhId") then {
        (findDisplay 46) displayRemoveEventHandler ["KeyDown", AIS_var_respawnKeyEhId];
        AIS_var_respawnKeyEhId = nil;
    };
};

// scheduled: the HUD of the unconscious player unit until it is revived, dies or respawns, the player controls another
// unit or the round ends; SPACE respawns (kills the unconscious unit)
AIS_Effects_fnc_unconsciousHud = {
    params ["_unit"];

    disableSerialization;

    call AIS_Effects_fnc_unconsciousHudDelete;

    if (missionNamespace getVariable ["SC_var_roundEnded", false]) exitWith {};

    AIS_var_respawn = false;
    AIS_var_respawnKeyEhId = (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["", "_key"];

        if (_key == 57) then {
            AIS_var_respawn = true;
        };
    }];

    call AIS_Effects_fnc_unconsciousHudCreate;

    private _wasStabilized = false;

    waitUntil {
        [_unit, ((1 - ((time - ais_start_unc_time) / AIS_BLEEDOUT_TIME)) max 0) min 1] call AIS_Effects_fnc_unconsciousHudUpdate;

        if (!_wasStabilized && {_unit getVariable ["ais_stabilized", false]}) then {
            _wasStabilized = true;
            ["medicSystem", ["You have been stabilized."]] call SC_fnc_showNotificationIfHudIsEnabled;
        };

        sleep AIS_var_hudUpdateInterval;

        AIS_var_respawn ||
        {!alive _unit} ||
        {player isNotEqualTo _unit} ||
        {!(_unit getVariable ["ais_unconscious", false])} ||
        {missionNamespace getVariable ["SC_var_roundEnded", false]}
    };

    call AIS_Effects_fnc_unconsciousHudDelete;

    // a revive in the same moment wins over the respawn key
    if (AIS_var_respawn && {alive _unit} && {_unit getVariable ["ais_unconscious", false]}) then {
        [_unit, objNull, objNull] call AIS_Damage_fnc_goToDead;
        _unit setDamage 1;
    } else {
        if (!alive _unit) then {
            [["finallyKilled", "bledOut"] select ((time - ais_start_unc_time) >= AIS_BLEEDOUT_TIME)] call SC_fnc_showNotificationIfHudIsEnabled;
        };
    };

    AIS_var_respawn = nil;
};

/*
 * Author: Vladimir Hynek (BI)
   Changed: Psycho
 * Posst process blood effects. (original from BIS_fnc_bloodEffect)
 * Arguments:
    -
 * Return value:
    -
*/
AIS_Effects_fnc_BloodSplatterScreen = {
    if (!canSuspend) exitWith {};
    disableSerialization;

    if (isNil {uiNamespace getVariable "RscHealthTextures"}) then {uiNamespace setVariable ["RscHealthTextures",displayNull]};
    if (isNull (uiNamespace getVariable "RscHealthTextures")) then {(["HealthPP_blood"] call BIS_fnc_rscLayer) cutRsc ["RscHealthTextures","plain"]};
    _display = uiNamespace getVariable "RscHealthTextures";

    _texLower = _display displayCtrl 1211;
    _texLower ctrlSetFade 1;
    _texLower ctrlCommit 0;

    _texMiddle = _display displayCtrl 1212;
    _texMiddle ctrlSetFade 1;
    _texMiddle ctrlCommit 0;

    _texUpper = _display displayCtrl 1213;
    _texUpper ctrlSetFade 1;
    _texUpper ctrlCommit 0;

    _x = ((0 * safeZoneW) + safeZoneX) + ((safeZoneW - (2.125 * safeZoneW * 3/4)) / 2);
    _y = (-0.0625 * safeZoneH) + safeZoneY;
    _w = 2.125 * safeZoneW * 3/4;
    _h = 1.125 * safeZoneH;

    _texLower ctrlSetPosition [_x, _y, _w, _h];
    _texMiddle ctrlSetPosition [_x, _y, _w, _h];
    _texUpper ctrlSetPosition [_x, _y, _w, _h];

    _texLower ctrlCommit 0;
    _texMiddle ctrlCommit 0;
    _texUpper ctrlCommit 0;

    _texLower ctrlSetFade 0.2;
    _texMiddle ctrlSetFade 0.7;
    _texUpper ctrlSetFade 0.7;

    _texLower ctrlCommit 0.2;
    _texMiddle ctrlCommit 0.2;
    _texUpper ctrlCommit 0.2;

    // remove effect if player get revived/stabilized or died or character changed (teamswitch or zeus f.e.)
    [
        {!alive player || {!(player getVariable ["ais_unconscious", false])} || {(player getVariable ["ais_stabilized", false])}},
        {_this spawn AIS_Effects_fnc_deleteBloodSplatterScreen},
        [_texLower,_texMiddle,_texUpper]
    ] call AIS_Core_fnc_waitUntilAndExecute;

    true
};

/*
 * Author: Psycho
 * Impact effect on bullet hit.
 * Arguments:
    0: Unit (Object)
    1: Strength (Number)
 * Example:
    [player, 0.5] call AIS_Effects_fnc_bulletImpact;
 * Return value:
    -
*/
AIS_Effects_fnc_bulletImpact = {
    params ["_unit", "_strength"];

    if (!local player) exitWith {};
    if (_unit getVariable "ais_unconscious") exitWith {};

    true
};

/*
 * Author: Psycho
 * Remove post process blood effects.
 * Arguments:
    -
 * Return value:
    -
*/
AIS_Effects_fnc_deleteBloodSplatterScreen = {
    disableSerialization;
    params ["_texLower", "_texMiddle", "_texUpper"];

    _texLower ctrlSetFade 1;
    _texMiddle ctrlSetFade 1;
    _texUpper ctrlSetFade 1;

    _texUpper ctrlCommit 1.5;
    sleep 1;
    _texMiddle ctrlCommit 1;
    sleep 0.5;
    _texLower ctrlCommit 0.8;

    true
};
