// AI vehicle use: one vehicle per AI squad (reservation, seats, boarding, dismounting), stuck / repair / abandon
// handling, and the per-vehicle loop with the side ownership and despawn of vehicles (server).

// ---- vehicle choice and reservation ----

// a vehicle that made less than this progress (m) in SC_var_aiStuckTime seconds while travelling is stuck
SC_var_aiStuckDistance = 15;
SC_var_aiStuckTime = 25;

// a vehicle that was abandoned (stuck, not repairable) is ignored by the AI for this long (seconds)
SC_var_aiAbandonTime = 600;

// a repair (walk to the vehicle and repair it) that takes longer than this (seconds) fails
SC_var_aiRepairTimeout = 90;

// [seats, crew seats] of a vehicle type, cached: all seats (driver, gunners, commander, cargo, FFV) and the seats that
// operate the vehicle or a weapon (driver and turrets that aren't FFV)
SC_var_aiSeatCounts = createHashMap;

SC_fnc_aiCountCrewTurrets = {
    params ["_turretsConfig"];

    private _count = 0;

    {
        if ((getNumber (_x >> "isPersonTurret")) == 0) then {
            _count = _count + 1;
        };

        _count = _count + ([_x >> "Turrets"] call SC_fnc_aiCountCrewTurrets);
    } forEach ("true" configClasses _turretsConfig);

    _count
};

SC_fnc_aiSeatCounts = {
    params ["_type"];

    private _counts = SC_var_aiSeatCounts get _type;

    if (isNil "_counts") then {
        private _config = configFile >> "CfgVehicles" >> _type;

        _counts = [
        [_type, true] call BIS_fnc_crewCount,
        (getNumber (_config >> "hasDriver")) + ([_config >> "Turrets"] call SC_fnc_aiCountCrewTurrets)
        ];
        SC_var_aiSeatCounts set [_type, _counts];
    };

    _counts
};

// Seats a squad of _size units needs in a vehicle: one per member; a squad bigger than a full squad
// (SC_var_aiFullSquadSize) also takes a smaller vehicle with at least that many seats if there is none for all of them,
// the members without a seat follow on foot (SC_fnc_aiDoBoard).
SC_fnc_aiSeatsNeeded = {
    params ["_size"];

    _size min SC_var_aiFullSquadSize
};

// vehicles an AI squad of _size units can travel in: no planes, UAVs, boats or parachutes (a parachute is a kind of
// helicopter), _size seats (the mobile spawn vehicles of SC\vehicles\spawnVehicles.sqf are excluded by
// SC_fnc_aiIsVehicleUsable)
SC_fnc_aiIsSquadVehicleType = {
    params ["_type", "_size"];

    !([_type] call SC_fnc_isPlaneType) && {!(_type isKindOf "ParachuteBase")} &&
        {(getNumber (configFile >> "CfgVehicles" >> _type >> "isUav")) != 1} &&
        {(_type isKindOf "Car") || {_type isKindOf "Tank"} || {_type isKindOf "Helicopter"}} &&
        {(([_type] call SC_fnc_aiSeatCounts) select 0) >= _size}
};

// vehicles spawned for an AI squad: squad vehicles whose crew seats the squad can fill (no tank for a lone AI)
SC_fnc_aiIsSpawnTypeForSquad = {
    params ["_type", "_size"];

    ([_type, _size] call SC_fnc_aiIsSquadVehicleType) && {(([_type] call SC_fnc_aiSeatCounts) select 1) <= _size}
};

// Vehicle budgets, renewed by SC_fnc_aiVehicleLoop. Men sharing one vehicle: SC_var_aiMenPerVehicleDistance divided by
// the sector spacing, within SC_var_aiMenPerVehicle [min, max] (far apart sectors: more vehicles per man; small maps
// keep 6). The AI of a side may have one vehicle per that many AI it is wanted to have (SC_fnc_getWantedAiAmounts:
// players take the place of AI, so the budget follows the AI actually on the side). On maps with a vehicle limit (not
// huge) a side may have SC_var_vehicleLimitFactor times the vehicles of the strongest side (players and AI).
SC_var_aiMenPerVehicle = [3, 6];
SC_var_aiMenPerVehicleDistance = 9000;
SC_var_vehicleLimitFactor = 1.5;

SC_fnc_updateVehicleBudgets = {
    SC_var_aiMenPerVehicle params ["_minMen", "_maxMen"];

    private _menPerVehicle = _minMen max (_maxMen min (SC_var_aiMenPerVehicleDistance / (1 max SC_var_aiSectorSpacing)));
    private _wantedAiAmounts = call SC_fnc_getWantedAiAmounts;
    private _strength = selectMax ((_wantedAiAmounts vectorAdd (call SC_fnc_getPlayerCounts)) + [SC_var_wantedUnitAmount]);
    private _vehicles = 1 max (ceil (_strength / _menPerVehicle));
    private _limit = (_vehicles + 1) max (round (SC_var_vehicleLimitFactor * _vehicles));

    SC_var_aiVehicleBudgets = _wantedAiAmounts apply {ceil (_x / _menPerVehicle)};

    if (_limit != (missionNamespace getVariable ["SC_var_maximumVehicleAmount", -1])) then {
        SC_var_maximumVehicleAmount = _limit;
        publicVariable "SC_var_maximumVehicleAmount";
    };
};

