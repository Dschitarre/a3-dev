// Shared client settings. SC/OF keep their larger mode-specific F4 dialog; other modes use these capability tabs.

if (!isNil "UI_var_settingsCompiled") exitWith {};

UI_var_settingsCompiled = true;
UI_var_heldWinKeys = [];

// View distance (all modes): the player sets the OBJECT view distance (500..10000 m; ground
// default 2000, in flight 3500); the terrain view distance follows from it: equal at 500 m, rising to 1.25 x the
// object distance at 800 m and above. Shadows: setObjectViewDistance [objects, 0].
UI_var_viewRange = [500, 10000];
UI_fnc_viewDistanceStep = {
    params ["_distance"];

    private _s = 10 * sqrt ((500 max _distance) / 500);
    if (_s < 15) exitWith {10};

    if (_s < 35) exitWith {20};

    50
};

UI_fnc_roundViewDistance = {
    params ["_distance", ["_min", 500], ["_max", 10000]];

    _distance = _min max (_max min _distance);
    private _step = [_distance] call UI_fnc_viewDistanceStep;
    _min max (_max min (_step * round (_distance / _step)))
};

UI_fnc_viewDistanceSliderPosition = {
    params ["_distance", ["_min", 500], ["_max", 10000]];

    (sqrt (_min max (_max min _distance)) - sqrt _min) / (sqrt _max - sqrt _min)
};

UI_fnc_viewDistanceForObjects = {
    params ["_objects"];

    _objects * (((1 + (((_objects - 500) / 300) * 0.25)) min 1.25) max 1)
};

// slider label: "Ground: objects 2000 m, view 2500 m"
UI_fnc_viewSettingText = {
    params ["_label", "_objects"];

    format ["%1: objects %2 m, view %3 m", _label, _objects, round ([_objects] call UI_fnc_viewDistanceForObjects)]
};

UI_fnc_viewSettings = {
    UI_var_viewRange params ["_min", "_max"];

    [["Ground", "UI_var_groundObjectDistance", 2000, _min, _max], ["Flight", "UI_var_flightObjectDistance", 3500, _min, _max]]
};

UI_fnc_inFlight = {
    alive player &&
        {player getVariable ["BR_var_aboard", false] || {(vehicle player) isKindOf "Air"} ||
        {(vehicle player) isKindOf "ParachuteBase"} ||
        {isNull objectParent player && {(getPosATL player select 2) > 20}}}
};

UI_fnc_applyViewDistance = {

    // No arguments: plain call inherits initPlayerLocal / slider-event arguments in SQF.
    private _flight = call UI_fnc_inFlight;
    ((call UI_fnc_viewSettings) select ([0, 1] select _flight)) params ["", "_key", "_default", "_min", "_max"];
    private _objects = [profileNamespace getVariable [_key, _default], _min, _max] call UI_fnc_roundViewDistance;
    private _view = [_objects] call UI_fnc_viewDistanceForObjects;
    if ((missionNamespace getVariable ["UI_var_appliedView", []]) isEqualTo [_view, _objects] && {abs (viewDistance - _view) < 1}) exitWith {};

    if (abs (viewDistance - _view) >= 1) then {setViewDistance _view};
    (getObjectViewDistance) params ["_currentObjects", "_currentShadows"];
    if (abs (_currentObjects - _objects) > 0.1 || {_currentShadows != 0}) then {setObjectViewDistance [_objects, 0]};
    UI_var_appliedView = [_view, _objects];
};

UI_fnc_initViewDistance = {
    if (!hasInterface || {!isNil "UI_var_viewLoop"}) exitWith {};

    UI_var_viewLoop = [] spawn {uiSleep 0.1;
        while {true} do {
            [] call UI_fnc_applyViewDistance;
            uiSleep 0.25
        }};
};

// [label, mission variable, profile key, default]. Only capabilities actually provided by the mode are shown.
UI_fnc_iconSettings = {
    private _specs = [
    ["3D unit names", "TDI_var_showUnitNames", "UI_var_3dNames", true],
    ["Hide invisible group icons", "TDI_var_hideInvisibleGroupMembers", "UI_var_hideInvisibleGroupIcons", false],
    ["Limit group icon distance", "TDI_var_groupUnitsLimitedDistance", "UI_var_limitGroupIcons", false],
    ["Map names only on hover", "MM_var_showUnitNamesOnlyOnHover", "UI_var_mapHoverNames", true]
    ];

    // BR's own icons (only shown where the mode defines them: see the filter below)
    _specs append [
    ["3D teammate icons", "BR_var_showTeam3DIcons", "BR_var_showTeam3DIcons", true],
    ["3D teammate names", "BR_var_showTeam3DNames", "BR_var_showTeam3DNames", true],
    ["Map names only on hover", "BR_var_mapNamesOnlyOnHover", "BR_var_mapNamesOnlyOnHover", false],
    ["Supply drop map icons", "BR_var_showDropMapIcons", "BR_var_showDropMapIcons", true],
    ["3D zone boundary (spectator)", "BR_var_showZone3D", "BR_var_showZone3D", true]
    ];

    if (!isNil "EX_var_teamIconRange") then {
        _specs append [
        ["3D teammate icons", "EX_var_showTeam3DIcons", "EX_var_showTeam3DIcons", true],
        ["3D teammate names", "EX_var_showTeam3DNames", "EX_var_showTeam3DNames", true],
        ["Map names only on hover", "EX_var_mapNamesOnlyOnHover", "EX_var_mapNamesOnlyOnHover", true]
        ];
    };

    _specs select {!isNil (_x select 1)}
};

