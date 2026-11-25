// Earplugs (client): F1 puts the earplugs in / out, automatic earplugs while the player sits in a ground vehicle,
// aircraft or boat, a settings dialog (Ctrl+F1, saved in the profile) and an icon while earplugs are in. The game
// volume is the lowest one of the earplugs in, faded on every change. Missions that fade the sound themselves (death,
// spectator, black screens) fade back to E_fnc_effectiveVolume and tell the mod with E_var_suspendCondition.

E_var_running = false;
E_var_ehIds = [];              // [KeyDown, KeyUp] handler IDs on display 46 while added
E_var_keyHeld = false;         // F1 is down: the key repeats while held, only the first press acts
E_var_dialogKeyHeld = false;   // the same in the settings dialog
E_var_loopScript = scriptNull;

E_var_earplugsOn = false;      // F1 (game modes read it together with E_var_volumeMuted)
E_var_appliedVolume = 1;       // the volume the mod faded to last; 1 at the start, so it changes nothing until needed
E_var_fadeEnd = 0;             // time when that fade is done
E_var_suspended = false;       // the last update found the mod suspended
E_var_resumeTime = -1;         // time to put the earplugs back in after a suspension, -1: none pending
E_var_dialogRefreshing = false;   // the dialog's controls are being set by script (their handlers ignore it)

// ---- tuning ----

E_var_fadeDuration = 0.5;      // seconds of every volume change
E_var_updateInterval = 0.25;   // seconds between two checks (vehicle, mission state)
E_var_resumeDelay = 1.5;       // seconds after a suspension (death, a mission's black screen) before the earplugs are
                               // put back in: the mission's own fade in (about 1 s) is done by then
E_var_maxVolume = 0.9;         // the volumes go from 0 to 90 % in steps of 10 %
E_var_iconSize = 1.2;          // GUI grid cells, square
E_var_iconGap = 0.2;           // cells between the icon and the vanilla weapon info
E_var_iconColor = [1, 1, 1, 0.85];
E_var_iconFadeDuration = 0.3;  // seconds the icon fades in / out

// vehicle categories of the automatic earplugs, in the order of the settings: ground vehicles, aircraft, boats
E_var_categoryKinds = ["LandVehicle", "Air", "Ship"];

// without the server's E_var_defaultSettings (fnc_server.sqf, same form)
E_var_builtinDefaults = [0.3, [true, true, true], [0.5, 0.3, 0.5]];

// the icon ships in the mod's PBO and, in missions that integrate the mod, next to these scripts in
// modsIntegrated\earplugs\scripts (scripts\build.ps1 copies the whole scripts folder; the check uses the script, as
// modsIntegrated\loadMods.sqf does); a mission file needs its full path for a texture
E_var_iconTexture = if (fileExists "modsIntegrated\earplugs\scripts\fnc_client.sqf") then {
    getMissionPath "modsIntegrated\earplugs\scripts\earplugs_ca.paa"
} else {
    "\earplugs\scripts\earplugs_ca.paa"
};

// ---- mission hooks (missions may set them before or after the mod loads) ----

// true while the mission sets the sound volume itself (loading and black screens, its own spectator, round end): the
// mod changes nothing, F1 does nothing and the icon is hidden; afterwards (E_var_resumeDelay) the mod puts the
// earplugs back in. Always suspended while the player is dead or in the vanilla spectator.
if (isNil "E_var_suspendCondition") then {E_var_suspendCondition = {false};};

// false hides the icon, e.g. together with the mission's HUD
if (isNil "E_var_iconCondition") then {E_var_iconCondition = {true};};

// the icon's [x, y, w, h] in screen coordinates (E_fnc_defaultIconPosition: left of the vanilla weapon info)
if (isNil "E_var_iconPosition") then {E_var_iconPosition = {call E_fnc_defaultIconPosition};};

// ---- settings ----

// a volume on a step of 10 % from 0 to E_var_maxVolume
E_fnc_stepVolume = {
    params ["_volume"];

    (((round (_volume * 10)) / 10) max 0) min E_var_maxVolume
};

