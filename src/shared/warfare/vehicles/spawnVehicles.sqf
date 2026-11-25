// Mobile spawn vehicles: spawn trucks / helicopters of every side (number and kind by map size) wait at the base, are a
// respawn position of their side while they stand still away from enemies and come back after their loss (server);
// the seat of a player who respawned in one (client). The mapmarker / tdicons mods show them to their side.

// ---- constants ----

// type by world group (SC_var_currentWorldGroup) and kind, the same for every side (user decision: equal seats, speed
// and armour); a type the game doesn't know falls back to the "2035" type of its kind. Base game vehicles: the Huron /
// Taru (Helicopters DLC) could only be flown by owners of the DLC
SC_var_spawnVehicleTypes = createHashMapFromArray [
    ["2035", createHashMapFromArray [
        ["truck", "I_Truck_02_medical_F"],
        ["heli", "I_Heli_light_03_unarmed_F"],
        ["bigHeli", "I_Heli_Transport_02_F"]
    ]],
    ["Chernarus", createHashMapFromArray [
        ["truck", "CUP_V3S_Open_NAPA"],
        ["heli", "CUP_I_UH60L_Unarmed_RACS"],
        ["bigHeli", "CUP_I_Merlin_HC3_PMC_Transport_black"]
    ]]
];

// the one name everywhere (map, 3D icons, HUD, notifications, information board)
SC_var_spawnVehicleNames = createHashMapFromArray [
    ["truck", "Spawn Truck"],
    ["heli", "Spawn Helicopter"],
    ["bigHeli", "Spawn Helicopter"]
];

SC_var_spawnVehicleLoopInterval = 1;        // s between two checks of the spawn vehicles
SC_var_spawnVehicleMaxSpeed = 3;            // km/h: a faster spawn vehicle is moving
SC_var_spawnVehicleMaxHeight = 2;           // m above the surface: a helicopter higher up has not landed
SC_var_spawnVehicleMinUp = 0.7;             // z of vectorUp: a spawn vehicle tilted more is overturned
SC_var_spawnVehicleSettleTime = 3;          // s the conditions must hold before it becomes a respawn position
SC_var_spawnVehicleHitCooldown = 30;        // s after a hit in which it is no respawn position
SC_var_spawnVehicleAbandonTime = 300;       // s an empty one may be stuck / outside the play zone until it is replaced
SC_var_spawnVehicleSpawnDistance = [25, 100];   // m from the base's vehicle spawn point (keeps that point free)
SC_var_spawnVehicleExtraCenters = 4;        // random base points searched after the spawn point and the base centre

// ---- interface (server and clients) ----
// The server publishes SC_var_spawnVehicles: [[vehicle, side, name, kind], ...] of the existing spawn vehicles, and on
// every spawn vehicle SC_var_spawnVehicle (true), SC_var_spawnVehicleSide, SC_var_spawnVehicleName and
// SC_var_spawnVehicleState ("" while it is a respawn position, else the reason why not, e.g. "moving").
// The mods' vehicle icons (map / GPS: mapmarker, 3D: tdicons) show a spawn vehicle by their normal rules, to its side
// (MM_var_showWhenEmpty / TDI_var_showWhenEmpty) also while empty, then labeled with its name and, while it is no
// respawn position, why not (MM_var_emptyLabel / TDI_var_emptyLabel); manned, with its crew as any vehicle.

SC_fnc_isSpawnVehicle = {
    params ["_vehicle"];

    _vehicle getVariable ["SC_var_spawnVehicle", false]
};

// the existing (alive) spawn vehicles of a side
SC_fnc_getSideSpawnVehicles = {
    params ["_side"];

    ((missionNamespace getVariable ["SC_var_spawnVehicles", []]) select {((_x select 1) == _side) && {alive (_x select 0)}}) apply {_x select 0}
};

// whether a spawn vehicle is a respawn position right now
SC_fnc_isSpawnVehicleUsable = {
    params ["_vehicle"];

    (alive _vehicle) && {(_vehicle getVariable ["SC_var_spawnVehicleState", "-"]) == ""}
};

SC_fnc_getUsableSpawnVehicles = {
    params ["_side"];

    ([_side] call SC_fnc_getSideSpawnVehicles) select {[_x] call SC_fnc_isSpawnVehicleUsable}
};

