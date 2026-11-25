// Team Deathmatch team vehicles (server): spawning the vehicles of each team, locking them during the equip phase and
// handing them to the AI.

DM_fnc_spawnVehiclesForSides = {
    {
        [_x, count ([_x] call DM_fnc_unitsOfSide)] spawn DM_fnc_spawnVehicles;
    } forEach [west, east];
};

DM_fnc_spawnVehicles = {
    params ["_side", "_unitCount"];

    private _pos = getMarkerPos ([_side] call DM_fnc_hqMarker);

    // vehicleAmount: 0 One per Team, 1 One per 2 Players (at least one), 2 One per Player
    private _vehicleCount = [1, 1 max floor (_unitCount / 2), _unitCount] select DM_var_vehicleAmount;

    if (_vehicleCount < 1) exitWith {};

    for "_i" from 1 to _vehicleCount do {
        [_pos, DM_var_vehicleType] spawn DM_fnc_spawnVehicle;
        sleep (3 / _vehicleCount);
    };
};

DM_fnc_spawnVehicle = {
    params ["_pos", "_vehicleType"];

    private _spawnPos = [_pos, _vehicleType, 5] call DM_fnc_findSpawnPos;
    private _vehicle = createVehicle [_vehicleType, _spawnPos, [], 0, "NONE"];
    _vehicle lock ([2, 0] select DM_var_movingEnabled);
    DM_var_teamVehicles pushBack _vehicle;
    [_vehicle, false] call ADG_fnc_allowDamage;

    waitUntil {!isNull _vehicle};

    _vehicle setDir random 360;

    clearBackpackCargoGlobal _vehicle;
    clearItemCargoGlobal _vehicle;
    clearMagazineCargoGlobal _vehicle;
    clearWeaponCargoGlobal _vehicle;
    _vehicle addItemCargoGlobal ["Toolkit", 1];

    [_vehicle] spawn {
        params ["_vehicle"];

        sleep 5;
        [_vehicle, true] call ADG_fnc_allowDamage;
    };
};

// locked team vehicles (equip phase) cannot be entered; "lock" must run where the vehicle is local
DM_fnc_lockTeamVehicles = {
    params ["_locked"];

    DM_var_teamVehicles = DM_var_teamVehicles - [objNull];

    {
        [_x, [0, 2] select _locked] remoteExecCall ["lock", _x];
    } forEach DM_var_teamVehicles;
};

// one crew loop at a time (warmup and every round start one)
DM_fnc_startVehicleLoop = {
    call DM_fnc_stopVehicleLoop;
    DM_var_vehicleLoopHdl = [] spawn DM_fnc_vehicleLoop;
};

DM_fnc_stopVehicleLoop = {
    if (!scriptDone DM_var_vehicleLoopHdl) then {
        terminate DM_var_vehicleLoopHdl;
    };
};

// goes through all vehicles about every 5 s and gives them AI crews
DM_fnc_vehicleLoop = {
    waitUntil {
        private _vehicles = vehicles;
        private _sleepTime = 5 / (1 + count _vehicles);

        {
            [_x] call DM_fnc_assignVehicleCrew;
            sleep _sleepTime;
        } forEach _vehicles;

        false
    };
};

// assigns free AI units near the vehicle to its empty crew seats; cargo seats stay free
DM_fnc_assignVehicleCrew = {
    params ["_vehicle"];

    private _crew = (crew _vehicle) select {alive _x};

    // empty vehicle: anyone within 50 m; manned: only soldiers of the crew's side within 20 m
    private _unitsInArea = if (_crew isEqualTo []) then {
        getPosATL _vehicle nearEntities 50
    } else {
        private _soldierType = switch (side group (_crew select 0)) do {
            case west: {"B_Soldier_F"};
            case east: {"O_Soldier_F"};
            case independent: {"I_Soldier_F"};
        };

        getPosATL _vehicle nearEntities [_soldierType, 20]
    };

    private _assignedUnits = _unitsInArea select {assignedVehicle _x isEqualTo _vehicle};

    {
        unassignVehicle _x;
    } forEach (_assignedUnits select {(assignedVehicleRole _x) select 0 == "cargo"});

    private _freeUnits = _unitsInArea select {_x isKindOf "CAManBase" && {!isPlayer _x} && {isNull assignedVehicle _x}};

    // fullCrew entry: [unit, role, cargoIndex, turretPath, isPersonTurret], role in lower case
    private _emptySeats = (fullCrew [_vehicle, "", true]) select {isNull (_x select 0) && {_x select 1 != "cargo"}};
    _emptySeats resize (count _emptySeats min count _freeUnits);

    {
        _x params ["", "_role", "", "_turretPath"];

        private _unit = _freeUnits deleteAt 0;
        (group _unit) addVehicle _vehicle;

        switch (_role) do {
            case "driver": {
                _unit assignAsDriver _vehicle;
            };
            case "commander": {
                _unit assignAsCommander _vehicle;
            };
            case "gunner": {
                _unit assignAsGunner _vehicle;
            };
            case "turret": {
                _unit assignAsTurret [_vehicle, _turretPath];
            };
        };
    } forEach _emptySeats;
};