// [number, [3 booleans], [3 numbers]]
E_fnc_isSettings = {
    params ["_settings"];

    _settings isEqualType [] &&
    {_settings isEqualTypeArray [0, [], []]} &&
    {(_settings select 1) isEqualTypeArray [true, true, true]} &&
    {(_settings select 2) isEqualTypeArray [0, 0, 0]}
};

// the player's settings (profileNamespace E_var_settings, the form of E_var_defaultSettings), else the defaults
E_fnc_loadSettings = {
    private _settings = profileNamespace getVariable ["E_var_settings", []];

    if !([_settings] call E_fnc_isSettings) then {
        _settings = missionNamespace getVariable ["E_var_defaultSettings", []];
    };

    if !([_settings] call E_fnc_isSettings) then {
        _settings = E_var_builtinDefaults;
    };

    _settings params ["_volumeMuted", "_autoEnabled", "_autoVolumes"];

    E_var_volumeMuted = [_volumeMuted] call E_fnc_stepVolume;   // game modes read it together with E_var_earplugsOn
    E_var_autoEnabled = +_autoEnabled;
    E_var_autoVolumes = _autoVolumes apply {[_x] call E_fnc_stepVolume};
};

// into the profile; saved to disk when the dialog closes
E_fnc_storeSettings = {
    profileNamespace setVariable ["E_var_settings", [E_var_volumeMuted, +E_var_autoEnabled, +E_var_autoVolumes]];
};

E_fnc_resetSettings = {
    profileNamespace setVariable ["E_var_settings", nil];
    call E_fnc_loadSettings;
    call E_fnc_update;
    call E_fnc_refreshDialog;
};

call E_fnc_loadSettings;

// ---- volume ----

// the unit the player hears the world through: the unit remote controlled by Zeus while remote controlling
E_fnc_listenerUnit = {
    private _remoteControlled = missionNamespace getVariable ["bis_fnc_moduleRemoteControl_unit", objNull];

    [_remoteControlled, player] select (isNull _remoteControlled)
};

// the category of the unit's vehicle (index into E_var_categoryKinds); -1 on foot, dead, in a static weapon, a
// parachute (counts as aircraft) or a UAV
E_fnc_vehicleCategory = {
    params ["_unit"];

    private _vehicle = objectParent _unit;

    if (
        !alive _unit ||
        {isNull _vehicle} ||
        {_vehicle isKindOf "StaticWeapon"} ||
        {_vehicle isKindOf "ParachuteBase"} ||
        {unitIsUAV _vehicle}
    ) exitWith {-1};

    E_var_categoryKinds findIf {_vehicle isKindOf _x}
};

// The game volume with the earplugs that are in: the lowest one of F1 (if in) and the automatic earplugs of the
// player's vehicle (if on), 1 without earplugs or while the mod is stopped. Missions that fade the sound themselves
// fade back to it, e.g. on respawn: 1 fadeSound (call E_fnc_effectiveVolume).
E_fnc_effectiveVolume = {
    if (!E_var_running) exitWith {1};

    private _volume = [1, E_var_volumeMuted] select E_var_earplugsOn;
    private _category = [call E_fnc_listenerUnit] call E_fnc_vehicleCategory;

    if (_category != -1 && {E_var_autoEnabled select _category}) then {
        _volume = _volume min (E_var_autoVolumes select _category);
    };

    _volume
};

// fades to the effective volume now (for missions that don't fade themselves); _duration in seconds
E_fnc_applyVolume = {
    params [["_duration", E_var_fadeDuration, [0]]];

    [call E_fnc_effectiveVolume, _duration] call E_fnc_fadeTo;
};

E_fnc_fadeTo = {
    params ["_volume", "_duration"];

    _duration fadeSound _volume;
    E_var_appliedVolume = _volume;
    E_var_fadeEnd = time + _duration;
};

E_fnc_isSuspended = {
    !alive player || {!isNull findDisplay 60492} || {call E_var_suspendCondition}
};