// whether the AI of a side may spawn one more vehicle: within the AI's own budget of the side (SC_var_aiVehicleBudgets
// vehicles spawned for the AI, so that vehicles of players don't take all), and on maps with a vehicle limit only while
// the side is at least 2 below it (the last place stays for its players, SC\vehicles\spawning.sqf)
SC_fnc_aiCanSpawnVehicle = {
    params ["_side"];

    private _sideIndex = SC_var_sides find _side;

    (_sideIndex != -1) &&
        {((missionNamespace getVariable ["SC_var_numAiVehiclesSides",[]]) param [_sideIndex,
        0]) <(SC_var_aiVehicleBudgets param [_sideIndex, 0])} &&
        {SC_var_hugeMap || {(SC_var_numVehiclesSides select _sideIndex) <(SC_var_maximumVehicleAmount - 1)}}
};

// Type of a vehicle spawned for an AI squad of _size units of side _side whose AI has rank _rank (types of the rank
// only; "" if the AI of the side may spawn no more vehicles, SC_fnc_aiCanSpawnVehicle): one whose crew seats the squad
// fills and with a seat for everybody, else (a squad bigger than every type) one with SC_fnc_aiSeatsNeeded seats;
// mostly one of the higher ranks. "" if there is none.
SC_fnc_aiPickVehicleType = {
    params ["_rank", "_size", "_side"];

    if !([_side] call SC_fnc_aiCanSpawnVehicle) exitWith {""};

    private _rankVehicles = SC_var_availableVehiclesWithoutUnarmedUavs select {(_x select 1) <= _rank};
    private _types = _rankVehicles select {[_x select 0, _size] call SC_fnc_aiIsSpawnTypeForSquad};

    if (_types isEqualTo []) then {
        private _seatsNeeded = [_size] call SC_fnc_aiSeatsNeeded;
        _types = _rankVehicles select {[_x select 0, _seatsNeeded] call SC_fnc_aiIsSpawnTypeForSquad};
    };

    if (_types isEqualTo []) exitWith {""};

    _types = ([_types, [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy) apply {_x select 0};

    _types select ((floor ((random [0.4, 0.85, 1]) * (count _types))) min ((count _types) - 1))
};

// Seats of a vehicle spawned for a squad of _size units at a spawn point: also room for the own AI on foot without a
// vehicle there, which ride along (SC_fnc_aiGathers, SC_fnc_aiJoinRide), up to SC_var_aiBusSeats. The AI vehicles of a
// side are limited (SC_var_aiVehicleBudgets): a lone AI in a small vehicle would leave the others to walk.
SC_var_aiBusSeats = 8;

SC_fnc_aiTransportSize = {
    params ["_pos", "_side", "_size", "_group"];

    private _walkers = {
        (alive _x) && {simulationEnabled _x} && {!(isPlayer _x)} && {isNull (objectParent _x)} &&
            {(side (group _x)) == _side} && {(group _x) isNotEqualTo _group} &&
            {isNull ((group _x) getVariable ["SC_var_aiVehicle", objNull])}
    } count (_pos nearEntities ["CAManBase", SC_var_aiGatherRadius]);

    _size max (SC_var_aiBusSeats min (_size + _walkers))
};

// whether the AI of the side may spawn one more vehicle (SC_fnc_aiCanSpawnVehicle); counts it at once (the vehicle loop
// recounts)
SC_fnc_aiTakeVehicleSlot = {
    params ["_side"];

    if !([_side] call SC_fnc_aiCanSpawnVehicle) exitWith {false};

    [_side, true] call SC_fnc_countSpawnedVehicle;
    true
};

// a squad without a vehicle in reach that stands at an own spawn point (its base, the middle of an own sector where
// vehicles may be spawned) gets a vehicle spawned there like the players do (its leader gets in as the driver, so only
// when no player sees it), within the side's vehicle limit; at most every SC_var_aiVehicleRequestTime seconds per squad
SC_var_aiVehicleRequestTime = 300;
SC_var_aiPendingVehicleGroups = [];

// Initial spawning and the squad loop share one in-flight request. Queueing a second asynchronous
// spawn used to produce vehicles after the requester had already found transport or walked away.
SC_fnc_aiQueueVehicle = {
    params ["_unit", "_place", "_type"];

    if (isNull _unit || {isPlayer _unit} || {!alive _unit}) exitWith {false};

    private _group = group _unit;
    private _queued = false;

    isNil {
        if (!scriptDone (_group getVariable ["SC_var_aiVehicleRequest", scriptNull])) exitWith {};

        if (!isNull ([_group] call SC_fnc_aiGetSquadVehicle)) exitWith {};

        // a land vehicle or helicopter nearby instead (not for a boat: the squad needs one to cross the water)
        private _available = if(_type isKindOf "Ship") then {objNull} else {[_group,
            (units _group) select {alive _x && {simulationEnabled _x}}] call SC_fnc_aiFindVehicle};
        if (!isNull _available) exitWith {[_group, _available, "reuse before spawn"] call SC_fnc_aiReserveVehicle};

        if (!([side _group] call SC_fnc_aiTakeVehicleSlot)) exitWith {};

        private _request = [_unit, _place, _type, _group] spawn {
            params ["_unit", "_place", "_type", "_group"];

            if (!isPlayer _unit && {alive _unit} && {group _unit == _group}) then {[_unit, _place, _type] call SC_fnc_spawnVehicle};
            _group setVariable ["SC_var_aiVehicleRequest", scriptNull];
        };

        _group setVariable ["SC_var_aiVehicleRequest", _request];
        SC_var_aiPendingVehicleGroups pushBackUnique _group;
        _queued = true;
    };

    _queued
};

SC_fnc_aiVehicleRequestStillNeeded = {
    params ["_unit", "_group", "_spawnPos"];

    !isNull _unit && {!isPlayer _unit} && {alive _unit} && {simulationEnabled _unit} &&
        {group _unit == _group} && {isNull ([_group] call SC_fnc_aiGetSquadVehicle)} &&
        {_unit distance2D _spawnPos < 150} &&
        {([getPosWorld _unit, side _group, _group] call SC_fnc_aiDistanceToGoal) > SC_var_aiVehicleUseDistance}
};

SC_fnc_aiRequestVehicle = {
    params ["_group", "_able"];

    if (time < (_group getVariable ["SC_var_aiNextVehicleRequest", 0])) exitWith {};

    _group setVariable ["SC_var_aiNextVehicleRequest", time + SC_var_aiVehicleRequestTime];

    private _leader = leader _group;
    private _side = side _group;
    private _place = "";

    if ([_leader, SC_var_aiSeenDistance] call SC_fnc_aiIsSeenByPlayers) exitWith {};

    if ((_leader distance2D (getMarkerPos ("SC_var_" + (toLower (str _side)) + "Respawn"))) < 150) then {
        _place = "the Base";
    } else {

        if SC_var_spawnVehiclesOnSectors then {
            private _index = SC_var_sectors findIf {
                ((missionNamespace getVariable ("SC_var_owner" + _x)) == _side) && {(_leader distance2D (getMarkerPos ("SC_var_sector" + _x))) < 100}
            };

            if (_index != -1) then {
                _place = SC_var_sectors select _index;
            };
        };
    };

    if (_place == "") exitWith {};

    // for the size the squad will have (it may still be filling up)
    private _size =[getPosWorld _leader, _side,(count _able) max ([_leader] call SC_fnc_getGroupTargetSize),
        _group] call SC_fnc_aiTransportSize;
    private _type = [(_leader getVariable ["SC_var_rank", 1]), _size, _side] call SC_fnc_aiPickVehicleType;

    if (_type == "") exitWith {};

    ["vehicle", _group, _type, "requested", _place] call SC_fnc_aiLog;
    [_leader, _place, _type] call SC_fnc_aiQueueVehicle;
};

// whether a vehicle can still bring the squad somewhere: intact, mobile, fuel, upright, not locked by a player, no AI
// crew of another group and no player driving (players riding along, e.g. one who spawned at a squad mate in it, don't
// take it away from the squad), not recently abandoned by the AI, not a mobile spawn vehicle (they are the players')
SC_fnc_aiIsVehicleUsable = {
    params ["_vehicle", "_group"];

    (alive _vehicle) && {!(_vehicle getVariable ["SC_var_spawnVehicle", false])} && {canMove _vehicle} &&
        {(fuel _vehicle) > 0.05} && {((vectorUp _vehicle) select 2) > 0.5} && {(locked _vehicle) <= 1} &&
        {(_vehicle getVariable ["SC_var_aiAbandonedUntil", 0]) < time} &&
        {((crew _vehicle) findIf {(alive _x) && {(group _x) isNotEqualTo _group} &&
        {!(isPlayer _x) || {(driver _vehicle) isEqualTo _x}}}) == -1}
};

// a squad waits this long (s) for its flipped vehicle before it abandons it (the unflip mod turns AI vehicles back after
// about 10 s)
SC_var_aiFlipWaitTime = 20;

// whether a squad waits for its flipped ground vehicle (on its side or roof, not in the water) instead of abandoning it:
// for SC_var_aiFlipWaitTime seconds after it flipped
SC_fnc_aiWaitsForUnflip = {
    params ["_vehicle"];

    if (
    !(alive _vehicle) || {_vehicle isKindOf "Air"} || {((vectorUp _vehicle) select 2) > 0.5} || {surfaceIsWater (getPosWorld _vehicle)}

    ) exitWith {
        _vehicle setVariable ["SC_var_aiFlippedSince", nil];
        false
    };

    private _since = _vehicle getVariable "SC_var_aiFlippedSince";

    if (isNil "_since") then {
        _since = time;
        _vehicle setVariable ["SC_var_aiFlippedSince", _since];
    };

    (time - _since) < SC_var_aiFlipWaitTime
};

// the squad's reserved vehicle (objNull if it has none or the reservation broke: destroyed, deleted, taken by a player)
SC_fnc_aiGetSquadVehicle = {
    params ["_group"];

    private _vehicle = _group getVariable ["SC_var_aiVehicle", objNull];

    if (isNull _vehicle) exitWith {objNull};

    if (!(alive _vehicle) || {(_vehicle getVariable ["SC_var_aiVehicleGroup", grpNull]) isNotEqualTo _group}) exitWith {
        [_group, _vehicle, "lost"] call SC_fnc_aiReleaseVehicle;
        objNull
    };

    _vehicle
};

// whether a vehicle is reserved by another (still existing) AI squad
SC_fnc_aiIsReservedByOther = {
    params ["_vehicle", "_group"];

    private _owner = _vehicle getVariable ["SC_var_aiVehicleGroup", grpNull];

    !(isNull _owner) && {_owner isNotEqualTo _group} &&
        {((_owner getVariable ["SC_var_aiVehicle", objNull]) isEqualTo _vehicle)} &&
        {((units _owner) findIf {(alive _x) && {simulationEnabled _x}}) != -1}
};

SC_fnc_aiReserveVehicle = {
    params ["_group", "_vehicle", "_reason"];

    _group setVariable ["SC_var_aiVehicle", _vehicle];
    _group setVariable ["SC_var_aiStuckCheck", nil];
    _vehicle setVariable ["SC_var_aiVehicleGroup", _group];

    // the squad decides when to get out (SC_fnc_aiUpdateSquad), the engine only for an immobile vehicle
    _vehicle setUnloadInCombat [false, false];
    _vehicle allowCrewInImmobile [false, false];
    _group addVehicle _vehicle;

    ["vehicle", _group, typeOf _vehicle, "reserved", _reason] call SC_fnc_aiLog;
};

// ends the reservation; units of the group that are still assigned to the vehicle get out
SC_fnc_aiReleaseVehicle = {
    params ["_group", "_vehicle", "_reason"];

    if ((_group getVariable ["SC_var_aiVehicle", objNull]) isEqualTo _vehicle) then {
        _group setVariable ["SC_var_aiVehicle", objNull];
    };

    if (isNull _vehicle) exitWith {};

    if ((_vehicle getVariable ["SC_var_aiVehicleGroup", grpNull]) isEqualTo _group) then {
        _vehicle setVariable ["SC_var_aiVehicleGroup", grpNull];
    };

    if (!(isNull _group) && {_vehicle in (assignedVehicles _group)}) then {
        _group leaveVehicle _vehicle;
    };

    // a later boarding of the same vehicle is a new one (SC_fnc_aiDoBoard)
    if (((_group getVariable ["SC_var_aiBoarding", []]) param [0, objNull]) isEqualTo _vehicle) then {
        _group setVariable ["SC_var_aiBoarding", nil];
    };

    ["vehicle", _group, typeOf _vehicle, "released", _reason] call SC_fnc_aiLog;
};

// nearest free vehicle (empty or only crewed by the squad, not reserved by another squad) within
// SC_var_aiVehicleWalkDistance of the leader with free seats for all able members outside; else (a big squad) the
// nearest with SC_fnc_aiSeatsNeeded free seats; objNull if there is none
SC_fnc_aiFindVehicle = {
    params ["_group", "_able"];

    private _leader = leader _group;
    private _seatsNeeded = [count _able] call SC_fnc_aiSeatsNeeded;
    private _outside = count _able;
    private _bestVehicle = objNull;
    private _bestRating = 1e9;

    {
        private _vehicle = _x;
        private _freeSeats = {isNull (_x select 0)} count (fullCrew [_vehicle, "", true]);

        // a vehicle with a seat for everybody before any that leaves some on foot
        private _rating = (_leader distance _vehicle) + ([0, 1e5] select (_freeSeats < _outside));

        if (
        (_rating < _bestRating) && {_freeSeats >= _seatsNeeded} &&
            {[typeOf _vehicle, _seatsNeeded] call SC_fnc_aiIsSquadVehicleType} &&
            {[_vehicle, _group] call SC_fnc_aiIsVehicleUsable} &&
            {!([_vehicle, _group] call SC_fnc_aiIsReservedByOther)} &&
            {!(surfaceIsWater (getPosWorld _vehicle))}

        ) then {
            _bestVehicle = _vehicle;
            _bestRating = _rating;
        };
    } forEach (_leader nearEntities [["Car", "Tank", "Helicopter"], SC_var_aiVehicleWalkDistance]);

    _bestVehicle
};

// ---- seats ----

SC_fnc_aiAssignSeat = {
    params ["_unit", "_vehicle", "_seat"];

    _seat params ["", "_role", "_cargoIndex", "_turretPath", "_isPersonTurret"];

    switch _role do {
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
        default {
            _unit assignAsCargoIndex [_vehicle, _cargoIndex];
        };
    };

    _unit setVariable ["SC_var_aiSeat", _role];
};

// Seats for the able members: members inside keep their seat, the driver seat is filled first (by the leader if he
// is outside), then gunner, commander and turrets, then cargo; the members outside are ordered in. Returns the
// members that got no seat (more members than seats).
SC_fnc_aiAssignSeats = {
    params ["_group", "_vehicle", "_able"];

    private _outside = _able select {(objectParent _x) isNotEqualTo _vehicle};

    if (_outside isEqualTo []) exitWith {[]};

    // leader first, so that he takes the driver seat if it is free
    private _leader = leader _group;

    if (_leader in _outside) then {
        _outside = [_leader] + (_outside - [_leader]);
    };

    private _rolePriority = ["driver", "gunner", "commander", "turret", "cargo"];

    // a seat assigned to a unit of another group that isn't in the vehicle (e.g. one that rode along and went its own
    // way) is free
    {
        _x params ["_crewUnit", "", "", "", "", "_assignedUnit"];

        if (
        (isNull _crewUnit) && {!(isNull _assignedUnit)} && {(group _assignedUnit) isNotEqualTo _group} &&
            {(objectParent _assignedUnit) isNotEqualTo _vehicle}

        ) then {
            unassignVehicle _assignedUnit;
        };
    } forEach (fullCrew [_vehicle, "", true]);

    private _freeSeats = (fullCrew [_vehicle, "", true]) select {
        (isNull (_x select 0)) && {(isNull (_x select 5)) || {(_x select 5) in _able}}
    };

    _freeSeats = [_freeSeats, [], {_rolePriority find (_x select 1)}, "ASCEND"] call BIS_fnc_sortBy;

    {
        if (_forEachIndex >= (count _freeSeats)) exitWith {};

        [_x, _vehicle, (_freeSeats select _forEachIndex)] call SC_fnc_aiAssignSeat;
    } forEach _outside;

    private _seated = _outside select [0, count _freeSeats];
    _seated allowGetIn true;
    _seated orderGetIn true;

    _outside - _seated
};

// everybody gets out (unarmed vehicle, abandon) or only the passengers (an armed vehicle keeps its crew, which then
// supports the squad); the new leader is a unit on foot
SC_fnc_aiDismount = {
    params ["_group", "_vehicle", "_onlyPassengers", "_reason"];

    private _leaving = (units _group) select {
        ((objectParent _x) isEqualTo _vehicle) &&
            {!_onlyPassengers || {(assignedVehicleRole _x) param [0, ""] == "cargo"} ||
            {[_x, _vehicle] call SC_fnc_aiIsPersonTurret}}
    };

    if !_onlyPassengers then {
        _group leaveVehicle _vehicle;
    };

    {
        unassignVehicle _x;
        _x setVariable ["SC_var_aiSeat", nil];
    } forEach _leaving;

    _leaving orderGetIn false;
    doGetOut _leaving;

    private _onFoot = _leaving select {!(_x getVariable ["AIS_unconscious", false])};

    if ((_onFoot isNotEqualTo []) && {!((leader _group) in _onFoot)}) then {
        _group selectLeader (_onFoot select 0);
    };

    _group setVariable ["SC_var_aiDismountTime", time];
    ["dismount", _group, typeOf _vehicle, count _leaving, _reason] call SC_fnc_aiLog;
};

SC_fnc_aiIsPersonTurret = {
    params ["_unit", "_vehicle"];

    private _seat = (fullCrew _vehicle) select {(_x select 0) isEqualTo _unit};

    (_seat isNotEqualTo []) && {(_seat select 0) select 4}
};

// whether a vehicle has a weapon its crew can use (gunner or commander turret that isn't a person turret)
SC_fnc_aiIsArmed = {
    params ["_vehicle"];

    ((fullCrew [_vehicle, "", true]) findIf {((_x select 1) in ["gunner", "commander", "turret"]) && {!(_x select 4)}}) != -1
};

// ---- stuck, repair, abandon ----

// a vehicle that can't be used any more is left: everybody gets out, the AI ignores it for SC_var_aiAbandonTime
SC_fnc_aiAbandonVehicle = {
    params ["_group", "_vehicle", "_reason"];

    _vehicle setVariable ["SC_var_aiAbandonedUntil", time + SC_var_aiAbandonTime];
    [_group, _vehicle, false, ("abandon: " + _reason)] call SC_fnc_aiDismount;
    [_group, _vehicle, ("abandon: " + _reason)] call SC_fnc_aiReleaseVehicle;
    _group setVariable ["SC_var_aiRepair", nil];
};

// whether a squad member can repair the vehicle: a toolkit in the vehicle or with a member, no enemy close
SC_fnc_aiCanRepair = {
    params ["_vehicle", "_able", "_enemyDistance"];

    (_enemyDistance > 150) && {((vectorUp _vehicle) select 2) > 0.5} &&
        {("ToolKit" in (itemCargo _vehicle)) || {(_able findIf {"ToolKit" in (items _x)}) != -1}}
};

// the repairer (nearest able member) gets out, walks to the vehicle and repairs it (engine action of an engineer
// with a toolkit; the toolkit of the vehicle is lent to him if he has none)
SC_fnc_aiStartRepair = {
    params ["_group", "_vehicle", "_able"];

    private _repairer = ([_able, [], {_x distance _vehicle}, "ASCEND"] call BIS_fnc_sortBy) select 0;

    if !("ToolKit" in (items _repairer)) then {
        _repairer addItem "ToolKit";
        _repairer setVariable ["SC_var_aiLentToolKit", true];
    };

    if ((objectParent _repairer) isEqualTo _vehicle) then {
        unassignVehicle _repairer;
        [_repairer] orderGetIn false;
        moveOut _repairer;
    };

    _repairer doMove (getPosATL _vehicle);
    _group setVariable ["SC_var_aiRepair", [_repairer, time, false]];
    ["repair", _group, typeOf _vehicle, "start", name _repairer] call SC_fnc_aiLog;
};

SC_fnc_aiEndRepair = {
    params ["_group", "_vehicle", "_repairer", "_startTime", "_result"];

    if (_repairer getVariable ["SC_var_aiLentToolKit", false]) then {
        _repairer removeItem "ToolKit";
        _repairer setVariable ["SC_var_aiLentToolKit", nil];
    };

    _group setVariable ["SC_var_aiRepair", nil];
    _group setVariable ["SC_var_aiStuckCheck", nil];
    ["repair", _group, typeOf _vehicle, _result, round (time - _startTime)] call SC_fnc_aiLog;
};

// one step of a running repair; returns true while the repair still runs
SC_fnc_aiUpdateRepair = {
    params ["_group", "_vehicle"];

    (_group getVariable ["SC_var_aiRepair", []]) params [["_repairer", objNull], ["_startTime", 0], ["_actionStarted", false]];

    if (canMove _vehicle) exitWith {
        [_group, _vehicle, _repairer, _startTime, "done"] call SC_fnc_aiEndRepair;
        false
    };

    if (!(alive _repairer) || {_repairer getVariable ["AIS_unconscious", false]} || {(time - _startTime) > SC_var_aiRepairTimeout}) exitWith {
        [_group, _vehicle, _repairer, _startTime, "failed"] call SC_fnc_aiEndRepair;
        [_group, _vehicle, "repair failed"] call SC_fnc_aiAbandonVehicle;
        false
    };

    if (!_actionStarted && {(_repairer distance _vehicle) < 8}) then {
        _repairer action ["RepairVehicle", _vehicle];
        _group setVariable ["SC_var_aiRepair", [_repairer, _startTime, true]];
    } else {

        if (!_actionStarted && {unitReady _repairer}) then {
            _repairer doMove (getPosATL _vehicle);
        };
    };

    true
};

// Stuck check of a travelling vehicle: no SC_var_aiStuckDistance progress (net, so rocking back and forth counts) in
// SC_var_aiStuckTime seconds. Stage 1: new path (_reroute: a new destination); stage 2: a detour (a point beside the
// vehicle, then on to the destination); stage 3: abandon. Returns false if the vehicle was abandoned.
SC_fnc_aiCheckStuck = {
    params ["_group", "_vehicle", "_destination", ["_reroute", false]];

    private _pos = getPosWorld _vehicle;
    (_group getVariable ["SC_var_aiStuckCheck", [time, _pos, 0]]) params ["_since", "_checkPos", "_stage"];

    if ((_pos distance2D _checkPos) > SC_var_aiStuckDistance) exitWith {
        _group setVariable ["SC_var_aiStuckCheck", [time, _pos, 0]];
        true
    };

    if ((time - _since) < (SC_var_aiStuckTime * (_stage + 1))) exitWith {
        _group setVariable ["SC_var_aiStuckCheck", [_since, _checkPos, _stage]];
        true
    };

    _stage = _stage + 1;
    _group setVariable ["SC_var_aiStuckCheck", [_since, _checkPos, _stage]];
    private _stuckDriver = driver _vehicle;
    [
    "stuck", _group, typeOf _vehicle, _stage, round (_vehicle distance2D _destination), _pos apply {round _x},
    (expectedDestination _stuckDriver) select 1, currentCommand _stuckDriver, isEngineOn _vehicle, round (speed _vehicle),
    (leader _group) isEqualTo _stuckDriver, behaviour _stuckDriver, (waypointPosition [_group, currentWaypoint _group]) apply {round _x},
    count (waypoints _group), count (crew _vehicle)
    ] call SC_fnc_aiLog;

    switch _stage do {

        // a squad's travel gets another destination turned to one side (the vehicle may find no way to the old one,
        // SC_fnc_aiGetTravelDestination), other drives plan their way again
        case 1: {
            if _reroute then {
                _group setVariable ["SC_var_aiDestinationTurn", selectRandom [-60, 60]];
                _group setVariable ["SC_var_aiDestination", nil];
            } else {

                [_group, _destination, "MOVE", true] call SC_fnc_aiSetWaypoint;
            };

            true
        };
        case 2: {
            private _detour = _vehicle getRelPos [40, selectRandom [100, 260]];

            if (surfaceIsWater _detour) then {
                _detour = _vehicle getRelPos [30, 180];
            };

            [_group, _detour, "MOVE", true] call SC_fnc_aiSetWaypoint;
            private _waypoint = _group addWaypoint [_destination, 0];
            _waypoint setWaypointType "MOVE";

            // the destination stays the squad's order (SC_fnc_aiDoTravel doesn't give it again)
            _group setVariable ["SC_var_aiWaypoint", [_destination, "MOVE", time]];
            true
        };
        default {
            [_group, _vehicle, "stuck"] call SC_fnc_aiAbandonVehicle;
            false
        };
    };
};

// whether a player is within _distance of an object (AI tricks like setPos are only done unseen)
SC_fnc_aiIsSeenByPlayers = {
    params ["_object", "_distance"];

    ((allPlayers select {!(_x isKindOf "HeadlessClient_F")}) findIf {(_x distance _object) < _distance}) != -1
};

// ---- vehicle loop ----

// [min distance, depletion factor] of the despawn / ownership timer of a vehicle (in a base only units right at the
// vehicle keep it, and the timer runs down faster)
SC_fnc_getVehicleTimerParams = {
    params ["_vehicle"];

    private _posVehicle = getPosWorld _vehicle;

    if ((SC_var_sides findIf {_posVehicle inArea ("SC_var_" + (str _x) + "Base")}) != -1) then {
        [1, 5]
    } else {

        [SC_var_minDistanceFromVehicleToDespawn, 1]
    }
};

// Side ownership: a vehicle counts for the vehicle limit (and the HUD count) of the side that used it last. The
// ownership timer is full while units of that side sit in it, recovers while they are near and runs down while
// nobody of that side is near (like the despawn timer); at 0 the vehicle is free for whoever takes it next.
// Returns the owner side (sideUnknown: none); SC_var_vehicleSide is public (vehicle locking).
SC_fnc_updateVehicleOwnership = {
    params ["_vehicle", "_crewAlive"];

    private _ownerSide = _vehicle getVariable ["SC_var_vehicleSide", sideUnknown];
    private _ownershipTime = 0;

    if (_crewAlive isNotEqualTo []) then {
        _ownerSide = side (group (_crewAlive select 0));
        _ownershipTime = SC_var_vehicleOwnershipTime;
    } else {

        if (_ownerSide in SC_var_sides) then {
            ([_vehicle] call SC_fnc_getVehicleTimerParams) params ["_minDistance", "_depletionFactor"];

            _ownershipTime = [
            _vehicle,
            (_vehicle getVariable ["SC_var_ownershipTime", SC_var_vehicleOwnershipTime]),
            SC_var_vehicleOwnershipTime,
            _minDistance,
            2,
            _depletionFactor,
            _ownerSide
            ] call SC_fnc_getNewDespawnTime;

            if (_ownershipTime <= 0) then {
                _ownerSide = sideUnknown;
            };
        };
    };

    _vehicle setVariable ["SC_var_ownershipTime", _ownershipTime];

    if (_ownerSide isNotEqualTo (_vehicle getVariable ["SC_var_vehicleSide", sideUnknown])) then {
        _vehicle setVariable ["SC_var_vehicleSide", _ownerSide, true];
    };

    _ownerSide
};

// speed (km/h) above which a vehicle of a kind is glitched (physics explosion) and removed
SC_fnc_getGlitchSpeed = {
    params ["_vehicle"];

    switch true do {
        case (_vehicle isKindOf "Car_F"): {400};
        case (_vehicle isKindOf "Tank_F"): {200};
        case (_vehicle isKindOf "Helicopter_F"): {600};
        default {1000};
    }
};

// the crew of a vehicle that is removed: players are moved out of the game until they respawn, AI are suspended
SC_fnc_removeVehicleCrew = {
    params ["_crew", "_reason", ["_forceRespawn", false]];

    {
        if (isPlayer _x) then {
            _x enableSimulationGlobal false;
            _x setPosWorld [0, 0, 10];

            if (_forceRespawn && {alive _x}) then {
                forceRespawn _x;
            };
        } else {

            [_x, _reason] call SC_fnc_suspendUnit;
        };
    } forEach _crew;
};

// one step of the vehicle loop for a registered vehicle: removes glitched vehicles and AI vehicles that hang in the
// air, puts flipped helicopters back on their wheels, rewards transports, counts the vehicles per owner side and runs
// the despawn timer of empty or immobile vehicles. Stuck vehicles of AI squads are handled by the squads.
SC_fnc_updateVehicle = {
    params ["_vehicle", "_counts"];

    private _crew = crew _vehicle;

    if ((speed _vehicle) > ([_vehicle] call SC_fnc_getGlitchSpeed)) exitWith {
        [_crew, "vehicle glitch", true] call SC_fnc_removeVehicleCrew;
        ["vehicleRemoved", grpNull, typeOf _vehicle, "glitch"] call SC_fnc_aiLog;
        [_vehicle] remoteExec ["SC_fnc_safelyDeleteVehicle", (owner _vehicle)];
    };

    private _checkIfAlone = !(alive _vehicle);

    if (alive _vehicle) then {
        private _pos = getPos _vehicle;
        private _crewAlive = _crew select {alive _x};

        if ((_vehicle isKindOf "Helicopter") && {((vectorUp _vehicle) select 2) < 0} && {(_pos select 2) < 10}) then {
            [_vehicle, _pos, (surfaceNormal _pos)] remoteExec ["SC_fnc_resetVehiclePose", (owner _vehicle)];
        };

        // an AI aircraft that hasn't moved for a long time hangs in the air (hovering, landing that never ends)
        (_vehicle getVariable "SC_var_posAtServerTime") params ["_lastPos", "_lastTime"];

        if ((serverTime - _lastTime) > SC_var_timeToDeleteNotMovingVehicle) then {
            if (
            ((_pos distance _lastPos) < 10) && {(_pos select 2) > 5} && {_crewAlive isNotEqualTo []} &&
                {(_crewAlive findIf {isPlayer _x}) == -1} &&
                {(([_vehicle] call SC_fnc_uavControlUnits) findIf {isPlayer _x}) == -1}

            ) then {
                [_crew, "aircraft hanging"] call SC_fnc_removeVehicleCrew;
                ["vehicleRemoved", grpNull, typeOf _vehicle, "hanging in the air"] call SC_fnc_aiLog;
                [_vehicle] remoteExec ["SC_fnc_safelyDeleteVehicle", (owner _vehicle)];
                _checkIfAlone = false;
                _crewAlive = [];
            } else {

                _vehicle setVariable ["SC_var_posAtServerTime", [_pos, serverTime]];
            };
        };

        if ((_crewAlive isEqualTo []) || {(((getPosATL _vehicle) select 2) < 5) && {!(canMove _vehicle)}}) then {
            _checkIfAlone = true;
        };

        // a unit assigned to a seat someone else sits in (e.g. a player took it) gets a new seat from its squad
        {
            _x params ["_crewUnit", "", "", "", "", "_assignedUnit"];

            if ((alive _crewUnit) && {!(isNull _assignedUnit)} && {_assignedUnit isNotEqualTo _crewUnit}) then {
                unassignVehicle _assignedUnit;
            };
        } forEach (fullCrew _vehicle);

        [_vehicle] call SC_fnc_updateTransport;

        [_counts, _vehicle, SC_var_sides find ([_vehicle, _crewAlive] call SC_fnc_updateVehicleOwnership)] call SC_fnc_addVehicleCount;
    };

    if (!_checkIfAlone || {isNull _vehicle}) exitWith {};

    private _timeRemaining = _vehicle getVariable "SC_var_timeRemaining";

    if (isNil "_timeRemaining") exitWith {};

    // the vehicle of an AI squad that fights near it waits for the squad (SC_fnc_aiUpdateSquad releases it once the
    // squad walks away or abandons it)
    if (
    (alive _vehicle) && {[_vehicle, grpNull] call SC_fnc_aiIsReservedByOther} &&
        {((leader (_vehicle getVariable "SC_var_aiVehicleGroup")) distance _vehicle) <(2 *(missionNamespace
        getVariable ["SC_var_aiVehicleWalkDistance", 100]))}

    ) exitWith {
        _vehicle setVariable ["SC_var_timeRemaining", SC_var_vehicleDespawnTime];
    };

    ([_vehicle] call SC_fnc_getVehicleTimerParams) params ["_minDistanceFromVehicleToDespawn", "_despawnTimeDepletionFactor"];

    _timeRemaining = [
    _vehicle,
    _timeRemaining,
    SC_var_vehicleDespawnTime,
    _minDistanceFromVehicleToDespawn,
    2,
    _despawnTimeDepletionFactor
    ] call SC_fnc_getNewDespawnTime;

    if (_timeRemaining <= 0) then {
        private _posVehicle = getPos _vehicle;

        {
            _x setPos _posVehicle;
        } forEach _crew;

        ["vehicleRemoved", grpNull, typeOf _vehicle, "despawn"] call SC_fnc_aiLog;
        [_vehicle] remoteExec ["SC_fnc_safelyDeleteVehicle", (owner _vehicle)];
    } else {

        _vehicle setVariable ["SC_var_timeRemaining", _timeRemaining];
    };
};

// counts a vehicle for the side with index _sideIndex (-1: none) in _counts: [vehicles per side, vehicles spawned for
// the AI per side]
SC_fnc_addVehicleCount = {
    params ["_counts", "_vehicle", "_sideIndex"];

    _counts params ["_numVehiclesSides", "_numAiVehiclesSides"];

    if (_sideIndex == -1) exitWith {};

    _numVehiclesSides set [_sideIndex, (_numVehiclesSides select _sideIndex) + 1];

    if ((_vehicle getVariable ["SC_var_spawnerUid", ""]) == "") then {
        _numAiVehiclesSides set [_sideIndex, (_numAiVehiclesSides select _sideIndex) + 1];
    };
};

SC_fnc_aiVehicleLoop = {
    waitUntil {
        private _counts = [SC_var_sides apply {0}, SC_var_sides apply {0}];
        private _sleepTime = 3 / (1 max SC_var_numVehicles);

        // a copy: the registry shrinks while the pass runs (deleted vehicles)
        private _passVehicles = +SC_var_vehicles;

        {
            private _startTime = time;

            if !(isNull _x) then {
                [_x, _counts] call SC_fnc_updateVehicle;
            };

            sleep (0.1 max (_sleepTime - (time - _startTime)));
        } forEach _passVehicles;

        // vehicles spawned during the pass count for their spawn side (else the AI would spawn more meanwhile)
        {
            if (!(_x in _passVehicles) && {alive _x}) then {
                [_counts, _x, SC_var_sides find (_x getVariable ["SC_var_vehicleSide", sideUnknown])] call SC_fnc_addVehicleCount;
            };
        } forEach SC_var_vehicles;

        // Waiting for a spawn semaphore still consumes an AI vehicle slot, even before a vehicle exists.
        SC_var_aiPendingVehicleGroups = SC_var_aiPendingVehicleGroups select {!isNull _x &&
            {!scriptDone (_x getVariable ["SC_var_aiVehicleRequest", scriptNull])}};

        {
            private _index = SC_var_sides find side _x;

            if (_index >= 0 && {isNull ([_x] call SC_fnc_aiGetSquadVehicle)}) then {
                private _aiCounts = _counts select 1;
                _aiCounts set [_index, 1 + (_aiCounts select _index)];
            };
        } forEach SC_var_aiPendingVehicleGroups;

        _counts params ["_numVehiclesSides", "_numAiVehiclesSides"];

        SC_var_numAiVehiclesSides = _numAiVehiclesSides;
        call SC_fnc_updateVehicleBudgets;

        if (_numVehiclesSides isNotEqualTo SC_var_numVehiclesSides) then {
            SC_var_numVehiclesSides = _numVehiclesSides;
            publicVariable "SC_var_numVehiclesSides";
        };

        sleep 0.5;
        false
    };
};
