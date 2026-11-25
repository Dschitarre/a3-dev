// Stored loadouts dialog: storing, loading and deleting named loadouts (client).

// ---- stored loadouts dialog ----

SC_fnc_getUsableStoredLoadouts = {
    (profileNamespace getVariable ["SC_var_storedLoadouts", []]) select {(_x select 3) == SC_var_currentWorldGroup}
};

SC_fnc_setupLoadoutDialog = {
    private _loadoutDialog = uiNamespace getVariable "SC_var_loadoutDialog";
    private _controlsTable = _loadoutDialog displayCtrl 1500;
    (ctAddHeader _controlsTable) params ["", "_header"];

    _header params ["",
        "_ctrlColumn1", "_ctrlColumn2", "_ctrlColumn3",
        "_ctrlColumn4", "_ctrlColumn5"
    ];

    [_header] call SC_fnc_styleTableHeader;
    _ctrlColumn1 ctrlSetText "Weapon";
    _ctrlColumn2 ctrlSetText "Launcher";
    _ctrlColumn3 ctrlSetText "Sidearm";
    _ctrlColumn4 ctrlSetText "Apparel";
    _ctrlColumn5 ctrlSetText "Perks";

    private _loadouts = call SC_fnc_getUsableStoredLoadouts;
    _loadouts pushBack [[[],[],[],[],[],[],"","",[],["","","","","",""]], [], SC_var_baseLoadoutInfo, SC_var_currentWorldGroup];

    {
        _x params ["_loadout", "_perks"];
        _loadout params ["_primaryArr", "_launcherArr", "_sidearmArr", "_uniformArr", "_vestArr", "_backpackArr", "_helmet"];

        private _primaryWeapon = if (_primaryArr isEqualTo []) then {""} else {_primaryArr select 0};
        private _launcher = if (_launcherArr isEqualTo []) then {""} else {_launcherArr select 0};
        private _sidearm = if (_sidearmArr isEqualTo []) then {""} else {_sidearmArr select 0};
        private _uniform = if (_uniformArr isEqualTo []) then {""} else {_uniformArr select 0};
        private _vest = if (_vestArr isEqualTo []) then {""} else {_vestArr select 0};
        private _backpack = if (_backpackArr isEqualTo []) then {""} else {_backpackArr select 0};
        _helmet = if (_helmet isEqualTo "") then {""} else {_helmet};

        (ctAddRow _controlsTable) params ["", "_row"];

        _row params ["",
            "_ctrlColumn1", "_ctrlColumn2", "_ctrlColumn3",
            "_ctrlColumn4", "_ctrlColumn5", "_ctrlColumn6",
            "_ctrlColumn7", "_ctrlColumn8"
        ];

        [_row] call SC_fnc_styleTableRow;

        _ctrlColumn1 ctrlSetText ([_primaryWeapon] call SC_fnc_getPicture);
        _ctrlColumn2 ctrlSetText ([_launcher] call SC_fnc_getPicture);
        _ctrlColumn3 ctrlSetText ([_sidearm] call SC_fnc_getPicture);
        _ctrlColumn4 ctrlSetText ([_uniform] call SC_fnc_getPicture);
        _ctrlColumn5 ctrlSetText ([_vest] call SC_fnc_getPicture);
        _ctrlColumn6 ctrlSetText ([_backpack] call SC_fnc_getPicture);
        _ctrlColumn7 ctrlSetText ([_helmet] call SC_fnc_getPicture);
        _ctrlColumn8 ctrlSetText ((_perks apply {"[" + _x + "]"}) joinString " ");
    } forEach _loadouts;
};

SC_fnc_storeLoadout = {
    if !(call SC_fnc_isLoadoutValid) exitWith {
        ["loadoutNotSaved"] call BIS_fnc_showNotification;
    };

    private _loadoutDialog = uiNamespace getVariable "SC_var_loadoutDialog";
    private _controlsTable = _loadoutDialog displayCtrl 1500;
    private _numLoadouts = (ctRowCount _controlsTable) - 1;
    private _idxToStore = ctCurSel _controlsTable;

    // nothing selected
    if (_idxToStore == -1) exitWith {};

    private _newLoadout = [(getUnitLoadout player), +SC_var_perks, (call SC_fnc_getLoadoutInfo), SC_var_currentWorldGroup];
    private _allLoadouts = profileNamespace getVariable ["SC_var_storedLoadouts", []];

    if (_idxToStore == _numLoadouts) then {
        _allLoadouts pushBack +_newLoadout;
    } else {
        private _worldGroupsLoadouts = call SC_fnc_getUsableStoredLoadouts;
        private _otherLoadouts = _allLoadouts - _worldGroupsLoadouts;
        _worldGroupsLoadouts set [_idxToStore, +_newLoadout];
        _allLoadouts = _worldGroupsLoadouts + _otherLoadouts;
    };

    profileNamespace setVariable ["SC_var_storedLoadouts", _allLoadouts];
    saveProfileNamespace;

    closeDialog 2;
    createDialog "loadoutDialog";
};

SC_fnc_loadLoadout = {
    private _loadoutDialog = uiNamespace getVariable "SC_var_loadoutDialog";
    private _controlsTable = _loadoutDialog displayCtrl 1500;
    private _numLoadouts = (ctRowCount _controlsTable) - 1;
    private _idxToLoad = ctCurSel _controlsTable;

    // nothing selected
    if (_idxToLoad == -1) exitWith {};

    if (_idxToLoad == _numLoadouts) then {
        SC_var_lastLoadout = +SC_var_baseLoadout;
        [SC_var_lastLoadout] call SC_fnc_setLoadout;
        SC_var_perks = [];
        SC_var_lastLoadoutInfo = +SC_var_baseLoadoutInfo;
    } else {
        private _usableLoadouts = call SC_fnc_getUsableStoredLoadouts;
        (_usableLoadouts select _idxToLoad) params ["_loadout", "_perks", "_loadoutInfo"];
        SC_var_lastLoadout = +_loadout;
        SC_var_perks = +_perks;
        [SC_var_lastLoadout] call SC_fnc_setLoadout;
        SC_var_lastLoadoutInfo = +_loadoutInfo;
        call SC_fnc_adjustLoadoutAndInfo;
    };

    [SC_var_equip, playerSide, (player getVariable "SC_var_rank"), +SC_var_perks] call SC_fnc_changePerks;
    call SC_fnc_saveLoadoutToProfile;

    if SC_var_hudEnabled then {
        ["loadoutLoaded"] call BIS_fnc_showNotification;
    };
};

SC_fnc_deleteLoadout = {
    private _loadoutDialog = uiNamespace getVariable "SC_var_loadoutDialog";
    private _controlsTable = _loadoutDialog displayCtrl 1500;

    private _allLoadouts = profileNamespace getVariable ["SC_var_storedLoadouts", []];
    private _worldGroupsLoadouts = call SC_fnc_getUsableStoredLoadouts;
    private _otherLoadouts = _allLoadouts - _worldGroupsLoadouts;

    private _numLoadouts = (ctRowCount _controlsTable) - 1;
    private _idxToDelete = ctCurSel _controlsTable;
    if ((_numLoadouts == 0) || {_idxToDelete in [-1, _numLoadouts]}) exitWith {};
    _worldGroupsLoadouts deleteAt _idxToDelete;
    _allLoadouts = _otherLoadouts + _worldGroupsLoadouts;
    profileNamespace setVariable ["SC_var_storedLoadouts", +_allLoadouts];
    saveProfileNamespace;

    _controlsTable ctRemoveRows [_idxToDelete];
};
