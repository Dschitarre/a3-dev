// Perks: perk config, perk slots per rank, changing perks and the perk dialog (both).

// ---- perks ----

// perks: [name, abbreviation, required rank]
SC_var_perkConfig = [
    ["Experience", "EXPR", 1],
    ["Medic", "MEDC", 1],
    ["Stamina", "STAM", 5],
    ["Marksman", "MRKS", 7],
    ["Machinegunner", "MGNR", 10],
    ["Launcher", "LNCR", 15],
    ["Armor", "ARMR", 18],
    ["Grenadier", "GRND", 20],
    ["Explosives", "DEMO", 22],
    ["Suppressor", "SUPR", 25]
];

// rank at which perk slot n (1-6) is unlocked, index 0 is unused
SC_var_rankForPerkId = [nil, 1, 6, 18, 35, 67, 100];

SC_fnc_getNumPerkSlots = {
    params ["_rank", ["_maxSlots", 6]];

    {_x <= _rank} count (SC_var_rankForPerkId select [1, _maxSlots])
};

SC_fnc_changePerks = {
    params ["_object", "_side", "_rank", "_newPerks", ["_removedEquipment", false]];

    [_object, (_object call BIS_fnc_getVirtualWeaponCargo), false] call BIS_fnc_removeVirtualWeaponCargo;
    [_object, (_object call BIS_fnc_getVirtualBackpackCargo), false] call BIS_fnc_removeVirtualBackpackCargo;
    [_object, (_object call BIS_fnc_getVirtualItemCargo), false] call BIS_fnc_removeVirtualItemCargo;
    [_object, (_object call BIS_fnc_getVirtualMagazineCargo), false] call BIS_fnc_removeVirtualMagazineCargo;

    ([_side, _newPerks, _rank] call SC_fnc_getItems) params ["_weps", "_bags", "_items", "_mags"];

    [_object, _weps, false, false, 1, 0] call BIS_fnc_addVirtualWeaponCargo;
    [_object, _bags, false, false, 1, 0] call BIS_fnc_addVirtualBackpackCargo;
    [_object, _items, false, false, 1, 0] call BIS_fnc_addVirtualItemCargo;
    [_object, _mags, false, false, 1, 0] call BIS_fnc_addVirtualMagazineCargo;

    private _itemsPlayer = items player;

    if _removedEquipment then {
        // the binocular slot (binoculars, laser designators are items) is handled below
        {player removeWeapon _x;} forEach ((weapons player) select {(_x != (binocular player)) && {!(_x in _weps)}});
        {player removePrimaryWeaponItem _x;} forEach ((primaryWeaponItems player) select {(_x != "") && {!(_x in _items)}});
        {player removeSecondaryWeaponItem _x;} forEach ((secondaryWeaponItems player) select {(_x != "") && {!(_x in _items)}});
        {player removeHandgunItem _x;} forEach ((handgunItems player) select {(_x != "") && {!(_x in _items)}});
        {player removeItems _x;} forEach ((_itemsPlayer arrayIntersect _itemsPlayer) select {!(_x in _items)});
        private _magsPlayer = magazines player;
        {player removeMagazines _x;} forEach ((_magsPlayer arrayIntersect _magsPlayer) select {!(_x in _mags)});
        if !((uniform player) in _items) then {removeUniform player};
        if !((vest player) in _items) then {removeVest player};
        if !((backpack player) in _bags) then {removeBackpackGlobal player};
        if !((headgear player) in _items) then {removeHeadgear player};
        if !((goggles player) in _items) then {removeGoggles player};
        if !((hmd player) in _items) then {player unlinkItem (hmd player)};
    };

    player setUnitTrait ["Medic", ("MEDC" in _newPerks)];
    player setVariable ["SC_var_hasExprPerk", ("EXPR" in _newPerks), true];
    _itemsPlayer = items player;

    if ("MEDC" in SC_var_perks) then {
        if ("FirstAidKit" in _itemsPlayer) then {
            player removeItems "FirstAidKit";
        };

        if !("Medikit" in _itemsPlayer) then {
            player addItem "Medikit";
        };
    } else {
        if !("FirstAidKit" in _itemsPlayer) then {
            for "_i" from 1 to 4 do {
                player addItem "FirstAidKit";
            };
        };
    };

    // everyone gets the default binocular of the perks, unless another allowed one is equipped (laser designator)
    private _currentBinocular = binocular player;
    private _wantedBinocular = ["Binocular", "Rangefinder"] select ("MRKS" in SC_var_perks);
    private _keepCurrent = !(_currentBinocular in ["", "Binocular", "Rangefinder"]) && {(_items findIf {_x == _currentBinocular}) != -1};

    if (!_keepCurrent && {_currentBinocular != _wantedBinocular}) then {
        player removeWeaponGlobal _currentBinocular;
        player addWeaponGlobal _wantedBinocular;
    };

    call SC_fnc_saveLoadoutToProfile;
};

