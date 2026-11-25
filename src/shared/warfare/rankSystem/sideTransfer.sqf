// Side transfer: converts a loadout to the equivalent items of another side (same rank and variant) (client).

// ---- side transfer ----
// The by-rank tables (SC_fnc_buildItemsByRank): [[rank, [westItems, eastItems, guerItems]], ...]

// rank of a worn item in a by-rank table (in any side's list): -1 = nothing worn, -2 = in no table (e.g. picked up)
SC_fnc_getItemRankInTable = {
    params ["_table", "_class"];

    if (_class == "") exitWith {-1};

    private _index = _table findIf {((_x select 1) findIf {(_x findIf {_x == _class}) != -1}) != -1};

    if (_index == -1) then {-2} else {(_table select _index) select 0}
};

// the new side's equivalent of a worn item: same rank and variant slot (index in its side's list of that rank), else
// the first item of that rank; without an item of that rank, the best lower rank. "" = keep the worn item (not in
// the table, no equivalent or already the equivalent)
SC_fnc_translateItem = {
    params ["_table", "_class", "_oldSide", "_newSide"];

    if (_class == "") exitWith {""};

    private _newSideIndex = SC_var_sides find _newSide;
    private _oldSideIndex = SC_var_sides find _oldSide;
    private _sideIndices = [0, 1, 2];

    // the old side's list first (an item can be in several sides' lists, e.g. from general[])
    if (_oldSideIndex != -1) then {
        _sideIndices = [_oldSideIndex] + (_sideIndices - [_oldSideIndex]);
    };

    private _rank = -1;
    private _variant = 0;

    {
        private _sideIndex = _x;

        {
            _x params ["_entryRank", "_sidesItems"];

            private _index = (_sidesItems select _sideIndex) findIf {_x == _class};

            if (_index != -1) exitWith {
                _rank = _entryRank;
                _variant = _index;
            };
        } forEach _table;

        if (_rank != -1) exitWith {};
    } forEach _sideIndices;

    if ((_rank == -1) || {_newSideIndex == -1}) exitWith {""};

    private _bestRank = -1;
    private _bestItems = [];

    {
        _x params ["_entryRank", "_sidesItems"];

        private _items = _sidesItems select _newSideIndex;

        if ((_items isNotEqualTo []) && {_entryRank <= _rank} && {_entryRank > _bestRank}) then {
            _bestRank = _entryRank;
            _bestItems = _items;
        };
    } forEach _table;

    if (_bestItems isEqualTo []) exitWith {""};

    private _newClass = _bestItems param [_variant, _bestItems select 0];

    if (_newClass == _class) then {""} else {_newClass}
};

// [side, NVG rank, uniform rank, helmet rank, vest rank, backpack rank] of the worn gear (-1 = none, -2 = not in a
// by-rank table)
SC_fnc_getLoadoutInfo = {
    [
        side (group player),
        [SC_var_nvGogglesByRank, hmd player] call SC_fnc_getItemRankInTable,
        [SC_var_uniformsByRank, uniform player] call SC_fnc_getItemRankInTable,
        [SC_var_helmetsByRank, headgear player] call SC_fnc_getItemRankInTable,
        [SC_var_vestsByRank, vest player] call SC_fnc_getItemRankInTable,
        [SC_var_backpacksByRank, backpack player] call SC_fnc_getItemRankInTable
    ]
};

// a loadout of another side: the side specific gear is replaced by the player side's equivalent
// (SC_fnc_translateItem); gear without an equivalent is kept
SC_fnc_adjustLoadoutAndInfo = {
    private _loadoutSide = SC_var_lastLoadoutInfo select 0;

    if (_loadoutSide == playerSide) exitWith {};

    {
        player unlinkItem _x;
    } forEach ((assignedItems player) select {"UavTerminal" in _x});

    player linkItem (SC_var_wgUavTerminals select (SC_var_sides find (side (group player))));

    private _nvGoggles = [SC_var_nvGogglesByRank, hmd player, _loadoutSide, playerSide] call SC_fnc_translateItem;

    if (_nvGoggles != "") then {
        player unlinkItem (hmd player);
        player linkItem _nvGoggles;
    };

    private _uniform = [SC_var_uniformsByRank, uniform player, _loadoutSide, playerSide] call SC_fnc_translateItem;

    if (_uniform != "") then {
        private _uniformItems = uniformItems player;
        removeUniform player;
        player forceAddUniform _uniform;
        {player addItemToUniform _x;} forEach _uniformItems;
    };

    private _helmet = [SC_var_helmetsByRank, headgear player, _loadoutSide, playerSide] call SC_fnc_translateItem;

    if (_helmet != "") then {
        removeHeadgear player;
        player addHeadgear _helmet;
    };

    private _vest = [SC_var_vestsByRank, vest player, _loadoutSide, playerSide] call SC_fnc_translateItem;

    if (_vest != "") then {
        private _vestItems = vestItems player;
        removeVest player;
        player addVest _vest;
        {player addItemToVest _x;} forEach _vestItems;
    };

    private _backpack = [SC_var_backpacksByRank, backpack player, _loadoutSide, playerSide] call SC_fnc_translateItem;

    if (_backpack != "") then {
        private _backpackItems = backpackItems player;
        removeBackpack player;
        player addBackpack _backpack;
        clearAllItemsFromBackpack player;
        {player addItemToBackpack _x;} forEach _backpackItems;
    };

    SC_var_lastLoadoutInfo = call SC_fnc_getLoadoutInfo;
    SC_var_lastLoadout = getUnitLoadout player;
};
