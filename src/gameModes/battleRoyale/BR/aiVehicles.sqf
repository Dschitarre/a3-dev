// Battle Royale AI vehicles (server): for a long way into the zone, or when water lies in between, an AI takes a free
// car, boat or helicopter near it; team mates close by ride along in its group (AI only, for this ride). A vehicle that
// gets stuck or broken, or a ride that takes too long, is left and the way goes on on foot.

BR_var_aiRideMinDistance = 700;         // ways at least this long (or across water) are worth a vehicle ...
BR_var_aiVehicleSearchRadius = 1200;    // ... within this distance (a whole map has few vehicles per km²) ...
BR_var_aiVehicleDetourShare = 0.4;      // ... closer than this share of the way, and walking there and driving on is at
BR_var_aiVehicleDetourMin = 300;        // most this much (or the share of the way) longer than the way itself
BR_var_aiCrossingSearchRadius = 2500;  // to another landmass: a boat or helicopter this close (no detour limit)
BR_var_aiBoatShoreCells = 3;            // a boat belongs to the landmass this many grid cells from it
BR_var_aiLandingStep = 20;              // a boat lands where the way from the destination towards it first reaches water
BR_var_aiVehicleCheckInterval = 15;
BR_var_aiWaterCheckStep = 100;          // the straight way is checked for water every this many metres
BR_var_aiToVehicleTimeout = 90;         // give up after this long without getting closer to the reserved vehicle
BR_var_aiGetInDistance = 6;
BR_var_aiRideMateDistance = 40;         // team mates this close get in too
BR_var_aiRideArriveDistance = 70;       // a car or boat is left this close to the destination ...
BR_var_aiHeliArriveDistance = 250;      // ... a helicopter lands this close
BR_var_aiHeliHeight = 80;
BR_var_aiRideStuckTime = 20;            // a vehicle that moved less than BR_var_aiRideStuckDistance in this time is left
BR_var_aiRideStuckDistance = 15;        // (helicopters on the ground get twice the time: start up)
BR_var_aiRideLegLength = 1000;          // cars and boats drive in legs this long (BR_fnc_aiRideOrder) ...
BR_var_aiRideLegReach = 120;            // ... the next one once the vehicle is this close to the end of the current one
BR_var_aiRideRoadSnap = 300;            // a car's leg ends on the nearest road this close (if any)
BR_var_aiRideRetryCount = 2;            // a stuck car gets this many new orders before everyone gets out ...
BR_var_aiRideNearDistance = 150;        // ... (then this close to the destination the ride still counts as arrived)
BR_var_aiRideOffroadLeg = 300;          // the last way, off the road, in legs this long ...
BR_var_aiRideSpotSearch = 60;           // ... to a free spot for the vehicle this close to the destination (not in a house)
BR_var_aiRideMaxDamage = 0.6;
BR_var_aiRideExitSpeed = 10;            // km/h: a faster car stops first, then everyone gets out
BR_var_aiMinFuel = 0.05;

// true if the straight way from _from (object or position) to _to crosses water
BR_fnc_waterBetween = {
    params ["_from", "_to"];

    private _direction = _from getDir _to;
    private _water = false;

    for "_i" from 1 to floor ((_from distance2D _to) / BR_var_aiWaterCheckStep) do {
        if (surfaceIsWater (_from getPos [_i * BR_var_aiWaterCheckStep, _direction])) exitWith {
            _water = true;
        };
    };

    _water
};

/*
    Where a boat ride to _destination ends: from the destination towards the boat, the first water (the shore of the
    destination's landmass), a little out on the water. The destination itself if no water lies in between. Cached per
    destination on the driver.
*/
BR_fnc_aiLandingPoint = {
    params ["_unit", "_vehicle", "_destination"];

    private _cached = _unit getVariable ["BR_var_aiRideLanding", []];

    if ((_cached param [0, []]) isEqualTo _destination) exitWith {_cached select 1};

    private _direction = _destination getDir _vehicle;
    private _landing = _destination;

    for "_i" from 1 to floor ((_destination distance2D _vehicle) / BR_var_aiLandingStep) do {
        private _pos = _destination getPos [_i * BR_var_aiLandingStep, _direction];

        if (surfaceIsWater _pos) exitWith {
            _landing = _destination getPos [_i * BR_var_aiLandingStep + BR_var_aiLandingStep, _direction];
        };
    };

    _unit setVariable ["BR_var_aiRideLanding", [_destination, _landing]];
    _landing
};