// an empty perk slot is "" (abbreviation) / "----" (name)
SC_fnc_getPerkFromPerkAbbrev = {
    params ["_perkAbbrev"];

    private _idx = SC_var_perkConfig findIf {(_x select 1) == _perkAbbrev};

    if (_idx == -1) then {"----"} else {(SC_var_perkConfig select _idx) select 0}
};

SC_fnc_getPerkAbbrevFromPerk = {
    params ["_perk"];

    private _idx = SC_var_perkConfig findIf {(_x select 0) == _perk};

    if (_idx == -1) then {""} else {(SC_var_perkConfig select _idx) select 1}
};

// the "Perk N" labels as wide as the widest one from the body's padding on, the combos UI_GAP behind them up to the
// padding on the right (SC\dialogs.hpp, perkDialog: label idcs 1102 - 1107, combos 2100 - 2105)
SC_fnc_fitPerkDialog = {
    params ["_dialog"];

    (call UI_fnc_gridCell) params ["_cellW"];
    (ctrlPosition (_dialog displayCtrl 1000)) params ["_bodyX", "", "_bodyW"];

    private _labels = [1102, 1103, 1104, 1105, 1106, 1107] apply {_dialog displayCtrl _x};
    private _labelX = _bodyX + 0.5 * _cellW;
    private _labelW = (selectMax (_labels apply {ctrlTextWidth _x})) + 0.1 * _cellW;
    private _comboX = _labelX + _labelW + 0.1 * _cellW;
    private _comboW = (_bodyX + _bodyW - 0.5 * _cellW) - _comboX;

    {
        private _combo = _dialog displayCtrl (2100 + _forEachIndex);

        (ctrlPosition _x) params ["", "_labelY", "", "_labelH"];
        _x ctrlSetPosition [_labelX, _labelY, _labelW, _labelH];
        _x ctrlCommit 0;

        (ctrlPosition _combo) params ["", "_comboY", "", "_comboH"];
        _combo ctrlSetPosition [_comboX, _comboY, _comboW, _comboH];
        _combo ctrlCommit 0;
    } forEach _labels;
};

SC_fnc_setupPerkDialog = {
    private _perkDialog = uiNamespace getVariable "SC_var_perkDialog";

    [_perkDialog] call SC_fnc_fitPerkDialog;
    private _rank = player getVariable "SC_var_rank";

    private _possiblePerks = SC_var_perkConfig select {(_x select 2) <= _rank};
    private _unselectedPerks = _possiblePerks select {!((_x select 1) in SC_var_perks)};
    private _numPossiblePerks = [_rank] call SC_fnc_getNumPerkSlots;
    private _numEquippedPerks = count SC_var_perks;
    private _numUnselectedPerks = count _unselectedPerks;
    SC_var_overridePerkChange = true;

    for "_i" from 0 to 5 do {
        private _combo = _perkDialog displayCtrl (2100 + _i);
        lbClear _combo;
        private _numEntries = 0;
        private _selectedPerk = "";

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
        private _idxSelectedPerk = 0;

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

    private _perkDialog = uiNamespace getVariable "SC_var_perkDialog";
    private _combo = _perkDialog displayCtrl (2100 + _perkSlot);
    private _rank = player getVariable "SC_var_rank";
    private _numPossiblePerks = [_rank] call SC_fnc_getNumPerkSlots;

    if (!SC_var_overridePerkChange && {_perkSlot < _numPossiblePerks}) then {
        private _newPerk = _combo lbText _index;
        private _newPerkAbbrev = [_newPerk] call SC_fnc_getPerkAbbrevFromPerk;

        while {(count SC_var_perks) < _perkSlot} do {
            SC_var_perks pushBack "";
        };

        private _oldPerkAbbrev = SC_var_perks param [_perkSlot, ""];

        // removing an equipment perk (or choosing the Medic perk, which replaces the first aid kits) removes the gear
        // that isn't allowed anymore
        private _removedEquipment = (_newPerkAbbrev == "MEDC") || {_oldPerkAbbrev in ((SC_var_perkItemConfigs apply {_x select 0}) + ["MEDC"])};
        SC_var_perks set [_perkSlot, _newPerkAbbrev];
        [SC_var_equip, playerSide, (player getVariable "SC_var_rank"), +SC_var_perks, _removedEquipment] call SC_fnc_changePerks;
        call SC_fnc_setupPerkDialog;
    };
};