// Unscheduled (the loop calls it in isNil, the keys and the dialog directly): fades to the effective volume when it
// changed, keeps out of the mission's fades while suspended and puts the earplugs back in afterwards, shows the icon.
E_fnc_update = {
    if (!E_var_running) exitWith {};

    if (call E_fnc_isSuspended) exitWith {
        E_var_suspended = true;
        E_var_resumeTime = -1;
        [false] call E_fnc_showIcon;
    };

    if (E_var_suspended) then {
        E_var_suspended = false;
        E_var_resumeTime = time + E_var_resumeDelay;
    };

    private _volume = call E_fnc_effectiveVolume;
    private _fade = _volume != E_var_appliedVolume;

    if (E_var_resumeTime != -1) then {
        // after the delay always: the mission may have faded to another volume meanwhile
        _fade = time >= E_var_resumeTime;

        if (_fade) then {
            E_var_resumeTime = -1;
        };
    } else {
        // a mission faded to the full volume while earplugs are in (the end of a black screen of its own, which the mod
        // doesn't know of): back in
        if (!_fade && {_volume < 1} && {time >= E_var_fadeEnd} && {soundVolume > 0.99}) then {
            _fade = true;
        };
    };

    if (_fade) then {
        [_volume, E_var_fadeDuration] call E_fnc_fadeTo;
    };

    [_volume < 1 && {call E_var_iconCondition}] call E_fnc_showIcon;
};

E_fnc_updateLoop = {
    while {E_var_running} do {
        isNil {call E_fnc_update};
        sleep E_var_updateInterval;
    };
};

// F1 / the checkbox of the dialog: earplugs in / out; not while suspended (the mission decides the volume then). The
// player's own change applies at once, also right after a suspension. True if done.
E_fnc_setEarplugs = {
    params ["_on"];

    if (!E_var_running || {call E_fnc_isSuspended}) exitWith {
        call E_fnc_refreshDialog;
        false
    };

    E_var_earplugsOn = _on;
    E_var_suspended = false;
    E_var_resumeTime = -1;
    E_var_appliedVolume = -1;
    call E_fnc_update;
    call E_fnc_refreshDialog;
    true
};

// ---- icon ----

// the GUI grid cell [width, height] (\a3\ui_f\hpp\defineCommonGrids.inc)
E_fnc_gridCell = {
    private _gridWidth = (safeZoneW / safeZoneH) min 1.2;

    [_gridWidth / 40, _gridWidth / 1.2 / 25]
};

// Left of the vanilla weapon info (its place in the player's layout, IGUI_GRID_WEAPON_*), level with its top: the
// weapon info and the stance indicator fill the top right corner, below them starts the kill feed of the killfeed mod.
// In a vehicle the weapon info sits E_var_vehicleWeaponInfoShift cells further right (RscUnitInfo: no stance
// indicator there), the icon follows it.
E_var_vehicleWeaponInfoShift = 3.8;

E_fnc_defaultIconPosition = {
    (call E_fnc_gridCell) params ["_cellW", "_cellH"];

    private _weaponX = profileNamespace getVariable ["IGUI_GRID_WEAPON_X", safeZoneX + safeZoneW - 14.3 * _cellW];
    private _weaponY = profileNamespace getVariable ["IGUI_GRID_WEAPON_Y", safeZoneY + 0.5 * _cellH];
    private _width = E_var_iconSize * _cellW;

    if (!isNull (objectParent (call E_fnc_listenerUnit))) then {
        _weaponX = _weaponX + E_var_vehicleWeaponInfoShift * _cellW;
    };

    [_weaponX - E_var_iconGap * _cellW - _width, _weaponY, _width, E_var_iconSize * _cellH]
};