UI_fnc_applyIconSettings = {
    {missionNamespace setVariable [_x select 1,
        profileNamespace getVariable [_x select 2, _x select 3]]} forEach (call UI_fnc_iconSettings);
};

UI_fnc_settingsControl = {
    params ["_display", "_class", "_rect", ["_text", ""]];

    private _grid = _display getVariable "UI_var_settingsGrid";
    _grid params ["_left", "_top", "_w", "_h"];

    _rect params ["_x", "_y", "_width", "_height"];

    private _control = _display ctrlCreate [_class, -1];
    _control ctrlSetPosition [_left + _x * _w, _top + _y * _h, _width * _w, _height * _h];
    _control ctrlSetText _text;
    _control ctrlCommit 0;
    _control
};

UI_fnc_settingsShowTab = {
    params ["_index"];

    private _display = uiNamespace getVariable ["UI_var_settingsDisplay", displayNull];
    if (isNull _display) exitWith {};

    {
        private _visible = _forEachIndex == _index;
        {_x ctrlShow _visible} forEach (_x select 1);
        private _button = (_display getVariable "UI_var_settingsButtons") select _forEachIndex;
        _button ctrlSetBackgroundColor ([ [0, 0, 0, 0.7], ["accent"] call UI_fnc_color] select _visible);
    } forEach (_display getVariable "UI_var_settingsTabs");

    UI_var_settingsTab = _index;
};

UI_fnc_settingsSliderChanged = {
    params ["_slider", "_position"];

    if ((ctrlParent _slider) getVariable ["UI_var_initializingView", false]) exitWith {};

    (_slider getVariable "UI_var_spec") params ["_label", "_key", "_default", "_min", "_max"];
    private _value = [(sqrt _min + (0 max (1 min _position)) * (sqrt _max - sqrt _min))^2, _min, _max] call UI_fnc_roundViewDistance;

    if (_value != (_slider getVariable ["UI_var_shown", -1])) then {
        _slider setVariable ["UI_var_shown", _value];
        profileNamespace setVariable [_key, _value];
        saveProfileNamespace;
        [] call UI_fnc_applyViewDistance;
    };

    private _snapped = [_value, _min, _max] call UI_fnc_viewDistanceSliderPosition;
    if (abs (sliderPosition _slider - _snapped) > 0.000001) then {_slider sliderSetPosition _snapped};
    private _step = [_value] call UI_fnc_viewDistanceStep;
    private _increment = abs (([_value +([- _step, _step] select (_value < _max)), _min,
        _max] call UI_fnc_viewDistanceSliderPosition) - _snapped);
    _slider sliderSetSpeed [_increment, 10 * _increment];
    (_slider getVariable "UI_var_label") ctrlSetText ([_label, _value] call UI_fnc_viewSettingText);
};

