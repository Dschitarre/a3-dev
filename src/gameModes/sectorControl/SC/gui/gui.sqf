SC_fnc_getHudColor = {
    params ["_side"];

    switch _side do {
        case WEST: {[0, 0.4, 0.7, 0.85]};
        case EAST: {[0.7, 0, 0, 0.85]};
        case INDEPENDENT: {[0, 0.6, 0.3, 0.85]};
        default {[0, 0, 0, 0.35]};
    }
};

SC_fnc_transformAlignToSafezone = {
    params ["_x","_y","_w","_h","_align"];

    _aspectRatio = (getResolution select 0) / (getResolution select 1);
    _safezoneWCorrected = safeZoneW * ((16 / 9) / _aspectRatio);
    _safeZoneXCorrected = switch _align do {
        case "LEFT": {safeZoneX};
        case "RIGHT": {safeZoneX + safeZoneW - _safezoneWCorrected};
        case "CENTER": {safeZoneX + (safeZoneW - _safezoneWCorrected) / 2};
    };

    [
        _safeZoneXCorrected + _safezoneWCorrected * _x,
        safeZoneY + safeZoneH * (1 - _y),
        _safezoneWCorrected * _w,
        safeZoneH * _h
    ]
};

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
            (SC_var_alwaysShowHudOnMap && visibleMap) ||
            {SC_var_alwaysShowHudWhenUnconscious && (player getVariable ["AIS_unconscious", false])}
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
        SC_var_hudEnabled ||
        {SC_var_alwaysShowHudOnMap && visibleMap} ||
        {SC_var_alwaysShowHudWhenUnconscious && (player getVariable ["AIS_unconscious", false])}
    ] call SC_fnc_setHud;
};

SC_fnc_setupSettingsDialog = {
    _settingsDialog = uiNamespace getVariable "SC_var_settingsDialog";

    for "_i" from 0 to ((count SC_var_settings) - 1) do {
        (_settingsDialog displayCtrl (2800 + _i)) cbSetChecked (SC_var_settings select _i);
    };

    (_settingsDialog displayCtrl 1900) sliderSetRange [0, 1];
    (_settingsDialog displayCtrl 1900) sliderSetPosition ((viewDistance - 500) / 3500);

    (_settingsDialog displayCtrl 1901) sliderSetRange [0, 1];
    (_settingsDialog displayCtrl 1901) sliderSetPosition (profileNameSpace getVariable ["SC_var_currentGrassViewDistanceFactor", 1]);
};

SC_fnc_getLoadoutName = {
    params ["_loadout", "_perks"];

    (
        (
            (
                [
                    ((_loadout select 0) select 0),
                    ((_loadout select 1) select 0)
                ] select {_x != ""}
            ) apply {[_x] call SC_fnc_getDisplayName}
        ) joinString " & "
    ) +
    " [" + ((_perks select {_x != ""}) joinString ", ") + "]"
};

SC_fnc_setupLoadoutDialog = {
    _loadoutDialog = uiNamespace getVariable "SC_var_loadoutDialog";
    _combo = _loadoutDialog displayCtrl 2100;
    
    {
        _x params ["", "", "", ["_worldGroup", "2035"]];

        if (_worldGroup == SC_var_currentWorldGroup) then {
            _combo lbAdd (_x call SC_fnc_getLoadoutName);
        };
    } forEach (profileNameSpace getVariable ["SC_var_storedLoadouts", []]);

    _combo lbAdd "New Loadout";
    _numLoadouts = (lbSize _combo) - 1;
    _combo lbSetCurSel _numLoadouts;
};

SC_fnc_storeLoadout = {
    if !(call SC_fnc_isLoadoutValid) exitWith {
        ["loadoutNotSaved"] call BIS_fnc_showNotification;
    };

    _loadoutDialog = uiNamespace getVariable "SC_var_loadoutDialog";
    _combo = _loadoutDialog displayCtrl 2100;
    _numLoadouts = (lbSize _combo) - 1;
    _idxToStore = lbCurSel _combo;
    _newLoadout = [(getUnitLoadout player), +SC_var_perks, (call SC_fnc_getLoadoutInfo), SC_var_currentWorldGroup];
    _newLoadouts = profileNameSpace getVariable ["SC_var_storedLoadouts", []];

    if (_idxToStore == _numLoadouts) then {
        _newLoadouts pushBack _newLoadout;
    } else {
        _newLoadouts set [_idxToStore, _newLoadout];
    };
    
    _combo lbsetText [_idxToStore, (_newLoadout call SC_fnc_getLoadoutName)];
    profileNameSpace setVariable ["SC_var_storedLoadouts", _newLoadouts];
    saveProfileNameSpace;

    if (_idxToStore == _numLoadouts) then {
        _combo lbAdd "New Loadout";
    };
};