// The picture on display 46 (created again when it is gone: a loaded savegame has a new display 46); the control is
// kept in uiNamespace only (it can't be serialized with the mission namespace).
E_fnc_showIcon = {
    params ["_visible"];

    _visible = _visible && {missionNamespace getVariable ["E_cba_showIcon", true]};

    private _icon = uiNamespace getVariable ["E_var_icon", controlNull];

    if (isNull _icon) then {
        if (!_visible || {isNull findDisplay 46}) exitWith {};

        _icon = (findDisplay 46) ctrlCreate ["RscPictureKeepAspect", -1];
        _icon ctrlSetText E_var_iconTexture;
        _icon ctrlSetTextColor E_var_iconColor;
        _icon ctrlSetFade 1;
        _icon ctrlCommit 0;
        uiNamespace setVariable ["E_var_icon", _icon];
        uiNamespace setVariable ["E_var_iconState", [false, []]];
    };

    if (isNull _icon) exitWith {};

    (uiNamespace getVariable ["E_var_iconState", [false, []]]) params ["_shown", "_position"];

    // the position only while shown (the hook may read the mission's HUD)
    if (_visible) then {
        private _newPosition = call E_var_iconPosition;

        if (_newPosition isNotEqualTo _position) then {
            _position = _newPosition;
            _icon ctrlSetPosition _position;
            _icon ctrlCommit 0;
        };
    };

    if (_visible isNotEqualTo _shown) then {
        _icon ctrlSetFade ([1, 0] select _visible);
        _icon ctrlCommit E_var_iconFadeDuration;
    };

    uiNamespace setVariable ["E_var_iconState", [_visible, _position]];
};

// A mission moved what the icon sits next to (its E_var_iconPosition hook, e.g. the SC HUD rows): the shown icon
// follows at once instead of with the next update (user: it lagged behind)
E_fnc_refreshIconPosition = {
    private _icon = uiNamespace getVariable ["E_var_icon", controlNull];

    if (isNull _icon) exitWith {};

    (uiNamespace getVariable ["E_var_iconState", [false, []]]) params ["_shown", "_position"];

    if (!_shown) exitWith {};

    private _newPosition = call E_var_iconPosition;

    if (_newPosition isNotEqualTo _position) then {
        _icon ctrlSetPosition _newPosition;
        _icon ctrlCommit 0;
        uiNamespace setVariable ["E_var_iconState", [_shown, _newPosition]];
    };
};

E_fnc_deleteIcon = {
    ctrlDelete (uiNamespace getVariable ["E_var_icon", controlNull]);
    uiNamespace setVariable ["E_var_icon", nil];
    uiNamespace setVariable ["E_var_iconState", nil];
};

// ---- settings dialog ----
/*
    Ctrl+F1, or a game mode's own settings: [parent display] call E_fnc_openSettingsDialog. A child display built from
    vanilla classes with ctrlCreate (missions that integrate the mod have no config of it), in the vanilla look: title
    bar in the player's accent color, body black 0.7, layout in GUI grid cells, centred. Rows: the earplugs of F1, a
    heading, one row per vehicle category (checkbox, name, volume slider in steps of 10 %, value), a hint; the buttons
    below. Every change applies at once; the display (and so every control) is kept in uiNamespace only.
*/

E_var_dialogSliderWidth = 8;    // cells, as the sliders of the SC settings
E_var_dialogValueWidth = 2.5;   // cells: "90 %"
E_var_dialogButtonWidth = 6;
E_var_dialogHintSize = 0.8;     // cells: text size of the hint (the vanilla side info size)

// [label, tooltip] of the earplugs of F1, then of each vehicle category (E_var_categoryKinds); controls of row n:
// checkbox 100 + 10 * n, slider + 1, value + 2
E_var_dialogRows = [
    ["Earplugs (F1)", "Earplugs in or out (also F1) and the game volume while they are in"],
    ["Ground vehicles", "Earplugs in while you sit in a car, truck, tank or APC, and the game volume then"],
    ["Aircraft", "Earplugs in while you sit in a helicopter or plane, and the game volume then"],
    ["Boats", "Earplugs in while you sit in a boat or submarine, and the game volume then"]
];
E_var_dialogHeading = "Automatic earplugs in vehicles";
E_var_dialogHint = "If several earplugs are in, the lowest volume applies.";