/*
    On the way to _destination: looks for a vehicle worth it (BR_fnc_aiFindVehicle) now and then, walks there and gets in
    (BR_fnc_aiBoard). True while busy with that.
*/
BR_fnc_aiTryRide = {
    params ["_unit", "_destination"];

    private _vehicle = _unit getVariable ["BR_var_aiRideVehicle", objNull];

    if (isNull _vehicle && {time >= (_unit getVariable ["BR_var_aiNextVehicleCheck", 0])}) then {
        _unit setVariable ["BR_var_aiNextVehicleCheck", time + BR_var_aiVehicleCheckInterval];
        _vehicle = [_unit, _destination] call BR_fnc_aiFindVehicle;

        if (!isNull _vehicle) then {
            _vehicle setVariable ["BR_var_aiReservedBy", _unit];
            _unit setVariable ["BR_var_aiRideVehicle", _vehicle];
            _unit setVariable ["BR_var_aiRideSince", time];
            _unit setVariable ["BR_var_aiToVehicleProgress", [_unit distance _vehicle, time]];
        };
    };

    if (isNull _vehicle) exitWith {false};

    (_unit getVariable ["BR_var_aiToVehicleProgress", [_unit distance _vehicle, time]]) params ["_bestDistance", "_progressAt"];
    if (_unit distance _vehicle < _bestDistance - 2) then {
        _progressAt = time;
        _unit setVariable ["BR_var_aiToVehicleProgress", [_unit distance _vehicle, time]];
    };
    if (!([_unit, _vehicle] call BR_fnc_aiVehicleFree) || {time - _progressAt > BR_var_aiToVehicleTimeout}) exitWith {
        [_unit, _vehicle] call BR_fnc_aiDropVehicle;
        false
    };

    if (_unit distance _vehicle > BR_var_aiGetInDistance) exitWith {
        [_unit, getPosATL _vehicle] call BR_fnc_aiMoveTo;
        true
    };

    [_unit, _vehicle, _destination] call BR_fnc_aiBoard;
    true
};

/*
    The nearest free vehicle worth it for the way to _destination (objNull if none): only for a long way or across water;
    helicopters always, boats in the water when water lies in between, cars unless the way is short and crosses water.
*/
BR_fnc_aiFindVehicle = {
    params ["_unit", "_destination"];

    private _way = _unit distance2D _destination;
    // the destination on another landmass (BR\landmass.sqf): only a boat or a helicopter gets there; a car on the own
    // landmass would only lead to the shore
    private _from = [_unit] call BR_fnc_landmassNear;
    private _to = [_destination] call BR_fnc_landmassNear;
    private _crossing = _from >= 0 && {_to >= 0} && {_from != _to};
    private _water = _crossing || {[_unit, _destination] call BR_fnc_waterBetween};

    if (_way < BR_var_aiRideMinDistance && {!_water}) exitWith {objNull};

    private _searchRadius =[BR_var_aiVehicleSearchRadius min (_way * BR_var_aiVehicleDetourShare),
        BR_var_aiCrossingSearchRadius] select _crossing;
    private _nearest = objNull;
    private _nearestDistance = _searchRadius;

    {
        private _distance = _unit distance2D _x;
        // reachable on foot: a boat at the coast or a car on the unit's own landmass
        private _onOwnLand = _from < 0 || {([_x, BR_var_aiBoatShoreCells] call BR_fnc_landmassNear) in [_from, -1]};
        private _suitable = switch (true) do {
            // a plane (the airfields', BR\vehicles.sqf) cannot land at the destination as a helicopter does
            case (_x isKindOf "Plane"): {false};
            case (_x isKindOf "Air"): {true};
            case (_x isKindOf "Ship"): {_water && {surfaceIsWater getPosATL _x} && {_onOwnLand}};
            default {!_crossing && {_onOwnLand} && {!_water || {_way >= BR_var_aiRideMinDistance}}};
        };

        // on the way: walking there and driving on must not be much longer than the way itself (a car behind the
        // unit led it out of the zone); a crossing takes any boat or helicopter in reach
        if (
            _distance < _nearestDistance &&
            {_suitable} &&
            {_crossing ||
                {_distance +(_x distance2D _destination) <= _way +(BR_var_aiVehicleDetourMin max (_way *
                BR_var_aiVehicleDetourShare))}} &&
            {[_unit, _x] call BR_fnc_aiVehicleFree}
        ) then {
            _nearest = _x;
            _nearestDistance = _distance;
        };
    } forEach ((missionNamespace getVariable ["BR_var_vehicles", []]) select {_x distance2D _unit < _searchRadius});

    _nearest
};

