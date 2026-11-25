// Magazine repack (server and clients): the settings, the repack rules shared by the inventory button and the AI, and
// the AI repack: every machine repacks the AI units local to it (AI in a group led by a player is local to that
// player's machine) instantly from time to time while they are not in combat.

// ---- settings ----
// Missions may set them before the mod loads or before MR_fnc_startMagRepackServer (which publishes them); the module
// sets them on the server. MR_var_enabled may change any time, also on a single machine: false hides the button,
// stops a running repack and pauses the AI repack.

if (isNil "MR_var_enabled") then {MR_var_enabled = true;};
if (isNil "MR_var_secondsPerRound") then {MR_var_secondsPerRound = 0.12;};   // seconds a player needs per moved round
if (isNil "MR_var_aiRepack") then {MR_var_aiRepack = true;};                 // AI units repack (instantly)
if (isNil "MR_var_aiInterval") then {MR_var_aiInterval = 60;};               // seconds between two AI repacks

MR_var_capacities = createHashMap;   // magazine class -> rounds of a full magazine
MR_var_aiRunning = false;
MR_var_aiLoopScript = scriptNull;

// ---- magazines of a unit ----
// A magazine is a slot [place, ammo, muzzle]: place 0 / 1 / 2 = in the uniform / vest / backpack (MR_fnc_containers),
// -1 = loaded in the weapon muzzle _muzzle (else ""). Only types with more than one round take part (no grenades,
// rockets, single grenade launcher shells).

MR_fnc_capacity = {
    params ["_type"];

    private _capacity = MR_var_capacities get _type;

    if (isNil "_capacity") then {
        _capacity = getNumber (configFile >> "CfgMagazines" >> _type >> "count");
        MR_var_capacities set [_type, _capacity];
    };

    _capacity
};

MR_fnc_containers = {
    params ["_unit"];

    [uniformContainer _unit, vestContainer _unit, backpackContainer _unit]
};