// moves a unit (where it is local) into a free cargo seat of a spawn vehicle, else behind it; for AI respawns (players
// are moved by the respawn menu). False if the vehicle is gone.
SC_fnc_moveUnitToSpawnVehicle = {
    params ["_unit", "_vehicle"];

    if (!(alive _vehicle) || {!(local _unit)}) exitWith {false};

    private _freeCargo = (fullCrew [_vehicle, "cargo", true]) select {isNull (_x select 0)};

    if (_freeCargo isNotEqualTo []) exitWith {
        _unit moveInCargo [_vehicle, ((_freeCargo select 0) select 2)];
        true
    };

    private _rearDistance = (abs (((boundingBoxReal _vehicle) select 0) select 1)) + 2;
    _unit setVehiclePosition [(_vehicle getRelPos [_rearDistance, (150 + (random 60))]), [], 0, "NONE"];
    _unit setDir (getDir _vehicle);
    true
};

// ---- server ----

// server init: one slot per spawn vehicle (SC_var_spawnVehicleKinds of the map size), the loop creates them
SC_fnc_initSpawnVehiclesServer = {
    SC_var_spawnVehicleSlots = [];
    SC_var_spawnVehicles = [];
    publicVariable "SC_var_spawnVehicles";

    {
        private _side = _x;

        {
            _x params ["_kind", "_count"];

            for "_i" from 1 to _count do {
                private _name = SC_var_spawnVehicleNames get _kind;

                if (_count > 1) then {
                    _name = format ["%1 %2", _name, _i];
                };

                SC_var_spawnVehicleSlots pushBack (createHashMapFromArray [
                    ["side", _side],
                    ["kind", _kind],
                    ["name", _name],
                    ["vehicle", objNull],
                    ["respawnTime", 0],
                    ["respawnAt", -1],
                    ["isReplacement", false],
                    ["respawnId", -1]
                ]);
            };
        } forEach SC_var_spawnVehicleKinds;
    } forEach SC_var_sides;

    if (SC_var_spawnVehicleSlots isNotEqualTo []) then {
        SC_var_spawnVehicleLoopScript = [] spawn SC_fnc_spawnVehicleLoop;
    };
};

SC_fnc_spawnVehicleLoop = {
    waitUntil {
        {
            [_x] call SC_fnc_updateSpawnVehicleSlot;
        } forEach SC_var_spawnVehicleSlots;

        sleep SC_var_spawnVehicleLoopInterval;
        false
    };
};

// the type of a kind (see SC_var_spawnVehicleTypes; the same for every side), "" if the game knows none
SC_fnc_getSpawnVehicleType = {
    params ["", "_kind"];

    private _candidates = [
        (SC_var_spawnVehicleTypes getOrDefault [SC_var_currentWorldGroup, createHashMap]) getOrDefault [_kind, ""],
        (SC_var_spawnVehicleTypes get "2035") getOrDefault [_kind, ""]
    ];
    private _index = _candidates findIf {isClass (configFile >> "CfgVehicles" >> _x)};

    if (_index == -1) exitWith {""};

    _candidates select _index
};