// intact, fuelled, unlocked, nobody alive inside, not reserved by another living AI, not left as useless by this one
BR_fnc_aiVehicleFree = {
    params ["_unit", "_vehicle"];

    private _reservedBy = _vehicle getVariable ["BR_var_aiReservedBy", objNull];

    alive _vehicle &&
    {canMove _vehicle} &&
    {fuel _vehicle > BR_var_aiMinFuel} &&
    {locked _vehicle < 2} &&
    {((crew _vehicle) findIf {alive _x}) == -1} &&
    {isNull _reservedBy || {_reservedBy isEqualTo _unit} || {!alive _reservedBy}} &&
    {!(_vehicle getVariable ["BR_var_aiWedged", false])} &&
    {!(_vehicle in (_unit getVariable ["BR_var_aiBadVehicles", []]))}
};

// gives up a vehicle it wanted (gone, taken, not reachable): it is not tried again
BR_fnc_aiDropVehicle = {
    params ["_unit", "_vehicle"];

    if ((_vehicle getVariable ["BR_var_aiReservedBy", objNull]) isEqualTo _unit) then {
        _vehicle setVariable ["BR_var_aiReservedBy", nil];
    };

    _unit setVariable ["BR_var_aiBadVehicles", (_unit getVariable ["BR_var_aiBadVehicles", []]) + [_vehicle]];
    _unit setVariable ["BR_var_aiRideVehicle", objNull];
    _unit setVariable ["BR_var_aiToVehicleProgress", nil];
};

/*
    Into the driver's seat (scripted: renegades cannot board a vehicle with another renegade in it); team mates close by
    join the driver's group for the ride and get in too. Then off to _destination.
*/
BR_fnc_aiBoard = {
    params ["_unit", "_vehicle", "_destination"];

    _unit setVariable ["BR_var_aiRideVehicle", objNull];
    _unit setVariable ["BR_var_aiToVehicleProgress", nil];
    _vehicle enableSimulationGlobal true;      // far from everyone it was not simulated (BR_fnc_vehicleLodLoop)
    _unit forceSpeed -1;                        // the running pace of the travel mode would also slow the vehicle
    _unit moveInDriver _vehicle;

    if ((driver _vehicle) isNotEqualTo _unit) exitWith {
        [_unit, _vehicle] call BR_fnc_aiDropVehicle;
    };

    {
        if (
            alive _x &&
            {!isPlayer _x} &&
            {isNull objectParent _x} &&
            {_x distance _unit < BR_var_aiRideMateDistance} &&
            {isNull (_x getVariable ["BR_var_aiLootBuilding", objNull])}
        ) then {
            [_x] joinSilent (group _unit);

            if (!(_x moveInAny _vehicle)) then {
                [_x] call BR_fnc_aiOwnGroup;
            };
        };
    } forEach (([_unit getVariable ["BR_var_teamId", -1]] call BR_fnc_teamUnits) - [_unit]);

    if (_vehicle isKindOf "Air") then {
        _vehicle flyInHeight BR_var_aiHeliHeight;
    };

    // straight on: no stops for enemies seen on the way (AWARE drives slowly and halts); normal speed (full speed
    // crashed cars and killed their crews)
    (group _unit) setBehaviourStrong "CARELESS";
    (group _unit) setSpeedMode "NORMAL";

    _unit setVariable ["BR_var_aiRideTarget", []];
    _unit setVariable ["BR_var_aiRideSince", time];
    _unit setVariable ["BR_var_aiRideProgressPos", getPosATL _vehicle];
    _unit setVariable ["BR_var_aiRideProgressTime", time];
    _unit setVariable ["BR_var_aiRideRetries", 0];
    [_unit, _vehicle, _destination] call BR_fnc_aiRideOrder;
};

