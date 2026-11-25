// Arsenal limits: unlocked cargo, locked items (reduce only) and VA_maxItemCounts; counting and clamping loadouts (client).

// ---- arsenal rules: max item counts, locked items ----

// VA_maxItemCounts[] = {{"class", max}, ...} of the mission config as a hash map (lower case class -> max count in
// uniform + vest + backpack), empty without the array; cached in missionNamespace
VA_fnc_getMaxItemCounts = {
    private _maxCounts = missionNamespace getVariable "VA_var_maxItemCounts";

    if (isNil "_maxCounts") then {
        _maxCounts = createHashMap;

        {
            if (_x isEqualTypeArray ["", 0]) then {
                _maxCounts set [toLower (_x select 0), 0 max (floor (_x select 1))];
            };
        } forEach (getArray (missionConfigFile >> "VA_maxItemCounts"));

        missionNamespace setVariable ["VA_var_maxItemCounts", _maxCounts];
    };

    _maxCounts
};

// the arsenal content without the gear of the unit (which the arsenal lists too): [lower case classes (hash map),
// "%all" of [items, weapons, magazines, backpacks]]; like the arsenal, weapons also unlock their base weapon and
// their linked items
VA_fnc_getUnlockedCargo = {
    params ["_cargo"];

    private _classes = createHashMap;
    private _all = [];
    private _weapons = [];

    {
        private _list = (missionNamespace call _x) + (_cargo call _x);

        if (_forEachIndex == 1) then {
            _weapons = _list;
        };

        _list = _list apply {toLower _x};
        _all pushBack ("%all" in _list);

        {
            _classes set [_x, true];
        } forEach _list;
    } forEach [BIS_fnc_getVirtualItemCargo, BIS_fnc_getVirtualWeaponCargo, BIS_fnc_getVirtualMagazineCargo,
        BIS_fnc_getVirtualBackpackCargo];

    {
        if ((toLower _x) != "%all") then {
            _classes set [toLower (_x call BIS_fnc_baseWeapon), true];

            {
                _classes set [toLower (getText (_x >> "item")), true];
            } forEach ("true" configClasses (configFile >> "CfgWeapons" >> _x >> "LinkedItems"));
        };
    } forEach _weapons;

    [_classes, _all]
};

// whether a class is in the arsenal content (_unlocked: VA_fnc_getUnlockedCargo, [] = not known: everything is)
VA_fnc_isUnlocked = {
    params ["_class", "_unlocked"];

    if ((_class == "") || {_unlocked isEqualTo []} || {missionNamespace getVariable ["BIS_fnc_arsenal_fullArsenal", false]}) exitWith {true};

    _unlocked params ["_classes", "_all"];

    if ((toLower _class) in _classes) exitWith {true};

    // weapon variants with attachments count as their base weapon
    if ((isClass (configFile >> "CfgWeapons" >> _class)) && {(toLower (_class call BIS_fnc_baseWeapon)) in _classes}) exitWith {true};

    if !(true in _all) exitWith {false};

    private _index = [_class] call VA_fnc_getCargoIndex;

    (_index != -1) && {_all select _index}
};

VA_fnc_addCount = {
    params ["_counts", "_class", "_count"];

    if ((_class isEqualType "") && {_class != ""}) then {
        private _key = toLower _class;
        _counts set [_key, (_counts getOrDefault [_key, 0]) + _count];
    };
};

// getUnitLoadout weapon: [weapon, muzzle item, pointer, optic, [magazine, ammo], [magazine, ammo], bipod]
VA_fnc_countWeapon = {
    params ["_counts", "_weapon", "_count"];

    {
        if (_x isEqualType "") then {
            [_counts, _x, _count] call VA_fnc_addCount;
        } else {
            if ((_x isEqualType []) && {_x isNotEqualTo []}) then {
                [_counts, _x select 0, _count] call VA_fnc_addCount;
            };
        };
    } forEach _weapon;
};