// server: a spawn vehicle of the slot at its side's base (near the vehicle spawn point); objNull if there is no room
SC_fnc_createSpawnVehicle = {
    params ["_slot"];

    private _side = _slot get "side";
    private _type = [_side, (_slot get "kind")] call SC_fnc_getSpawnVehicleType;

    if (_type == "") exitWith {objNull};

    private _sideStr = toLower (str _side);
    private _baseMarker = "SC_var_" + _sideStr + "Base";
    private _vehicleSpawn = missionNamespace getVariable [("SC_var_" + _sideStr + "VehSpawn"), objNull];
    private _centers = [getMarkerPos _baseMarker];

    if !(isNull _vehicleSpawn) then {
        _centers = [getPosATL _vehicleSpawn] + _centers;
    };

    // a few random points of the base as well, in case the area around the spawn point is full (e.g. at the start)
    for "_i" from 1 to SC_var_spawnVehicleExtraCenters do {
        _centers pushBack ([_baseMarker] call BIS_fnc_randomPosTrigger);
    };

    private _pos = [];

    {
        private _center = _x;
        private _timeout = time + 5;

        waitUntil {(_center findEmptyPositionReady SC_var_spawnVehicleSpawnDistance) || {time > _timeout}};

        private _candidate = _center findEmptyPosition (SC_var_spawnVehicleSpawnDistance + [_type]);

        if ((_candidate isNotEqualTo []) && {_candidate inArea _baseMarker}) exitWith {
            _pos = _candidate;
        };
    } forEach _centers;

    if (_pos isEqualTo []) exitWith {objNull};

    private _name = _slot get "name";
    private _vehicle = createVehicle [_type, _pos, [], 0, "NONE"];
    _vehicle setVariable ["BIS_enableRandomization", false];
    _vehicle setDir (_pos getDir SC_var_playZoneMiddle);
    [_vehicle, false] call ADG_fnc_allowDamage;
    _vehicle disableTIEquipment true;
    _vehicle setUnloadInCombat [true, false];
    _vehicle allowCrewInImmobile [false, false];
    [_vehicle] call SC_fnc_setSpawnedVehicleCargo;

    // damage handler on every machine, without the lock actions (the JIP entry goes with it)
    [_vehicle, false] remoteExecCall ["SC_fnc_initSpawnedVehicle", 0, _vehicle];

    _vehicle setVariable ["SC_var_spawnVehicle", true, true];
    _vehicle setVariable ["SC_var_spawnVehicleSide", _side, true];
    _vehicle setVariable ["SC_var_spawnVehicleName", _name, true];
    [_vehicle, "at the base"] call SC_fnc_publishSpawnVehicleState;
    _vehicle setVariable ["KF_var_side", _side];

    // the mods' vehicle icons show it to its side also while empty
    _vehicle setVariable ["MM_var_showWhenEmpty", _side, true];
    _vehicle setVariable ["TDI_var_showWhenEmpty", _side, true];

    // the map label of the manned vehicle: the mapmarker mod first names every new vehicle after its type
    [_vehicle, _name] spawn {
        params ["_vehicle", "_name"];

        private _timeout = time + 10;

        waitUntil {sleep 0.5; (isNull _vehicle) || {(_vehicle getVariable ["MM_var_name", ""]) != ""} || {time > _timeout}};

        if !(isNull _vehicle) then {
            _vehicle setVariable ["MM_var_name", _name, true];
        };
    };

    {
        _slot set _x;
    } forEach [
        ["vehicle", _vehicle],
        ["respawnTime", -1],
        ["respawnId", -1],
        ["isProtected", true],
        ["damage", 0],
        ["hitTime", -1e9],
        ["clearSince", -1],
        ["abandonedSince", -1]
    ];

    _vehicle
};

// server: one check of a slot: creates its vehicle when it is due, handles its loss, else updates it
SC_fnc_updateSpawnVehicleSlot = {
    params ["_slot"];

    private _vehicle = _slot get "vehicle";

    if (alive _vehicle) exitWith {
        [_slot] call SC_fnc_updateSpawnVehicle;
    };

    // destroyed or deleted since the last check
    if ((_slot get "respawnTime") < 0) exitWith {
        [_slot, (["was lost", "was destroyed"] select !(isNull _vehicle))] call SC_fnc_loseSpawnVehicle;
    };

    if (time < (_slot get "respawnTime")) exitWith {};

    if (isNull ([_slot] call SC_fnc_createSpawnVehicle)) exitWith {};

    if (_slot get "isReplacement") then {
        [(_slot get "side"), format ["%1 is ready again at the base", (_slot get "name")]] call SC_fnc_notifySide;
    };

    _slot set ["isReplacement", true];
    _slot set ["respawnAt", -1];
    call SC_fnc_publishSpawnVehicles;
};

// server: a spawn vehicle is gone (_reason completes "<name> ..."): no respawn position any more, the wreck despawns
// like any other, a new one comes after SC_var_spawnVehicleRespawnTime
SC_fnc_loseSpawnVehicle = {
    params ["_slot", "_reason"];

    private _vehicle = _slot get "vehicle";

    [_slot, "lost"] call SC_fnc_setSpawnVehicleState;

    if (!(isNull _vehicle) && {!(alive _vehicle)}) then {
        _vehicle setVariable ["SC_var_timeRemaining", SC_var_vehicleDespawnTime];
        [_vehicle] call SC_fnc_registerEntityServer;
    };

    _slot set ["vehicle", objNull];
    _slot set ["respawnTime", time + SC_var_spawnVehicleRespawnTime];
    _slot set ["respawnAt", serverTime + SC_var_spawnVehicleRespawnTime];
    call SC_fnc_publishSpawnVehicles;

    [
        (_slot get "side"),
        format ["%1 %2, a new one is ready at the base in %3 min", (_slot get "name"), _reason, ([SC_var_spawnVehicleRespawnTime] call SC_fnc_secondsToMinSec)]
    ] call SC_fnc_notifySide;
};