// [_display, class, idc, [left, top, cell width, cell height], [x, y, w, h] in cells from the top left corner of the
// title bar, text, tooltip]
E_fnc_createDialogControl = {
    params ["_display", "_class", "_idc", "_grid", "_rect", ["_text", ""], ["_tooltip", ""]];

    _grid params ["_left", "_top", "_cellW", "_cellH"];
    _rect params ["_cellX", "_cellY", "_cellsW", "_cellsH"];

    private _control = _display ctrlCreate [_class, _idc];

    _control ctrlSetPosition [_left + _cellX * _cellW, _top + _cellY * _cellH, _cellsW * _cellW, _cellsH * _cellH];
    _control ctrlCommit 0;

    if (_text != "") then {
        _control ctrlSetText _text;
    };

    if (_tooltip != "") then {
        _control ctrlSetTooltip _tooltip;
    };

    _control
};

// an RGBA color of the player's settings (Options > Game > Colors): the profile variables <prefix>R / G / B / A
E_fnc_profileColor = {
    params ["_prefix", "_fallback"];

    private _color = +_fallback;

    {
        _color set [_forEachIndex, profileNamespace getVariable [_prefix + _x, _color select _forEachIndex]];
    } forEach ["R", "G", "B", "A"];

    _color
};

// [width, height] in cells of the settings rows (E_fnc_createSettingsRows): the label column as wide as its longest
// text, the rows as wide as the widest of the slider rows, the heading and the hint
E_fnc_settingsRowsSize = {
    (call E_fnc_gridCell) params ["_cellW", "_cellH"];

    private _labelWidth = 0;

    {
        _labelWidth = _labelWidth max (((_x select 0) getTextWidth ["RobotoCondensed", _cellH]) / _cellW);
    } forEach E_var_dialogRows;

    _labelWidth = _labelWidth + 0.3;

    private _valueX = 1.1 + _labelWidth + 0.1 + E_var_dialogSliderWidth + 0.1;
    private _width = selectMax [
        _valueX + E_var_dialogValueWidth,
        (E_var_dialogHeading getTextWidth ["RobotoCondensedBold", _cellH]) / _cellW + 0.3,
        (E_var_dialogHint getTextWidth ["RobotoCondensed", E_var_dialogHintSize * _cellH]) / _cellW + 0.3
    ];

    [_width, (count E_var_dialogRows) + 2, _labelWidth]
};

// The settings rows from the top left corner of _grid ([left, top, cell width, cell height]) on: the earplugs of F1, a
// heading, one row per vehicle category (checkbox, name, volume slider in steps of 10 %, value), the hint. Every change
// applies at once. Returns [controls, width, height] (cells).
E_fnc_createSettingsRows = {
    params ["_display", "_grid"];

    (call E_fnc_settingsRowsSize) params ["_width", "_height", "_labelWidth"];
    (call E_fnc_gridCell) params ["", "_cellH"];

    private _sliderX = 1.1 + _labelWidth + 0.1;
    private _valueX = _sliderX + E_var_dialogSliderWidth + 0.1;
    private _controls = [];

    {
        _x params ["_label", "_tooltip"];

        // the heading between the earplugs of F1 and the vehicle categories
        private _rowY = _forEachIndex + ([0, 1] select (_forEachIndex > 0));
        private _idc = 100 + 10 * _forEachIndex;

        private _checkBox = [_display, "RscCheckBox", _idc, _grid, [0, _rowY, 1, 1], "", _tooltip] call E_fnc_createDialogControl;
        _checkBox ctrlAddEventHandler ["CheckedChanged", {
            params ["_control"];

            if (!E_var_dialogRefreshing) then {
                [[_control] call E_fnc_dialogRowSource, cbChecked _control] call E_fnc_setSourceOn;
            };
        }];

        private _labelControl = [_display, "RscText", -1, _grid, [1.1, _rowY, _labelWidth, 1], _label, _tooltip] call E_fnc_createDialogControl;

        // the vanilla slider height, centred in the row
        private _slider =[_display, "RscXSliderH", _idc + 1, _grid,
            [_sliderX, _rowY + 0.125, E_var_dialogSliderWidth, 0.75], "",
            _tooltip] call E_fnc_createDialogControl;
        _slider sliderSetRange [0, round (10 * E_var_maxVolume)];
        _slider sliderSetSpeed [1, 1];
        _slider ctrlAddEventHandler ["SliderPosChanged", {
            params ["_control", "_position"];

            if (!E_var_dialogRefreshing) then {
                [[_control] call E_fnc_dialogRowSource, (round _position) / 10] call E_fnc_setSourceVolume;
            };
        }];

        private _value = [_display, "RscText", _idc + 2, _grid, [_valueX, _rowY, E_var_dialogValueWidth, 1]] call E_fnc_createDialogControl;

        _controls append [_checkBox, _labelControl, _slider, _value];
    } forEach E_var_dialogRows;

    private _heading = [_display, "RscText", -1, _grid, [0, 1, _width, 1], E_var_dialogHeading] call E_fnc_createDialogControl;
    _heading ctrlSetFont "RobotoCondensedBold";

    private _hint = [_display, "RscText", -1, _grid, [0, _height - 1, _width, 1], E_var_dialogHint] call E_fnc_createDialogControl;
    _hint ctrlSetFontHeight (E_var_dialogHintSize * _cellH);
    _hint ctrlSetTextColor [1, 1, 1, 1];   // the dialog's text white (a dimmed hint looked pale, user)

    _controls append [_heading, _hint];

    [_controls, _width, _height]
};