// [all classes of a getUnitLoadout array, the uniform + vest + backpack contents] as hash maps (lower case class ->
// count)
VA_fnc_countLoadout = {
    params ["_loadout"];

    private _all = createHashMap;
    private _containers = createHashMap;

    _loadout params [
        ["_primary", []], ["_secondary", []], ["_handgun", []],
        ["_uniform", []], ["_vest", []], ["_backpack", []],
        ["_headgear", ""], ["_goggles", ""], ["_binocular", []], ["_linkedItems", []]
    ];

    {
        [_all, _x, 1] call VA_fnc_countWeapon;
    } forEach [_primary, _secondary, _handgun, _binocular];

    {
        if (_x isNotEqualTo []) then {
            _x params ["_container", ["_items", []]];
            [_all, _container, 1] call VA_fnc_addCount;

            {
                _x params ["_item", "_count"];

                if (_item isEqualType []) then {
                    [_all, _item, _count] call VA_fnc_countWeapon;
                    [_containers, _item select 0, _count] call VA_fnc_addCount;
                } else {
                    [_all, _item, _count] call VA_fnc_addCount;
                    [_containers, _item, _count] call VA_fnc_addCount;
                };
            } forEach _items;
        };
    } forEach [_uniform, _vest, _backpack];

    {
        [_all, _x, 1] call VA_fnc_addCount;
    } forEach ([_headgear, _goggles] + _linkedItems);

    [_all, _containers]
};

// how many of _count instances of a class are kept within the budgets (lower case class -> count, classes without a
// budget are not limited; _containerBudget only for container contents); reduces the budgets, adds the rest to
// _removed (class -> count)
VA_fnc_takeBudget = {
    params ["_class", "_count", "_budget", "_containerBudget", "_inContainer", "_removed"];

    if (!(_class isEqualType "") || {_class == ""}) exitWith {_count};

    private _key = toLower _class;
    private _kept = _count min (_budget getOrDefault [_key, _count]);

    if _inContainer then {
        _kept = _kept min (_containerBudget getOrDefault [_key, _kept]);
    };

    _kept = 0 max _kept;

    if (_key in _budget) then {
        _budget set [_key, (_budget get _key) - _kept];
    };

    if (_inContainer && {_key in _containerBudget}) then {
        _containerBudget set [_key, (_containerBudget get _key) - _kept];
    };

    if (_kept < _count) then {
        _removed set [_class, (_removed getOrDefault [_class, 0]) + _count - _kept];
    };

    _kept
};

// limits a getUnitLoadout weapon (one copy) to the budgets in place; false if the weapon itself is not kept
VA_fnc_clampWeapon = {
    params ["_weapon", "_budget", "_containerBudget", "_inContainer", "_removed"];

    if (_weapon isEqualTo []) exitWith {true};
    if (([_weapon select 0, 1, _budget, _containerBudget, _inContainer, _removed] call VA_fnc_takeBudget) == 0) exitWith {false};

    for "_index" from 1 to ((count _weapon) - 1) do {
        private _element = _weapon select _index;

        if (_element isEqualType "") then {
            if (([_element, 1, _budget, _containerBudget, false, _removed] call VA_fnc_takeBudget) == 0) then {
                _weapon set [_index, ""];
            };
        } else {
            if((_element isNotEqualTo []) &&
                {([_element select 0, 1, _budget, _containerBudget, false,
                _removed] call VA_fnc_takeBudget) == 0}) then {
                _weapon set [_index, []];
            };
        };
    };

    true
};

// limits a getUnitLoadout array to the budgets in place (VA_fnc_takeBudget): the equipped items are kept first, then
// the uniform, vest and backpack contents (weapons in them are split into single copies); returns the removed
// [class, count] pairs
VA_fnc_clampLoadout = {
    params ["_loadout", "_budget", ["_containerBudget", createHashMap]];

    private _removed = createHashMap;

    {
        if !([_loadout select _x, _budget, _containerBudget, false, _removed] call VA_fnc_clampWeapon) then {
            _loadout set [_x, []];
        };
    } forEach [0, 1, 2, 8];

    {
        private _container = _loadout select _x;

        if((_container isNotEqualTo []) &&
            {([_container select 0, 1, _budget, _containerBudget, false,
            _removed] call VA_fnc_takeBudget) == 0}) then {
            _loadout set [_x, []];
        };
    } forEach [3, 4, 5];

    {
        if (([_loadout select _x, 1, _budget, _containerBudget, false, _removed] call VA_fnc_takeBudget) == 0) then {
            _loadout set [_x, ""];
        };
    } forEach [6, 7];

    private _linkedItems = _loadout select 9;

    {
        if (([_x, 1, _budget, _containerBudget, false, _removed] call VA_fnc_takeBudget) == 0) then {
            _linkedItems set [_forEachIndex, ""];
        };
    } forEach _linkedItems;

    {
        private _container = _loadout select _x;

        if (_container isNotEqualTo []) then {
            private _items = [];

            {
                _x params ["_item", "_count"];

                if (_item isEqualType []) then {
                    for "_i" from 1 to _count do {
                        private _weapon = +_item;

                        if ([_weapon, _budget, _containerBudget, true, _removed] call VA_fnc_clampWeapon) then {
                            _items pushBack [_weapon, 1];
                        };
                    };
                } else {
                    private _kept = [_item, _count, _budget, _containerBudget, true, _removed] call VA_fnc_takeBudget;

                    if (_kept > 0) then {
                        private _entry = +_x;
                        _entry set [1, _kept];
                        _items pushBack _entry;
                    };
                };
            } forEach (_container select 1);

            _container set [1, _items];
        };
    } forEach [3, 4, 5];

    (keys _removed) apply {[_x, _removed get _x]}
};