UI_fnc_settingsOpened = {
    params ["_display"];

    disableSerialization;
    uiNamespace setVariable ["UI_var_settingsDisplay", _display];
    (call UI_fnc_gridCell) params ["_w", "_h"];
    private _earSize = if (isNil "E_fnc_settingsRowsSize") then {[0, 0]} else {call E_fnc_settingsRowsSize};
    private _width = 18 max ((_earSize select 0) + 1);
    private _height = 10 max ((_earSize select 1) + 4) max (4 + 1.2 * count (call UI_fnc_iconSettings));
    _display setVariable ["UI_var_settingsGrid", [safeZoneX + (safeZoneW - _width * _w) / 2, safeZoneY + (safeZoneH - _height * _h) / 2, _w, _h]];
    [_display, "UI_Panel", [0, 1, _width, _height - 1]] call UI_fnc_settingsControl;
    [_display, "UI_Title", [0, 0, _width, 1], "Settings (F4)"] call UI_fnc_settingsControl;
    private _tabs = [];
    private _view = [];

    {
        private _row = _forEachIndex * 2;
        _x params ["_label", "_key", "_default", "_min", "_max"];

        private _value = [profileNamespace getVariable [_key, _default], _min, _max] call UI_fnc_roundViewDistance;
        private _text =[_display, "UI_Text",[0.5, 2.6 + _row, _width - 1, 1],
            [_label, _value] call UI_fnc_viewSettingText] call UI_fnc_settingsControl;
        private _slider = [_display, "UI_Slider", [0.5, 3.5 + _row, _width - 1, 0.7]] call UI_fnc_settingsControl;
        _slider setVariable ["UI_var_spec", _x];
        _slider setVariable ["UI_var_label", _text];
        _slider setVariable ["UI_var_shown", _value];
        _slider sliderSetRange [0, 1];
        _slider sliderSetPosition ([_value, _min, _max] call UI_fnc_viewDistanceSliderPosition);
        _slider ctrlAddEventHandler ["SliderPosChanged", {_this call UI_fnc_settingsSliderChanged}];
        _view append [_text, _slider];
    } forEach (call UI_fnc_viewSettings);

    _tabs pushBack ["View distance", _view];

    if (!isNil "E_fnc_embedSettings") then {
        (_display getVariable "UI_var_settingsGrid") params ["_left", "_top"];
        private _ear = [_display, _left + 0.5 * _w, _top + 2.7 * _h] call E_fnc_embedSettings;
        _tabs pushBack ["Earplugs", _ear select 0];
    };

    private _icons = [];

    {
        private _row = _forEachIndex * 1.2;
        private _box = [_display, "UI_CheckBox", [0.5, 2.7 + _row, 1, 1]] call UI_fnc_settingsControl;
        private _text = [_display, "UI_Text", [1.6, 2.7 + _row, _width - 2.1, 1], _x select 0] call UI_fnc_settingsControl;
        _box cbSetChecked (missionNamespace getVariable [_x select 1, _x select 3]);
        _box setVariable ["UI_var_spec", _x];

        _box ctrlAddEventHandler ["CheckedChanged", {
            params ["_control", "_state"];

            private _spec = _control getVariable "UI_var_spec";
            missionNamespace setVariable [_spec select 1, _state == 1];
            profileNamespace setVariable [_spec select 2, _state == 1];
            saveProfileNamespace;
        }];

        _icons append [_box, _text];
    } forEach (call UI_fnc_iconSettings);

    if (_icons isNotEqualTo []) then {_tabs pushBack ["Icons", _icons]};
    private _buttons = [];

    {
        private _button =[_display, "UI_Button",
            [0.5 + _forEachIndex *((_width - 1) / count _tabs), 1.3,(_width - 1) / count _tabs - 0.1, 1],
            _x select 0] call UI_fnc_settingsControl;
        _button setVariable ["UI_var_tab", _forEachIndex];
        _button ctrlAddEventHandler ["ButtonClick", {[(_this select 0) getVariable "UI_var_tab"] call UI_fnc_settingsShowTab}];
        _buttons pushBack _button;
    } forEach _tabs;

    _display setVariable ["UI_var_settingsTabs", _tabs];
    _display setVariable ["UI_var_settingsButtons", _buttons];
    private _close = [_display, "UI_ButtonOK", [_width - 6, _height - 1.1, 5.5, 1], "Close"] call UI_fnc_settingsControl;
    _close ctrlAddEventHandler ["ButtonClick", {(ctrlParent (_this select 0)) closeDisplay 1}];

    _display displayAddEventHandler ["KeyDown", {if ((_this select 1) == 62) then {
            (_this select 0) closeDisplay 1;
            true
        } else {false}}];

    [(missionNamespace getVariable ["UI_var_settingsTab", 0]) min (count _tabs - 1)] call UI_fnc_settingsShowTab;
};

UI_fnc_settingsKeyDown = {
    params ["", "_key", "_shift", "_ctrl", "_alt"];

    if (_key in [219, 220]) exitWith {
        UI_var_heldWinKeys pushBackUnique _key;
        false
    };

    if (_key != 62 || {_shift || _ctrl || _alt} || {dialog}) exitWith {false};

    createDialog "UI_SettingsDialog";
    true
};

UI_fnc_initSettings = {
    call UI_fnc_initViewDistance;
    if (!hasInterface || {isClass (missionConfigFile >> "settingsDialog")} || {!isNil "UI_var_settingsStarted"}) exitWith {};

    UI_var_settingsStarted = true;

    [] spawn {
        disableSerialization;
        sleep 1;
        private _iconKeys = [];

        while {true} do {
            {
                private _display = findDisplay _x;

                if (!isNull _display && {!(_display getVariable ["UI_var_settingsKeys", false])}) then {
                    _display setVariable ["UI_var_settingsKeys", true];
                    _display displayAddEventHandler ["KeyDown", {_this call UI_fnc_settingsKeyDown}];

                    _display displayAddEventHandler ["KeyUp", {
                        UI_var_heldWinKeys = UI_var_heldWinKeys-[_this select 1];
                        false

                    }];
                };
            } forEach [46, 60492];

            if (!isGameFocused) then {UI_var_heldWinKeys = []};
            private _keys = (call UI_fnc_iconSettings) apply {_x select 1};

            if (_keys isNotEqualTo _iconKeys) then {
                _iconKeys = _keys;
                call UI_fnc_applyIconSettings
            };

            sleep 0.25;
        };
    };
};