/*
    An AI in a vehicle. A passenger rides while a team mate drives. The driver goes for its zone destination and gets
    everyone out on arrival or when the vehicle is broken or stuck; a helicopter lands first,
    a fast car stops first.
*/
BR_fnc_aiRideTick = {
    params ["_unit"];

    private _vehicle = objectParent _unit;

    if (_vehicle isKindOf "ParachuteBase") exitWith {};

    private _driver = driver _vehicle;

    if (_driver isNotEqualTo _unit) exitWith {
        if (
            !alive _driver ||
            {_driver getVariable ["ais_unconscious", false]} ||
            {isPlayer _driver} ||
            {!([_driver, _unit] call BR_fnc_isTeammate)}
        ) then {
            [_unit] call BR_fnc_aiLeaveVehicle;
        };
    };

    private _destination = [_unit] call BR_fnc_aiZoneDestination;
    private _air = _vehicle isKindOf "Air";
    // a boat ends its ride at the shore of the destination's landmass, the rest is on foot
    private _arrival = if (_vehicle isKindOf "Ship") then {[_unit, _vehicle, _destination] call BR_fnc_aiLandingPoint} else {_destination};
    // A healthy ride can take longer across the island. End it for arrival or actual failure, not elapsed time.
    private _reason = switch (true) do {
        // shot at (BR_fnc_aiThreat): out and fight
        case (!isNull (_vehicle getVariable ["BR_var_aiAttackedBy", objNull])): {"attacked"};
        case (!canMove _vehicle || {fuel _vehicle <= 0} || {damage _vehicle > BR_var_aiRideMaxDamage}): {"broken"};
        case (_unit distance2D _arrival < ([BR_var_aiRideArriveDistance, BR_var_aiHeliArriveDistance] select _air)): {"arrived"};
        // stuck close to the destination (its last leg ends off the road, a boat runs aground): close enough
        case ((!_air || {isTouchingGround _vehicle}) && {[_unit, _vehicle] call BR_fnc_aiRideStuck}): {
            ["stuck", "arrived"] select (_unit distance2D _arrival < BR_var_aiRideNearDistance)
        };
        default {""};
    };

    if (_reason == "") exitWith {
        [_unit, _vehicle, _destination] call BR_fnc_aiRideOrder;
    };

    if (_air && {!isTouchingGround _vehicle}) exitWith {
        if !(_vehicle getVariable ["BR_var_aiLanding", false]) then {
            _vehicle setVariable ["BR_var_aiLanding", true];
            _vehicle land "LAND";
        };
    };

    if (speed _vehicle > BR_var_aiRideExitSpeed) exitWith {
        doStop _unit;
    };

    [_unit, _vehicle, _reason] call BR_fnc_aiEndRide;
};

// the driver's move order: a helicopter flies straight to the destination, a car or boat drives in legs (the engine
// plans no way over kilometres, BR_fnc_aiLegTarget), the next one once it is close to the end of the current one
BR_fnc_aiRideOrder = {
    params ["_unit", "_vehicle", "_destination"];

    private _leg = _unit getVariable ["BR_var_aiRideLeg", []];
    // Retrying the same unreachable waypoint cannot free a stuck driver. Shorter legs let the engine
    // plan a different local route; normal leg length resumes once the vehicle makes progress.
    private _retryScale = 1 + (_unit getVariable ["BR_var_aiRideRetries", 0]);

    if (
        (_unit getVariable ["BR_var_aiRideTarget", []]) isEqualTo _destination &&
        {_leg isEqualTo [] || {_vehicle distance2D _leg > BR_var_aiRideLegReach}}
    ) exitWith {};

    // a car drives to a free spot at the destination (not into a house or onto rocks), a boat to its landing point
    private _goal = if (_vehicle isKindOf "Ship") then {[_unit, _vehicle, _destination] call BR_fnc_aiLandingPoint} else {_destination};

    if (_vehicle isKindOf "LandVehicle") then {
        private _spot = _destination findEmptyPosition [0, BR_var_aiRideSpotSearch, typeOf _vehicle];

        if (_spot isNotEqualTo []) then {
            _goal = [_spot] call BR_fnc_groundPos;
        };
    };

    private _target = if (_vehicle isKindOf "Air") then {_goal} else {
        [_vehicle, _goal, BR_var_aiRideLegLength / _retryScale, _vehicle isKindOf "Ship"] call BR_fnc_aiLegTarget
    };

    if (_vehicle isKindOf "LandVehicle") then {
        if (_target isNotEqualTo _goal) then {
            // a leg on the way ends on a road: the driver finds no way to a point in the fields and does not start
            private _roads = _target nearRoads BR_var_aiRideRoadSnap;

            if (_roads isNotEqualTo []) then {
                private _distances = _roads apply {_x distance2D _target};

                _target = [getPosATL (_roads select (_distances find (selectMin _distances)))] call BR_fnc_groundPos;
            };
        } else {
            // the last way: off the road in short legs to the spot itself (they stopped on the road 160-650 m short)
            _target = [_vehicle, _goal, BR_var_aiRideOffroadLeg / _retryScale] call BR_fnc_aiLegTarget;
        };
    };

    _unit setVariable ["BR_var_aiRideTarget", _destination];
    _unit setVariable ["BR_var_aiRideLeg", [_target, []] select (_target isEqualTo _goal)];
    _unit doMove _target;
};