// server: one check of an existing spawn vehicle
SC_fnc_updateSpawnVehicle = {
    params ["_slot"];

    private _vehicle = _slot get "vehicle";
    private _side = _slot get "side";
    private _crewAlive = (crew _vehicle) select {alive _x};

    // spawn protection like a vehicle spawned at the base: until it leaves the base area for the first time
    if ((_slot get "isProtected") && {!((getPosWorld _vehicle) inArea ("SC_var_" + (toLower (str _side)) + "Base"))}) then {
        _slot set ["isProtected", false];
        [_vehicle, true] call ADG_fnc_allowDamage;
        ["vehiclesystem", ["Your vehicle is now vulnerable"], _crewAlive] call SC_fnc_notifyPlayers;
    };

    // enemies can't use it
    private _enemyCrew = _crewAlive select {((side (group _x)) in SC_var_sides) && {(side (group _x)) != _side}};

    {
        _x remoteExecCall ["unassignVehicle", _x];
        _x remoteExecCall ["moveOut", _x];
    } forEach _enemyCrew;

    ["vehiclesystem", ["You can't use an enemy spawn vehicle"], _enemyCrew] call SC_fnc_notifyPlayers;

    [_vehicle] call SC_fnc_updateTransport;

    // a hit: the summed damage grew since the last check (the service only lowers it)
    private _damage = damage _vehicle;

    {
        _damage = _damage + _x;
    } forEach ((getAllHitPointsDamage _vehicle) param [2, []]);

    if (_damage > ((_slot get "damage") + 0.001)) then {
        _slot set ["hitTime", time];
    };

    _slot set ["damage", _damage];

    // an empty spawn vehicle that is immobile or outside the play zone for too long is replaced
    private _isStranded = (
        !(canMove _vehicle) ||
        {(fuel _vehicle) == 0} ||
        {((vectorUp _vehicle) select 2) < SC_var_spawnVehicleMinUp} ||
        {!((getPosWorld _vehicle) inArea "SC_var_playZone")}
    );

    if (_isStranded && {_crewAlive isEqualTo []}) then {
        if ((_slot get "abandonedSince") < 0) then {
            _slot set ["abandonedSince", time];
        };
    } else {
        _slot set ["abandonedSince", -1];
    };

    if (((_slot get "abandonedSince") >= 0) && {(time - (_slot get "abandonedSince")) > SC_var_spawnVehicleAbandonTime}) exitWith {
        [_slot, "was abandoned"] call SC_fnc_loseSpawnVehicle;
        [_vehicle] remoteExec ["SC_fnc_safelyDeleteVehicle", (owner _vehicle)];
    };

    // respawn position once all conditions held for SC_var_spawnVehicleSettleTime (until then the state stays)
    private _state = [_vehicle, _side, (_slot get "hitTime")] call SC_fnc_getSpawnVehicleBlockReason;

    if (_state == "") then {
        if ((_slot get "clearSince") < 0) then {
            _slot set ["clearSince", time];
        };

        if ((time - (_slot get "clearSince")) < SC_var_spawnVehicleSettleTime) then {
            _state = _vehicle getVariable ["SC_var_spawnVehicleState", "at the base"];
        };
    } else {
        _slot set ["clearSince", -1];
    };

    [_slot, _state] call SC_fnc_setSpawnVehicleState;
};

// server: why a spawn vehicle is no respawn position right now ("" = it is one)
SC_fnc_getSpawnVehicleBlockReason = {
    params ["_vehicle", "_side", "_hitTime"];

    private _pos = getPosWorld _vehicle;
    private _baseIndex = SC_var_sides findIf {_pos inArea ("SC_var_" + (toLower (str _x)) + "Base")};

    switch true do {
        case (_baseIndex != -1): {["in an enemy base", "at the base"] select ((SC_var_sides select _baseIndex) == _side)};
        case !(_pos inArea "SC_var_playZone"): {"outside the play zone"};
        case (surfaceIsWater _pos): {"in the water"};
        case (((vectorUp _vehicle) select 2) < SC_var_spawnVehicleMinUp): {"overturned"};
        case ((_vehicle isKindOf "Air") && {((getPos _vehicle) select 2) > SC_var_spawnVehicleMaxHeight}): {"in the air"};
        case ((abs (speed _vehicle)) > SC_var_spawnVehicleMaxSpeed): {"moving"};
        case ((time - _hitTime) < SC_var_spawnVehicleHitCooldown): {"recently hit"};
        case ([_vehicle, _side, SC_var_spawnVehicleEnemyRadius] call SC_fnc_isEnemyNear): {"enemies nearby"};
        default {""};
    }
};