// a copy of a getUnitLoadout array with the uniform + vest + backpack contents limited to VA_maxItemCounts (for the
// loadouts a mode restores outside of the arsenal)
VA_fnc_clampLoadoutToMax = {
    params ["_loadout"];

    private _clamped = +_loadout;
    private _maxCounts = call VA_fnc_getMaxItemCounts;

    if ((count _maxCounts) > 0) then {
        [_clamped, createHashMap, +_maxCounts] call VA_fnc_clampLoadout;
    };

    _clamped
};

// removes from the unit what an arsenal action added against the rules (_before: VA_fnc_countLoadout before it):
// - classes that are not in the arsenal beyond their count before
// - uniform + vest + backpack contents beyond VA_maxItemCounts (a count that was carried before is kept unless
//   _strictMax, which loading a loadout uses)
// returns the removed [class, count] pairs
VA_fnc_enforceRules = {
    params ["_unit", "_before", ["_strictMax", false]];

    _before params ["_allBefore", "_containersBefore"];

    private _loadout = getUnitLoadout _unit;
    ([_loadout] call VA_fnc_countLoadout) params ["_all", "_containers"];
    private _unlocked = uiNamespace getVariable ["VA_var_unlockedCargo", []];
    private _maxCounts = call VA_fnc_getMaxItemCounts;
    private _budget = createHashMap;
    private _containerBudget = createHashMap;

    {
        private _allowed = _allBefore getOrDefault [_x, 0];

        if ((_y > _allowed) && {!([_x, _unlocked] call VA_fnc_isUnlocked)}) then {
            _budget set [_x, _allowed];
        };
    } forEach _all;

    {
        private _max = _maxCounts getOrDefault [_x, -1];

        if (_max >= 0) then {
            if !_strictMax then {
                _max = _max max (_containersBefore getOrDefault [_x, 0]);
            };

            if (_y > _max) then {
                _containerBudget set [_x, _max];
            };
        };
    } forEach _containers;

    if (((count _budget) + (count _containerBudget)) == 0) exitWith {[]};

    private _removed = [_loadout, _budget, _containerBudget] call VA_fnc_clampLoadout;
    _unit setUnitLoadout _loadout;

    [format ["RULES: removed %1", _removed]] call VA_fnc_log;
    _removed
};

// short message for the arsenal's message line
VA_fnc_formatRemoved = {
    params ["_removed"];

    "Removed (not available or over the limit): " + ((_removed apply {format ["%1x %2", _x select 1, [_x select 0] call VA_fnc_getDisplayName]}) joinString ", ")
};

// lines for the restricted items message of a loaded loadout
VA_fnc_formatRemovedLines = {
    params ["_removed"];

    private _maxCounts = call VA_fnc_getMaxItemCounts;
    private _lines = "";

    {
        _x params ["_class", "_count"];

        private _max = _maxCounts getOrDefault [toLower _class, -1];

        _lines = _lines + (if (_max >= 0) then {
            format ["<br />Limit %1 - %2 (%3 removed)", _max, _class, _count]
        } else {
            format ["<br />Not available - %1 (%2 removed)", _class, _count]
        });
    } forEach _removed;

    _lines
};

// whether the uniform, vest and backpack items of saved inventory data are within VA_maxItemCounts
VA_fnc_isWithinMaxCounts = {
    params ["_inventory", "_maxCounts"];

    if ((count _maxCounts) == 0) exitWith {true};

    private _counts = createHashMap;

    {
        private _items = (_inventory param [_x, []]) param [1, []];

        {
            [_counts, _x, 1] call VA_fnc_addCount;
        } forEach _items;
    } forEach [0, 1, 2];

    private _within = true;

    {
        if (_y > (_maxCounts getOrDefault [_x, _y])) exitWith {
            _within = false;
        };
    } forEach _counts;

    _within
};