// true if the vehicle moved less than BR_var_aiRideStuckDistance for a while
BR_fnc_aiRideStuck = {
    params ["_unit", "_vehicle"];

    if (_vehicle distance2D (_unit getVariable ["BR_var_aiRideProgressPos", [0, 0, 0]]) > BR_var_aiRideStuckDistance) exitWith {
        _unit setVariable ["BR_var_aiRideProgressPos", getPosATL _vehicle];
        _unit setVariable ["BR_var_aiRideProgressTime", time];
        _unit setVariable ["BR_var_aiRideRetries", 0];
        false
    };

    if (time - (_unit getVariable ["BR_var_aiRideProgressTime", time]) <= BR_var_aiRideStuckTime * ([1, 2] select (_vehicle isKindOf "Air"))) exitWith {false};

    // first a new order to the next leg (half the stuck cars never started: no way to their first target)
    private _retries = _unit getVariable ["BR_var_aiRideRetries", 0];

    if (_retries < BR_var_aiRideRetryCount) exitWith {
        _unit setVariable ["BR_var_aiRideRetries", _retries + 1];
        _unit setVariable ["BR_var_aiRideProgressTime", time];
        _unit setVariable ["BR_var_aiRideTarget", []];
        _unit setVariable ["BR_var_aiRideLeg", []];
        false
    };

    true
};

// everyone of the team out, passengers first; a broken or stuck vehicle is not taken by this driver again
BR_fnc_aiEndRide = {
    params ["_unit", "_vehicle", "_reason"];

    (group _unit) leaveVehicle _vehicle;

    private _attacker = _vehicle getVariable ["BR_var_aiAttackedBy", objNull];

    {
        if (alive _x && {!isPlayer _x}) then {
            [_x] call BR_fnc_aiLeaveVehicle;

            // attacked: everyone fights the attacker (BR_fnc_aiEngage) - not just the one he hit
            if (!isNull _attacker) then {
                _x setVariable ["BR_var_aiThreat", _attacker];
                _x setVariable ["BR_var_aiThreatUntil", time + BR_var_aiThreatTime];
                _x setVariable ["BR_var_aiNextTick", 0];
            };
        };
    } forEach (((crew _vehicle) - [_unit]) + [_unit]);

    _vehicle setVariable ["BR_var_aiAttackedBy", nil];

    if !(_reason in ["arrived", "attacked"]) then {
        _unit setVariable ["BR_var_aiBadVehicles", (_unit getVariable ["BR_var_aiBadVehicles", []]) + [_vehicle]];
    };

    // stuck right at the start: wedged in (no AI gets it going), nobody tries it again
    if (_reason == "stuck" && {time - (_unit getVariable ["BR_var_aiRideSince", time]) < BR_var_aiRideStuckTime * (2 + BR_var_aiRideRetryCount)}) then {
        _vehicle setVariable ["BR_var_aiWedged", true];
    };

    // on foot the travel mode sets the group's behaviour again (BR_fnc_aiSetTravelMode)
    (group _unit) setBehaviour "AWARE";
    _unit setVariable ["BR_var_aiTravelMode", nil];
    _vehicle setVariable ["BR_var_aiReservedBy", nil];
    _vehicle setVariable ["BR_var_aiLanding", nil];
};

// on foot again: unassigned (it does not get back in by itself), in an own group again, the next move order at once
BR_fnc_aiLeaveVehicle = {
    params ["_unit"];

    unassignVehicle _unit;
    moveOut _unit;

    if ((count units group _unit) > 1 || {(leader group _unit) isNotEqualTo _unit}) then {
        [_unit] call BR_fnc_aiOwnGroup;
    };

    _unit setVariable ["BR_var_aiDestination", []];
};