// The settings rows inside a dialog of a game mode (the SC settings), from the top left corner _left, _top (screen
// coordinates) on; they follow every change while that display is open. Returns [controls, width, height] (cells).
E_fnc_embedSettings = {
    params ["_display", "_left", "_top"];

    (call E_fnc_gridCell) params ["_cellW", "_cellH"];

    private _result = [_display, [_left, _top, _cellW, _cellH]] call E_fnc_createSettingsRows;

    uiNamespace setVariable ["E_var_embeddedDisplay", _display];
    call E_fnc_refreshDialog;
    _result
};

// the own dialog (Ctrl+F1): title, body with the settings rows, Default and OK below, centred
E_fnc_createDialogControls = {
    params ["_display"];

    (call E_fnc_gridCell) params ["_cellW", "_cellH"];
    (call E_fnc_settingsRowsSize) params ["_rowsWidth", "_rowsHeight"];

    private _bodyWidth = 1 + (_rowsWidth max (2 * E_var_dialogButtonWidth + 0.1));
    private _bodyHeight = 0.5 + _rowsHeight + 0.5;
    private _height = 1 + _bodyHeight + 0.1 + 1;                      // title, body, gap, buttons
    private _left = safeZoneX + 0.5 * (safeZoneW - _bodyWidth * _cellW);
    private _top = safeZoneY + 0.5 * (safeZoneH - _height * _cellH);
    private _grid = [_left, _top, _cellW, _cellH];

    private _title = [_display, "RscTitle", -1, _grid, [0, 0, _bodyWidth, 1], "Earplugs"] call E_fnc_createDialogControl;
    _title ctrlSetBackgroundColor (["GUI_BCG_RGB_", [0.13, 0.54, 0.21, 0.8]] call E_fnc_profileColor);
    _title ctrlSetTextColor (["GUI_TITLETEXT_RGB_", [1, 1, 1, 0.6]] call E_fnc_profileColor);

    private _body = [_display, "RscText", -1, _grid, [0, 1, _bodyWidth, _bodyHeight]] call E_fnc_createDialogControl;
    _body ctrlSetBackgroundColor [0, 0, 0, 0.7];

    [_display, [_left + 0.5 * _cellW, _top + 1.5 * _cellH, _cellW, _cellH]] call E_fnc_createSettingsRows;

    private _buttonY = 1 + _bodyHeight + 0.1;

    private _default = [_display, "RscButtonMenu", -1, _grid, [0, _buttonY, E_var_dialogButtonWidth, 1], "Default", "Back to the default settings"] call E_fnc_createDialogControl;
    _default ctrlAddEventHandler ["ButtonClick", {call E_fnc_resetSettings}];

    private _ok =[_display, "RscButtonMenuOK", -1, _grid,
        [_bodyWidth - E_var_dialogButtonWidth, _buttonY, E_var_dialogButtonWidth, 1],
        "OK"] call E_fnc_createDialogControl;
    _ok ctrlAddEventHandler ["ButtonClick", {
        params ["_control"];

        (ctrlParent _control) closeDisplay 1;
    }];
};

