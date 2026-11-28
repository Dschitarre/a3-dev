// Settings: settings dialog, view distance, HUD toggle, hotkeys and the hooks of the earplugs mod (client).

// ---- settings ----

SC_fnc_writeSettingsArrToVariables = {
    SC_var_hudEnabled = SC_var_settings select 0;
    SC_var_alwaysShowHudOnMap = SC_var_settings select 1;
    SC_var_alwaysShowHudWhenUnconscious = SC_var_settings select 2;
    SC_var_showWholeHudOnMap = SC_var_settings select 3;
    SC_var_showWholeHudWhenUnconscious = SC_var_settings select 4;
    TDI_var_ShowUnitNames = SC_var_settings select 11;
    TDI_var_HideInvisibleGroupMembers = SC_var_settings select 12;
    TDI_var_groupUnitsLimitedDistance = SC_var_settings select 13;
    SC_var_showSector3DIcons = SC_var_settings select 14;
    SC_var_showAirDrop3DIcons = SC_var_settings select 15;
    MM_var_showUnitNamesOnlyOnHover = SC_var_settings select 16;
    SC_var_gpsPanelEnabled = SC_var_settings select 20;
    SC_var_showLockedArsenalItems = SC_var_settings select 21;
};

SC_fnc_toggleHud = {
    SC_var_hudEnabled = !SC_var_hudEnabled;
    SC_var_settings set [0, SC_var_hudEnabled];
    profileNamespace setVariable ["SC_var_lastSettings", SC_var_settings];
    saveProfileNamespace;

    if SC_var_hudEnabled then {
        [true] call SC_fnc_setHud;
    } else {

        if !(
        (SC_var_alwaysShowHudOnMap && visibleMap) || {SC_var_alwaysShowHudWhenUnconscious && (player getVariable ["AIS_unconscious", false])}

        ) then {
            [false] call SC_fnc_setHud;
        };
    };
};

SC_fnc_toggleSetting = {
    params ["_settingsIndex"];

    [_settingsIndex, !(SC_var_settings select _settingsIndex)] call SC_fnc_changeSetting;
};

SC_fnc_changeSetting = {
    params ["_settingsIndex", "_enabled"];

    SC_var_settings set [_settingsIndex, _enabled];
    call SC_fnc_writeSettingsArrToVariables;
    profileNamespace setVariable ["SC_var_lastSettings", SC_var_settings];
    saveProfileNamespace;

    [
    SC_var_hudEnabled || {SC_var_alwaysShowHudOnMap && visibleMap} ||
        {SC_var_alwaysShowHudWhenUnconscious &&(player getVariable ["AIS_unconscious", false])}
    ] call SC_fnc_setHud;
};

// The sections of the settings dialog (tabs, SC\dialogs.hpp settingsDialog): [tab idc, setting indexes (SC_var_settings,
// checkbox 2800 + index), further controls]. The earplugs section holds the rows of the earplugs mod
// (E_fnc_embedSettings), its tab is hidden without the mod.
SC_var_settingsSections = [
[1610, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 17, 18, 19, 20], []],
[1611, [11, 12, 13, 14, 15, 16], []],
[1612, [], []],
[1613, [21], [1900, 1004, 1901, 1027]]
];
SC_var_settingsEarplugsSection = 2;

// label idc of a setting: 1003 for the HUD switch, 1005 + index for the others (SC_SETTING in SC\dialogs.hpp)
SC_fnc_settingLabelIdc = {
    params ["_index"];

    [1003, 1005 + _index] select (_index > 0)
};