SC_fnc_loadLoadout = {
    _loadoutDialog = uiNamespace getVariable "SC_var_loadoutDialog";
    _combo = _loadoutDialog displayCtrl 2100;
    _numLoadouts = (lbSize _combo) - 1;
    _idxToLoad = lbCurSel _combo;

    if (_idxToLoad == _numLoadouts) then {
        SC_var_lastLoadout = +SC_var_baseLoadout;
        [SC_var_lastLoadout] call SC_fnc_setLoadout;
        SC_var_perks = [];
        SC_var_lastloadoutInfo = SC_var_baseLoadoutInfo;
    } else {
        ((profileNameSpace getVariable "SC_var_storedLoadouts") select _idxToLoad) params ["_loadout", "_perks", "_loadoutInfo"];
        SC_var_lastLoadout = +_loadout;
        SC_var_perks = +_perks;
        [SC_var_lastLoadout] call SC_fnc_setLoadout;
        SC_var_lastloadoutInfo = +_loadoutInfo;
        call SC_fnc_adjustLoadoutAndInfo;
    };

    [SC_var_equip, playerSide, (player getVariable "SC_var_rank"), +SC_var_perks] call SC_fnc_changePerks;
    call SC_fnc_saveLoadoutToProfile;

    if SC_var_hudEnabled then {
        ["loadoutLoaded"] call BIS_fnc_showNotification;
    };
};

SC_fnc_deleteLoadout = {
    _loadoutDialog = uiNamespace getVariable "SC_var_loadoutDialog";
    _combo = _loadoutDialog displayCtrl 2100;
    
    _allLoadouts = profileNameSpace getVariable ["SC_var_storedLoadouts", []];
    _worldGroupsLoadouts = _allLoadouts select {
        _x params ["", "", "", ["_worldGroup", "2035"]];

        (_worldGroup == SC_var_currentWorldGroup)
    };
    _otherLoadouts = _allLoadouts - _worldGroupsLoadouts;

    _numLoadouts = (lbSize _combo) - 1;
    _idxToDelete = lbCurSel _combo;
    if ((_numLoadouts == 0) || {_idxToDelete == _numLoadouts}) exitWith {};
    _worldGroupsLoadouts deleteAt _idxToDelete;
    _allLoadouts = _otherLoadouts + _worldGroupsLoadouts;
    profileNameSpace setVariable ["SC_var_storedLoadouts", +_allLoadouts];
    saveProfileNameSpace;

    _combo lbDelete _idxToDelete;
    _combo lbSetCurSel (_numLoadouts - 1);
};

SC_fnc_getPerkFromPerkAbbrev = {
    params ["_perkAbbrev"];

    (SC_var_perkConfig select (SC_var_perkConfig findIf {(_x select 1) == _perkAbbrev})) select 0
};

SC_fnc_getPerkAbbrevFromPerk = {
    params ["_perk"];

    (SC_var_perkConfig select (SC_var_perkConfig findIf {(_x select 0) == _perk})) select 1
};

SC_fnc_setupPerkDialog = {
    _perkDialog = uiNamespace getVariable "SC_var_perkDialog";
    _rank = player getVariable "SC_var_rank";

    _possiblePerks = SC_var_perkConfig select {(_x select 2) <= _rank};
    _unselectedPerks = _possiblePerks select {!((_x select 1) in SC_var_perks)};
    _numPossiblePerks = {!(isNil "_x") && {_x <= _rank}} count SC_var_rankForPerkId;
    _numEquippedPerks = count SC_var_perks;
    _numUnselectedPerks = count _unselectedPerks;
    SC_var_overridePerkChange = true;

    for "_i" from 0 to 5 do {
        _combo = _perkDialog displayCtrl (2100 + _i);
        lbClear _combo;
        _numEntries = 0;
        _selectedPerk = "";

        if (_i < _numPossiblePerks) then {
            {_combo lbAdd (_x select 0);} forEach _unselectedPerks;
            _numEntries = _numUnselectedPerks + 1;

            if (_i < _numEquippedPerks) then {
                _selectedPerk = [SC_var_perks select _i] call SC_fnc_getPerkFromPerkAbbrev;
            } else {
                _selectedPerk = "----";
            };
        } else {
            _selectedPerk = "----";
            _numEntries = 1;
        };

        _combo lbAdd _selectedPerk;
        lbSort _combo;
        _idxSelectedPerk = 0;

        for "_j" from 1 to (_numEntries - 1) do {
            if ((_combo lbText _j) == _selectedPerk) then {
                _idxSelectedPerk = _j;
            };
        };

        _combo lbSetCurSel _idxSelectedPerk;
    };

    SC_var_overridePerkChange = false;
};

SC_fnc_changePerk = {
    params ["_perkSlot", "_index"];

    _perkDialog = uiNamespace getVariable "SC_var_perkDialog";
    _combo = _perkDialog displayCtrl (2100 + _perkSlot);
    _rank = player getVariable "SC_var_rank";
    _numPossiblePerks = {(_x select 2) <= _rank} count SC_var_perkConfig;

    if (!SC_var_overridePerkChange && {_perkSlot < _numPossiblePerks}) then {
        _newPerk = _combo lbText _index;
        _newPerkAbbrev = [_newPerk] call SC_fnc_getPerkAbbrevFromPerk;
        _oldPerkAbbrev = SC_var_perks select _perkSlot;
        _removedEquipment = (_newPerkAbbrev == "MEDC") || {_oldPerkAbbrev in ["MGNR", "MEDC", "LNCR", "MRKS", "ARMR", "GRND", "SUPR"]};
        SC_var_perks set [_perkSlot, _newPerkAbbrev];
        [SC_var_equip, playerSide, (player getVariable "SC_var_rank"), +SC_var_perks, _removedEquipment] call SC_fnc_changePerks;
        call SC_fnc_setupPerkDialog;
    };
};