// the source of a dialog row: -1 the earplugs of F1, else the vehicle category
E_fnc_dialogRowSource = {
    params ["_control"];

    (floor (((ctrlIDC _control) - 100) / 10)) - 1
};

E_fnc_setSourceOn = {
    params ["_source", "_on"];

    if (_source == -1) exitWith {
        [_on] call E_fnc_setEarplugs;
    };

    E_var_autoEnabled set [_source, _on];
    call E_fnc_storeSettings;
    call E_fnc_update;
    call E_fnc_refreshDialog;
};

E_fnc_setSourceVolume = {
    params ["_source", "_volume"];

    _volume = [_volume] call E_fnc_stepVolume;

    private _oldVolume = if (_source == -1) then {E_var_volumeMuted} else {E_var_autoVolumes select _source};

    // the slider moves freely while dragged: only a new step counts, the refresh puts it on the step
    if (_volume != _oldVolume) then {
        if (_source == -1) then {
            E_var_volumeMuted = _volume;
        } else {
            E_var_autoVolumes set [_source, _volume];
        };

        call E_fnc_storeSettings;
        call E_fnc_update;
    };

    call E_fnc_refreshDialog;
};

// the settings rows (the own dialog and the ones embedded in a game mode's dialog, if open) to the current settings
E_fnc_refreshDialog = {
    E_var_dialogRefreshing = true;

    {
        private _display = uiNamespace getVariable [_x, displayNull];

        if (!isNull _display) then {
            {
                private _source = _forEachIndex - 1;
                private _idc = 100 + 10 * _forEachIndex;
                private _on = if (_source == -1) then {E_var_earplugsOn} else {E_var_autoEnabled select _source};
                private _volume = if (_source == -1) then {E_var_volumeMuted} else {E_var_autoVolumes select _source};

                (_display displayCtrl _idc) cbSetChecked _on;
                (_display displayCtrl (_idc + 1)) sliderSetPosition (round (_volume * 10));
                (_display displayCtrl (_idc + 2)) ctrlSetText format ["%1 %2", round (_volume * 100), "%"];
            } forEach E_var_dialogRows;
        };
    } forEach ["E_var_dialog", "E_var_embeddedDisplay"];

    E_var_dialogRefreshing = false;
};

// _parent: the display to open it on (default: display 46); _byKey: opened with Ctrl+F1, which is still down
E_fnc_openSettingsDialog = {
    params [["_parent", displayNull, [displayNull]], ["_byKey", false, [false]]];

    if (!E_var_running || {!isNull (uiNamespace getVariable ["E_var_dialog", displayNull])}) exitWith {};

    if (isNull _parent) then {
        _parent = findDisplay 46;
    };

    if (isNull _parent) exitWith {};

    private _display = _parent createDisplay "RscDisplayEmpty";

    if (isNull _display) exitWith {};

    uiNamespace setVariable ["E_var_dialog", _display];
    E_var_dialogKeyHeld = _byKey;
    (_display displayCtrl 1202) ctrlShow false;   // the vignette of RscDisplayEmpty

    [_display] call E_fnc_createDialogControls;
    call E_fnc_refreshDialog;

    _display displayAddEventHandler ["KeyDown", {_this call E_fnc_dialogKeyDown}];
    _display displayAddEventHandler ["KeyUp", {_this call E_fnc_dialogKeyUp}];
    _display displayAddEventHandler ["Unload", {saveProfileNamespace}];
};

E_fnc_closeSettingsDialog = {
    private _display = uiNamespace getVariable ["E_var_dialog", displayNull];

    if (!isNull _display) then {
        _display closeDisplay 2;
    };
};

// in the dialog: Ctrl+F1 closes it, F1 puts the earplugs in / out (its checkbox follows)
E_fnc_dialogKeyDown = {
    params ["_display", "_key", "_shift", "_ctrl", "_alt"];

    if (_key != 59 || {_shift || _alt}) exitWith {false};

    if (E_var_dialogKeyHeld) exitWith {true};

    E_var_dialogKeyHeld = true;

    if (_ctrl) then {
        _display closeDisplay 2;
    } else {
        [!E_var_earplugsOn] call E_fnc_setEarplugs;
    };

    true
};