SC_fnc_setupSettingsDialog = {
    private _settingsDialog = uiNamespace getVariable "SC_var_settingsDialog";

    for "_i" from 0 to ((count SC_var_settings) - 1) do {
        (_settingsDialog displayCtrl (2800 + _i)) cbSetChecked (SC_var_settings select _i);
    };

    _settingsDialog setVariable ["UI_var_initializingView", true];

    {
        _x params ["_label", "_key", "_default", "_min", "_max"];

        private _slider = _settingsDialog displayCtrl (1900 + _forEachIndex);
        private _text = _settingsDialog displayCtrl ([1004, 1027] select _forEachIndex);
        private _value = [profileNamespace getVariable [_key, _default], _min, _max] call UI_fnc_roundViewDistance;
        _slider setVariable ["UI_var_spec", _x];
        _slider setVariable ["UI_var_label", _text];
        _slider setVariable ["UI_var_shown", _value];
        _slider sliderSetRange [0, 1];
        _slider sliderSetSpeed [0.0025, 0.025];
        _slider sliderSetPosition ([_value, _min, _max] call UI_fnc_viewDistanceSliderPosition);
        _text ctrlSetText ([_label, _value] call UI_fnc_viewSettingText);
    } forEach (call UI_fnc_viewSettings);

    _settingsDialog setVariable ["UI_var_initializingView", false];

    // the earplugs settings in their section, in the first rows (where the checkbox of the first setting is)
    private _earplugs = [[], 0, 0];

    if ((missionNamespace getVariable ["E_var_running", false]) && {!isNil "E_fnc_embedSettings"}) then {
        (ctrlPosition (_settingsDialog displayCtrl 2800)) params ["_left", "_top"];
        _earplugs = [_settingsDialog, _left, _top] call E_fnc_embedSettings;
    };

    uiNamespace setVariable ["SC_var_settingsEarplugsControls", _earplugs select 0];
    (_settingsDialog displayCtrl ((SC_var_settingsSections select SC_var_settingsEarplugsSection) select 0))
        ctrlShow ((_earplugs select 0) isNotEqualTo []);

    [_settingsDialog, _earplugs select 1] call SC_fnc_fitSettingsDialog;

    // the section shown last (the earplugs one only while the mod runs)
    private _section = missionNamespace getVariable ["SC_var_settingsSection", 0];

    if ((_section == SC_var_settingsEarplugsSection) && {(_earplugs select 0) isEqualTo []}) then {
        _section = 0;
    };

    [_section] call SC_fnc_settingsShowSection;
};

// the controls of a section of the settings dialog
SC_fnc_settingsSectionControls = {
    params ["_display", "_section"];

    (SC_var_settingsSections select _section) params ["", "_indexes", "_idcs"];

    private _controls = [];

    {
        _controls pushBack (_display displayCtrl (2800 + _x));
        _controls pushBack (_display displayCtrl ([_x] call SC_fnc_settingLabelIdc));
    } forEach _indexes;

    _controls append (_idcs apply {_display displayCtrl _x});

    if (_section == SC_var_settingsEarplugsSection) then {
        _controls append (uiNamespace getVariable ["SC_var_settingsEarplugsControls", []]);
    };

    _controls
};

// shows the controls of one section, its tab in the accent color
SC_fnc_settingsShowSection = {
    params ["_section"];

    private _display = uiNamespace getVariable ["SC_var_settingsDialog", displayNull];

    if (isNull _display) exitWith {};

    SC_var_settingsSection = _section;

    {
        private _shown = _forEachIndex == _section;

        {
            _x ctrlShow _shown;
        } forEach ([_display, _forEachIndex] call SC_fnc_settingsSectionControls);

        (_display displayCtrl (_x select 0)) ctrlSetBackgroundColor ([[0, 0, 0, 0.4], ["accent"] call UI_fnc_color] select _shown);
    } forEach SC_var_settingsSections;
};

// The settings dialog as wide as its longest row (texts have the vanilla size, their width depends on the screen): the
// longest label, the earplugs rows (_earplugsWidth cells) and the four tabs. Labels, body and title get the new width,
// the tabs share it, everything moves so that the dialog stays centred.
SC_fnc_fitSettingsDialog = {
    params ["_display", ["_earplugsWidth", 0]];

    (call SC_fnc_hudGrid) params ["_gridW", "_gridH"];

    private _bodyPos = ctrlPosition (_display displayCtrl 1000);
    _bodyPos params ["_left"];

    private _labelIdcs = [1004, 1027];

    {
        _labelIdcs append ((_x select 1) apply {[_x] call SC_fnc_settingLabelIdc});
    } forEach SC_var_settingsSections;

    private _tabIdcs = SC_var_settingsSections apply {_x select 0};

    // right edge of every row relative to the dialog's left edge, plus the padding
    private _width = (_earplugsWidth + 0.5) * _gridW;

    {
        private _label = _display displayCtrl _x;
        private _textWidth = (ctrlText _label) getTextWidth ["RobotoCondensed", _gridH];

        _width = _width max ((((ctrlPosition _label) select 0) - _left) + _textWidth + 0.3 * _gridW);
    } forEach _labelIdcs;

    {
        _width = _width max (0.5 * _gridW + 4 *(((ctrlText (_display displayCtrl _x)) getTextWidth [
            "RobotoCondensed", _gridH]) + 0.6 * _gridW) + 3 * 0.1 * _gridW);
    } forEach _tabIdcs;

    _width = _width + 0.5 * _gridW;

    private _newLeft = safeZoneX + 0.5 * (safeZoneW - _width);
    private _tabWidth = (_width - _gridW - 3 * 0.1 * _gridW) / 4;

    {
        private _pos = ctrlPosition _x;
        private _offset = (_pos select 0) - _left;
        private _idc = ctrlIDC _x;

        _pos set [0, _newLeft + _offset];

        switch true do {
            case (_idc in [1000, 1002]): {
                _pos set [2, _width];
            };
            case (_idc in _labelIdcs): {
                _pos set [2, _width - _offset - 0.5 * _gridW];
            };
            case (_idc in _tabIdcs): {
                _pos set [0, _newLeft + 0.5 * _gridW + (_tabIdcs find _idc) * (_tabWidth + 0.1 * _gridW)];
                _pos set [2, _tabWidth];
            };
        };

        _x ctrlSetPosition _pos;
        _x ctrlCommit 0;
    } forEach (allControls _display);
};