// whether a living, conscious unit of another side than _side (on foot or in a vehicle) is within _radius of _center
// (object or position AGL)
SC_fnc_isEnemyNear = {
    params ["_center", "_side", "_radius"];

    ((_center nearEntities [["CAManBase", "LandVehicle", "Air", "Ship"], _radius]) findIf {
        if (_x isKindOf "CAManBase") then {
            [_x, _side] call SC_fnc_isEnemyUnit
        } else {
            ((crew _x) findIf {[_x, _side] call SC_fnc_isEnemyUnit}) != -1
        }
    }) != -1
};

SC_fnc_isEnemyUnit = {
    params ["_unit", "_side"];

    private _unitSide = side (group _unit);

    (alive _unit) &&
    {_unitSide in SC_var_sides} &&
    {_unitSide != _side} &&
    {!(_unit getVariable ["ais_unconscious", false])}
};

// server: publishes a new state of a slot's vehicle; "" makes it a respawn position of its side, anything else removes
// that position
SC_fnc_setSpawnVehicleState = {
    params ["_slot", "_state"];

    private _vehicle = _slot get "vehicle";
    private _respawnId = _slot get "respawnId";

    if ((_state == "") && {_respawnId == -1}) then {
        ([(_slot get "side"), _vehicle, (_slot get "name")] call BIS_fnc_addRespawnPosition) params ["", "_newId"];
        _slot set ["respawnId", _newId];
    };

    if ((_state != "") && {_respawnId != -1}) then {
        [(_slot get "side"), _respawnId] call BIS_fnc_removeRespawnPosition;
        _slot set ["respawnId", -1];
    };

    if (!(isNull _vehicle) && {(_vehicle getVariable ["SC_var_spawnVehicleState", ""]) != _state}) then {
        [_vehicle, _state] call SC_fnc_publishSpawnVehicleState;
    };
};

// server: the state of a spawn vehicle and the label the mods show for it: only its name (user decision: no reason in
// brackets why it is no respawn position)
SC_fnc_publishSpawnVehicleState = {
    params ["_vehicle", "_state"];

    private _label = _vehicle getVariable ["SC_var_spawnVehicleName", ""];

    _vehicle setVariable ["SC_var_spawnVehicleState", _state, true];
    _vehicle setVariable ["MM_var_emptyLabel", _label, true];
    _vehicle setVariable ["TDI_var_emptyLabel", _label, true];
};

SC_fnc_publishSpawnVehicles = {
    SC_var_spawnVehicles = (SC_var_spawnVehicleSlots select {alive (_x get "vehicle")}) apply {
        [(_x get "vehicle"), (_x get "side"), (_x get "name"), (_x get "kind")]
    };

    // [[side, name, server time of the replacement], ...] of the lost ones, for the HUD countdown
    SC_var_spawnVehicleRespawns = (SC_var_spawnVehicleSlots select {!(alive (_x get "vehicle")) && {(_x get "respawnAt") >= 0}}) apply {
        [(_x get "side"), (_x get "name"), (_x get "respawnAt")]
    };

    publicVariable "SC_var_spawnVehicles";
    publicVariable "SC_var_spawnVehicleRespawns";
};

// server: notification for the players of a side (shown with the HUD)
SC_fnc_notifySide = {
    params ["_side", "_text"];

    private _players = allPlayers select {(side (group _x)) == _side};

    if (_players isNotEqualTo []) then {
        ["vehiclesystem", [_text]] remoteExec ["SC_fnc_showNotificationIfHudIsEnabled", _players];
    };
};

// ---- client ----

// client (after a respawn): the respawn menu puts a player who respawns at a spawn vehicle into its first free seat,
// usually the driver's; from a seat at the controls he moves on to a free cargo seat, if there is one
SC_fnc_seatAtSpawnVehicle = {
    private _timeout = time + 3;

    waitUntil {sleep 0.1; !(isNull (objectParent player)) || {time > _timeout}};

    private _vehicle = objectParent player;

    if ((isNull _vehicle) || {!([_vehicle] call SC_fnc_isSpawnVehicle)}) exitWith {};

    // [unit, role, cargo index, turret path, person turret, ...] of the player's seat
    private _seat = ((fullCrew _vehicle) select {(_x select 0) isEqualTo player}) param [0, []];

    if ((_seat isEqualTo []) || {(_seat select 1) == "cargo"} || {_seat select 4}) exitWith {};

    private _freeCargo = (fullCrew [_vehicle, "cargo", true]) select {isNull (_x select 0)};

    if (_freeCargo isNotEqualTo []) then {
        player action ["MoveToCargo", _vehicle, ((_freeCargo select 0) select 2)];
    };
};