// the release of a key pressed on display 46 can reach the dialog instead (and the other way round)
E_fnc_dialogKeyUp = {
    params ["", "_key"];

    if (_key == 59) then {
        E_var_dialogKeyHeld = false;
        E_var_keyHeld = false;
    };

    false
};

// ---- keys ----

E_fnc_keyDown = {
    params ["", "_key", "_shift", "_ctrl", "_alt"];

    if (_key != 59 || {_shift || _alt}) exitWith {false}; // DIK_F1, with Ctrl: the settings

    if (_ctrl) exitWith {
        [displayNull, true] call E_fnc_openSettingsDialog;
        true
    };

    if (E_var_keyHeld) exitWith {true};

    // suspended (dead, spectating, the mission's black screens): the key is not taken, as without the mod
    if !([!E_var_earplugsOn] call E_fnc_setEarplugs) exitWith {false};

    E_var_keyHeld = true;
    true
};

E_fnc_keyUp = {
    params ["", "_key"];

    if (_key == 59) then {
        E_var_keyHeld = false;
        E_var_dialogKeyHeld = false;
    };

    false
};

// Adds / removes the key handlers on display 46 to match E_var_running. Runs scheduled (waits for the display);
// the change itself runs unscheduled, so a start and a stop in quick succession cannot double or lose them.
// _reload: a loaded singleplayer savegame has a new display 46, so the handlers are added again.
E_fnc_syncKeyHandlers = {
    params [["_reload", false]];

    waitUntil {!isNull player && {!isNull findDisplay 46}};

    isNil {
        private _display = findDisplay 46;

        if (E_var_ehIds isNotEqualTo [] && {_reload || {!E_var_running}}) then {
            E_var_ehIds params ["_keyDownEhId", "_keyUpEhId"];

            _display displayRemoveEventHandler ["KeyDown", _keyDownEhId];
            _display displayRemoveEventHandler ["KeyUp", _keyUpEhId];
            E_var_ehIds = [];
        };

        if (E_var_running && {E_var_ehIds isEqualTo []}) then {
            E_var_keyHeld = false;
            E_var_ehIds = [
                _display displayAddEventHandler ["KeyDown", {_this call E_fnc_keyDown}],
                _display displayAddEventHandler ["KeyUp", {_this call E_fnc_keyUp}]
            ];
        };
    };
};

// ---- start / stop ----

E_fnc_startEarplugsClient = {
    if (E_var_running) exitWith {};

    E_var_running = true;
    if (!isNil "UI_fnc_initSettings") then {call UI_fnc_initSettings};

    // the server's defaults have arrived by now
    call E_fnc_loadSettings;

    if (!isMultiplayer) then {
        E_var_loadedEhId = addMissionEventHandler ["Loaded", {[true] spawn E_fnc_syncKeyHandlers}];
    };

    [] spawn E_fnc_syncKeyHandlers;
    E_var_loopScript = [] spawn E_fnc_updateLoop;
};

E_fnc_stopEarplugsClient = {
    if (!E_var_running) exitWith {};

    E_var_running = false;
    terminate E_var_loopScript;

    // the full volume again, unless the mission has the sound in hand
    if (E_var_appliedVolume != 1 && {!(call E_fnc_isSuspended)}) then {
        [1, E_var_fadeDuration] call E_fnc_fadeTo;
    };

    E_var_earplugsOn = false;
    E_var_appliedVolume = 1;
    E_var_suspended = false;
    E_var_resumeTime = -1;

    call E_fnc_closeSettingsDialog;
    call E_fnc_deleteIcon;

    if (!isMultiplayer) then {
        removeMissionEventHandler ["Loaded", E_var_loadedEhId];
        E_var_loadedEhId = nil;
    };

    [] spawn E_fnc_syncKeyHandlers;
};

E_var_clientInitDone = true;