// The repackable magazines loaded in the unit's weapons: [type, ammo, muzzle]. A magazine is only taken when "ammo"
// confirms it under the muzzle name, because setAmmo refills it by that name later (the first muzzle has the weapon's
// name; another muzzle, e.g. the grenade launcher, its own - weapons with a safety muzzle have one more).
MR_fnc_loadedMagazines = {
    params ["_unit"];

    private _weapons = [primaryWeapon _unit, handgunWeapon _unit, secondaryWeapon _unit] - [""];
    private _loaded = [];

    {
        _x params ["_weapon", "", "", "", ["_magazine", []], ["_secondMagazine", []]];

        if (_weapon in _weapons) then {
            private _otherMuzzles = (getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles")) select {_x != "this"};

            {
                _x params [["_type", ""], ["_ammo", 0]];

                // an empty loaded magazine is never confirmed (any other muzzle reports 0 as well)
                if (_ammo > 0 && {([_type] call MR_fnc_capacity) > 1}) then {
                    private _muzzle = "";

                    if (_forEachIndex == 0) then {
                        if ((_unit ammo _weapon) == _ammo) then {_muzzle = _weapon;};
                    } else {
                        private _index = _otherMuzzles findIf {(_unit ammo _x) == _ammo};

                        if (_index != -1) then {_muzzle = _otherMuzzles select _index;};
                    };

                    if (_muzzle != "") then {
                        _loaded pushBack [_type, _ammo, _muzzle];
                    };
                };
            } forEach [_magazine, _secondMagazine];
        };
    } forEach weaponsItems _unit;

    _loaded
};

// All repackable magazines of the unit, full ones included (a type is always written back as a whole):
// type -> [slot, ...]
MR_fnc_readMagazines = {
    params ["_unit"];

    private _magazines = createHashMap;

    {
        private _place = _forEachIndex;

        if (!isNull _x) then {
            {
                _x params ["_type", "_ammo"];

                if (([_type] call MR_fnc_capacity) > 1) then {
                    if !(_type in _magazines) then {_magazines set [_type, []];};

                    (_magazines get _type) pushBack [_place, _ammo, ""];
                };
            } forEach magazinesAmmoCargo _x;
        };
    } forEach ([_unit] call MR_fnc_containers);

    {
        _x params ["_type", "_ammo", "_muzzle"];

        if !(_type in _magazines) then {_magazines set [_type, []];};

        (_magazines get _type) pushBack [-1, _ammo, _muzzle];
    } forEach ([_unit] call MR_fnc_loadedMagazines);

    _magazines
};

// _slots in a fixed order, to compare two readings (magazinesAmmoCargo has none); _storedOnly drops the loaded ones
MR_fnc_sorted = {
    params ["_slots", ["_storedOnly", false]];

    private _sorted = if (_storedOnly) then {_slots select {(_x select 0) != -1}} else {+_slots};

    _sorted sort true;
    _sorted
};

// ---- repack rules ----

// The next step of one magazine type, or [] when at most one partly filled magazine is left: one magazine is filled (a
// loaded one first, so the weapon gets the fullest magazine, else the fullest one) from the emptiest others. Loaded
// magazines never give rounds: an emptied one would leave the weapon without a magazine.
// Returns [target, [[source, rounds], ...], rounds moved] with indices into _slots.
MR_fnc_nextStep = {
    params ["_slots", "_capacity"];

    private _partial = [];   // [ammo, index] of the partly filled magazines

    {
        if ((_x select 1) < _capacity) then {
            _partial pushBack [_x select 1, _forEachIndex];
        };
    } forEach _slots;

    if (count _partial < 2) exitWith {[]};

    _partial sort true;   // emptiest first

    private _targetIndex = _partial findIf {((_slots select (_x select 1)) select 0) == -1};

    if (_targetIndex == -1) then {
        _targetIndex = count _partial - 1;
    };

    private _target = (_partial deleteAt _targetIndex) select 1;
    private _sources = _partial select {((_slots select (_x select 1)) select 0) != -1};

    if (_sources isEqualTo []) exitWith {[]};

    private _missing = _capacity - ((_slots select _target) select 1);
    private _taken = [];
    private _moved = 0;

    {
        if (_missing <= 0) exitWith {};

        _x params ["_ammo", "_index"];

        private _rounds = _ammo min _missing;

        _taken pushBack [_index, _rounds];
        _missing = _missing - _rounds;
        _moved = _moved + _rounds;
    } forEach _sources;

    [_target, _taken, _moved]
};

// _slots after _step; emptied magazines are gone
MR_fnc_applyStep = {
    params ["_slots", "_step"];
    _step params ["_target", "_taken", "_moved"];

    private _result = +_slots;
    private _targetSlot = _result select _target;

    _targetSlot set [1, (_targetSlot select 1) + _moved];

    {
        _x params ["_index", "_rounds"];

        private _source = _result select _index;

        _source set [1, (_source select 1) - _rounds];
    } forEach _taken;

    _result select {(_x select 0) == -1 || {(_x select 1) > 0}}
};

// after the last step of a type: a loaded magazine left partly filled changes places with a full one from the
// containers, so the weapon is loaded with a full magazine
MR_fnc_swapLoaded = {
    params ["_slots", "_capacity"];

    private _result = +_slots;

    {
        private _loaded = _x;

        if ((_loaded select 0) == -1 && {(_loaded select 1) < _capacity}) then {
            private _fullIndex = _result findIf {(_x select 0) != -1 && {(_x select 1) >= _capacity}};

            if (_fullIndex != -1) then {
                (_result select _fullIndex) set [1, _loaded select 1];
                _loaded set [1, _capacity];
            };
        };
    } forEach _result;

    _result
};

// [steps, rounds moved] until the type is repacked
MR_fnc_countSteps = {
    params ["_slots", "_capacity"];

    private _steps = 0;
    private _moved = 0;
    private _step = [_slots, _capacity] call MR_fnc_nextStep;

    while {_step isNotEqualTo []} do {
        _steps = _steps + 1;
        _moved = _moved + (_step select 2);
        _slots = [_slots, _step] call MR_fnc_applyStep;
        _step = [_slots, _capacity] call MR_fnc_nextStep;
    };

    [_steps, _moved]
};

// The slots of a type after all steps (unchanged if there is nothing to repack). With two loaded magazines of one type
// (primary and handgun of a mod) a swap can leave a stored partly filled magazine for the other weapon: steps again.
MR_fnc_repackedSlots = {
    params ["_slots", "_capacity"];

    private _step = [_slots, _capacity] call MR_fnc_nextStep;

    if (_step isEqualTo []) exitWith {_slots};

    while {_step isNotEqualTo []} do {
        while {_step isNotEqualTo []} do {
            _slots = [_slots, _step] call MR_fnc_applyStep;
            _step = [_slots, _capacity] call MR_fnc_nextStep;
        };

        _slots = [_slots, _capacity] call MR_fnc_swapLoaded;
        _step = [_slots, _capacity] call MR_fnc_nextStep;
    };

    _slots
};

/*
    Writes the magazines of one type of a local unit; call it unscheduled, so nothing changes between the check and the
    write. _oldSlots: as read before (MR_fnc_readMagazines), _newSlots: as they should be. False (nothing written) if
    the unit's magazines of the type are no longer _oldSlots, e.g. the player moved one meanwhile.
    The stored magazines of the type are removed (removeMagazines: local unit, global effect; it leaves the loaded
    ones alone) and added again with their new ammo, each into the container it belongs to (addMagazineAmmoCargo:
    global; cargo commands add regardless of free space, so nothing ends up on the ground). Loaded magazines only get
    their ammo set (setAmmo: local unit, global effect; no reload).
*/
MR_fnc_writeMagazines = {
    params ["_unit", "_type", "_oldSlots", "_newSlots"];

    // the commands only act on a local unit; adding without removing would duplicate magazines
    if (!local _unit) exitWith {false};

    private _current = ([_unit] call MR_fnc_readMagazines) getOrDefault [_type, []];

    if (([_current] call MR_fnc_sorted) isNotEqualTo ([_oldSlots] call MR_fnc_sorted)) exitWith {false};

    private _containers = [_unit] call MR_fnc_containers;
    private _storedChanged = ([_oldSlots, true] call MR_fnc_sorted) isNotEqualTo ([_newSlots, true] call MR_fnc_sorted);

    if (_storedChanged) then {
        _unit removeMagazines _type;
    };

    if (_storedChanged && {(_containers findIf {((magazinesAmmoCargo _x) findIf {(_x select 0) == _type}) != -1}) != -1}) exitWith {
        diag_log format ["MR: %1 still has %2 after removeMagazines, repack skipped", _unit, _type];
        false
    };

    if (_storedChanged) then {
        private _counts = createHashMap;   // [place, ammo] -> magazines

        {
            _x params ["_place", "_ammo"];

            if (_place != -1) then {
                _counts set [[_place, _ammo], (_counts getOrDefault [[_place, _ammo], 0]) + 1];
            };
        } forEach _newSlots;

        {
            _x params ["_place", "_ammo"];

            (_containers select _place) addMagazineAmmoCargo [_type, _y, _ammo];
        } forEach _counts;
    };

    {
        _x params ["_place", "_ammo", "_muzzle"];

        if (_place == -1 && {(_unit ammo _muzzle) != _ammo}) then {
            _unit setAmmo [_muzzle, _ammo];
        };
    } forEach _newSlots;

    // for the in-game tests (RPT): the unit's magazines of the type must now be exactly _newSlots
    private _written = ([_unit] call MR_fnc_readMagazines) getOrDefault [_type, []];

    if (([_written] call MR_fnc_sorted) isNotEqualTo ([_newSlots] call MR_fnc_sorted)) then {
        diag_log format ["MR: %1 %2 after the repack: %3 instead of %4", _unit, _type, _written, _newSlots];
    };

    true
};

// ---- AI repack ----

// all magazine types of a local unit at once; unscheduled
MR_fnc_repackUnit = {
    params ["_unit"];

    {
        private _newSlots = [_y, [_x] call MR_fnc_capacity] call MR_fnc_repackedSlots;

        if (_newSlots isNotEqualTo _y) then {
            [_unit, _x, _y, _newSlots] call MR_fnc_writeMagazines;
        };
    } forEach ([_unit] call MR_fnc_readMagazines);
};

// every MR_var_aiInterval the local AI units out of combat (players repack with the inventory button)
MR_fnc_aiLoop = {
    while {MR_var_aiRunning} do {
        sleep (MR_var_aiInterval max 1);

        if (MR_var_aiRunning && {MR_var_enabled} && {MR_var_aiRepack}) then {
            {
                if (local _x && {alive _x} && {!isPlayer _x} && {behaviour _x != "COMBAT"}) then {
                    // one unit at a time unscheduled: its magazines (a shot, a reload) can't change while it is repacked
                    isNil {[_x] call MR_fnc_repackUnit};
                };
            } forEach allUnits;
        };
    };
};

MR_fnc_startAiRepack = {
    if (MR_var_aiRunning) exitWith {};

    MR_var_aiRunning = true;
    MR_var_aiLoopScript = [] spawn MR_fnc_aiLoop;
};

MR_fnc_stopAiRepack = {
    if (!MR_var_aiRunning) exitWith {};

    MR_var_aiRunning = false;
    terminate MR_var_aiLoopScript;
};

MR_var_clientServerInitDone = true;