// Equal slider travel corresponds to equal changes in sqrt(distance): finer nearby, coarser far away.
SC_fnc_viewDistanceSliderPosition = UI_fnc_viewDistanceSliderPosition;
SC_fnc_viewDistanceStep = UI_fnc_viewDistanceStep;
SC_fnc_roundViewDistance = UI_fnc_roundViewDistance;
SC_fnc_settingsViewDistanceChanged = {
    _this call UI_fnc_settingsSliderChanged;
};

SC_fnc_keySettingsDialog = {
    params ["", "_key"];

    if (_key == 62) then { // F4
        if (isNull (uiNamespace getVariable ["SC_var_settingsDialog", displayNull])) then {
            createDialog "settingsDialog";
        } else {

            closeDialog 2;
        };

        true
    }
};

SC_fnc_keyPanel = {
    params ["", "_key"];

    if (_key == 61) then { // F3
        [20] call SC_fnc_toggleSetting;

        if !(isNull (uiNamespace getVariable ["SC_var_settingsDialog", displayNull])) then {
            ((uiNamespace getVariable "SC_var_settingsDialog") displayCtrl 2820) cbSetChecked SC_var_gpsPanelEnabled;
        };

        true
    }
};

SC_fnc_keyHud = {
    params ["", "_key"];

    if (_key == 60) then { // F2
        if (SC_var_hudSwitchCooldown == 0) then {
            call SC_fnc_toggleHud;
            SC_var_hudSwitchCooldown = 1;

            if !(isNull (uiNamespace getVariable ["SC_var_settingsDialog", displayNull])) then {
                ((uiNamespace getVariable "SC_var_settingsDialog") displayCtrl 2800) cbSetChecked SC_var_hudEnabled;
            };

            [] spawn {
                sleep 0.1;
                SC_var_hudSwitchCooldown = 0;
            };
        };

        true
    };
};

// ---- earplugs (earplugs mod: F1, its settings with Ctrl+F1 or the button in the settings dialog) ----

// The hooks of the mod. _ready false while loading: the black loading screen keeps the sound muted until
// SC_fnc_onRespawn fades it in; afterwards the round end sets its own volume (death and SC's spectator suspend the mod
// by themselves: the player is dead). The icon only with SC's HUD, at SC_fnc_earplugsIconPosition.
SC_fnc_setEarplugsHooks = {
    params ["_ready"];

    E_var_suspendCondition = [{true}, {missionNamespace getVariable ["SC_var_roundEnded", false]}] select _ready;
    E_var_iconCondition = {missionNamespace getVariable ["SC_var_hudShown", false]};
    E_var_iconPosition = {call SC_fnc_earplugsIconPosition};
};

// While the player stats panel is shown, the icon sits above its right column at the right screen edge: right aligned with the rank bar, above it; otherwise at the mod's default place left of the vanilla
// weapon info.
SC_fnc_earplugsIconPosition = {
    private _default = call E_fnc_defaultIconPosition;
    private _display = uiNamespace getVariable ["SC_var_sectorControlDisplay", displayNull];

    if (
    isNull _display || {isNull (missionNamespace getVariable ["SC_var_hudUpdatePlayerStatsLoopScript", scriptNull])} || {isNil "SC_var_hudSpawnVehicleRowCount"}
    ) exitWith {_default};

    _default params ["", "", "_w", "_h"];

    (call SC_fnc_hudGrid) params ["", "_gridH"];
    (ctrlPosition (_display displayCtrl 1005)) params ["_rankX", "_rankY", "_rankW"];

    [_rankX + _rankW - _w, _rankY - E_var_iconGap * _gridH - _h, _w, _h]
};
