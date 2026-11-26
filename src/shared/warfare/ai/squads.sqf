// AI squads: the AI of one SC group form fire teams of 1 - 2 AI (engine groups of AI only, SC\groups.sqf and
// SC\ai\fireTeams.sqf; in this file "squad" is such an engine group). Every fire team runs a small state machine that
// brings it to the objective of its SC group (SC\ai\objectives.sqf) on foot or by vehicle and lets it fight for the
// sector there (server). States: IDLE (no objective), MOVE (on foot), BOARD (getting into the squad vehicle), TRAVEL
// (driving / flying), FIGHT (in the sector: capture or defend), REPAIR (of the squad vehicle), RIDE (with a player as
// driver), CHAUFFEUR (driving players of the SC group). Only this file and fireTeams.sqf give AI squads orders.

// ---- tuning ----

// estimated travel speeds (m/s) of the objective planning
SC_var_aiFootSpeed = 3;
SC_var_aiVehicleSpeed = 10;

// a squad within this distance (m) of its sector's edge fights for the sector
SC_var_aiFightMargin = 30;

// in a fight, the squad moves to a new point of the sector after this time (seconds) or when it reached the point
SC_var_aiFightMoveTime = 90;

// a squad member that falls this far (m) behind its travelling squad is brought back by a respawn at the squad
// (only when no player sees it; not the members that stayed behind at the boarding, they follow on foot)
SC_var_aiStragglerDistance = 400;

// a squad of this size counts as full: smaller ones prefer defending and close objectives, the commander's demand
// of an objective is counted in full squads, bigger squads also take a vehicle with only this many seats
SC_var_aiFullSquadSize = 4;

// players closer than this (m) see an AI unit; it is then never suspended or moved by a script
SC_var_aiSeenDistance = 500;

// [behaviour, combat mode, speed, formation] while travelling, when approaching the sector, when enemies are close on
// the way, in the sector
SC_var_aiStanceTravel = ["AWARE", "YELLOW", "FULL", "STAG COLUMN"];
SC_var_aiStanceApproach = ["AWARE", "RED", "FULL", "LINE"];
SC_var_aiStanceCloseFight = ["COMBAT", "RED", "FULL", "WEDGE"];
SC_var_aiStanceFight = ["COMBAT", "RED", "NORMAL", "LINE"];

// on the way a squad only fights (COMBAT behaviour) when a known enemy is this close (m): a squad in COMBAT moves
// about half as fast (bounding), so on its own it would crawl to the sector after every contact
SC_var_aiCloseFightDistance = 150;

// ---- distances from the sector layout ----

// The distances of the AI follow the running map: the typical sector spacing (median distance from a sector to its
// nearest neighbour) times a factor, clamped to sensible limits ([factor, min, max] below).

// objectives further away than this (from the sector's edge) are reached by vehicle (on a map with closely spaced
// sectors already a neighbouring sector, if the squad's vehicle or a free one is near)
SC_var_aiVehicleUseScale = [0.8, 200, 700];

// ... if the vehicle is at most this far away (a squad's vehicle is kept up to twice this distance)
SC_var_aiVehicleWalkScale = [0.5, 60, 400];

// ground vehicles unload this far from the sector's edge, helicopters land this far from it
SC_var_aiDismountScale = [0.3, 40, 250];
SC_var_aiLandingScale = [0.6, 150, 400];

// a squad on foot this far from its objective without a vehicle is sent back to the front by a respawn (only unseen)
SC_var_aiRedeployScale = [1, 1500, 3000];

SC_fnc_aiScaledDistance = {
    params ["_scale"];
    _scale params ["_factor", "_min", "_max"];

    _min max (_max min (_factor * SC_var_aiSectorSpacing))
};

// server, once per round: the sector spacing and the distances that follow from it
SC_fnc_aiInitTuning = {
    private _centers = SC_var_sectors apply {getMarkerPos ("SC_var_sector" + _x)};
    private _nearest = [];

    {
        private _center = _x;
        _nearest pushBack (selectMin (((_centers select {_x isNotEqualTo _center}) apply {_x distance2D _center}) + [1e9]));
    } forEach _centers;

    _nearest sort true;
    SC_var_aiSectorSpacing = if ((count _centers) < 2) then {500} else {_nearest select (floor ((count _nearest) / 2))};

    SC_var_aiVehicleUseDistance = [SC_var_aiVehicleUseScale] call SC_fnc_aiScaledDistance;
    SC_var_aiVehicleWalkDistance = [SC_var_aiVehicleWalkScale] call SC_fnc_aiScaledDistance;
    SC_var_aiDismountDistance = [SC_var_aiDismountScale] call SC_fnc_aiScaledDistance;
    SC_var_aiLandingDistance = [SC_var_aiLandingScale] call SC_fnc_aiScaledDistance;
    SC_var_aiRedeployDistance = [SC_var_aiRedeployScale] call SC_fnc_aiScaledDistance;
    SC_var_aiApproachDistance = [SC_var_aiApproachScale] call SC_fnc_aiScaledDistance;

    [
        "tuning", grpNull, round SC_var_aiSectorSpacing, SC_var_aiVehicleUseDistance, SC_var_aiVehicleWalkDistance,
        SC_var_aiDismountDistance, SC_var_aiLandingDistance, SC_var_aiRedeployDistance
    ] call SC_fnc_aiLog;
};

// ---- orders ----

SC_fnc_aiSetState = {
    params ["_group", "_state", ["_reason", ""]];

    private _oldState = _group getVariable ["SC_var_aiState", ""];

    if (_oldState == _state) exitWith {};

    _group setVariable ["SC_var_aiState", _state];
    _group setVariable ["SC_var_aiStateTime", time];
    ["state", _group, _oldState, _state, _reason] call SC_fnc_aiLog;
};

SC_fnc_aiClearWaypoints = {
    params ["_group"];

    for "_i" from ((count (waypoints _group)) - 1) to 1 step -1 do {
        deleteWaypoint [_group, _i];
    };

    _group setVariable ["SC_var_aiWaypoint", []];
};

// the squad's only waypoint (index 1, waypoint 0 is the engine's start waypoint); the same order isn't given twice
// while it is still running, unless _force (a new path after getting stuck). A completed waypoint (the squad stands
// at it, or the engine dropped it) is given again, so a squad never stands idle without an order (its time stays).
SC_fnc_aiSetWaypoint = {
    params ["_group", "_pos", ["_type", "MOVE"], ["_force", false]];

    private _lastWaypoint = _group getVariable ["SC_var_aiWaypoint", []];
    private _same =(_lastWaypoint isNotEqualTo []) && {((_lastWaypoint select 0) distance2D _pos) < 10} &&
        {(_lastWaypoint select 1) == _type};

    if (!_force && {_same} && {(currentWaypoint _group) < (count (waypoints _group))}) exitWith {};

    [_group] call SC_fnc_aiClearWaypoints;

    private _waypoint = _group addWaypoint [_pos, 0];
    _waypoint setWaypointType _type;
    _waypoint setWaypointCompletionRadius ([15, 40] select !(isNull (objectParent (leader _group))));
    _group setCurrentWaypoint _waypoint;
    _group setVariable ["SC_var_aiWaypoint", [_pos, _type, [time, _lastWaypoint param [2, time]] select (_same && {!_force})]];
};

// [behaviour, combat mode, speed, formation] of the squad; only set when it changes, so the engine's own switch to
// COMBAT when the squad meets enemies stays - except with _enforce (travelling: AUTOCOMBAT is off then, a COMBAT
// behaviour comes from scripts, e.g. the one of a vehicle spawn). Enforcing also checks every unit's own behaviour: a
// unit keeps a COMBAT of its last fight although the group's is AWARE, and a driver in COMBAT stops the vehicle.
SC_fnc_aiSetStance = {
    params ["_group", "_stance", ["_enforce", false]];

    _stance params ["_behaviour", "_combatMode", "_speed", "_formation"];

    if (
        ((_group getVariable ["SC_var_aiStance", []]) isEqualTo _stance) &&
        {!_enforce || {((combatBehaviour _group) == _behaviour) && {((units _group) findIf {(combatBehaviour _x) != _behaviour}) == -1}}}
    ) exitWith {};

    _group setCombatBehaviour _behaviour;

    if _enforce then {
        {
            if ((combatBehaviour _x) != _behaviour) then {
                _x setCombatBehaviour _behaviour;
            };
        } forEach (units _group);
    };

    _group setCombatMode _combatMode;
    _group setSpeedMode _speed;
    _group setFormation _formation;
    _group setVariable ["SC_var_aiStance", _stance];
};

// on the way to the sector the squad doesn't switch to COMBAT on its own (that stops vehicles and halves the pace on
// foot); the squad logic sets the behaviour instead
SC_fnc_aiSetAutoCombat = {
    params ["_units", "_enabled"];

    {
        if ((_x checkAIFeature "AUTOCOMBAT") != _enabled) then {
            if _enabled then {
                _x enableAI "AUTOCOMBAT";
            } else {
                _x disableAI "AUTOCOMBAT";
            };
        };
    } forEach _units;
};

// random land position in a sector, at most _fraction of its radius from the center
SC_fnc_aiRandomSectorPos = {
    params ["_sectorInd", "_fraction"];

    (SC_var_aiSectorInfo get _sectorInd) params ["_center", "_radius"];

    private _marker = "SC_var_sector" + _sectorInd;
    private _pos = _center;

    for "_i" from 1 to 10 do {
        private _candidate = _center getPos [_radius * _fraction * (sqrt (random 1)), random 360];

        if (!(surfaceIsWater _candidate) && {_candidate inArea _marker}) exitWith {
            _pos = _candidate;
        };
    };

    _pos
};

// ---- squad ----

// the leader has to be able to act: an unconscious leader is replaced (by the squad's driver if there is one)
SC_fnc_aiEnsureLeader = {
    params ["_group", "_able", "_vehicle"];

    private _leader = leader _group;

    if (_leader in _able) exitWith {_leader};

    private _driver = driver _vehicle;
    _leader = [_able select 0, _driver] select (_driver in _able);
    _group selectLeader _leader;

    _leader
};

// an AI rides along in the vehicle of a player of its side (e.g. it spawned in it) as long as the player drives; a stop
// of SC_var_aiRideStopTime seconds ends the ride
SC_var_aiRideStopTime = 30;

SC_fnc_aiKeepsRiding = {
    params ["_unit", "_vehicle"];

    private _driver = driver _vehicle;

    if (!(isPlayer _driver) || {(side (group _driver)) != (side (group _unit))}) exitWith {false};

    (_unit getVariable ["SC_var_aiRideStop", [objNull, time]]) params ["_stopVehicle", "_stopSince"];

    if (((speed _vehicle) > 5) || {_stopVehicle isNotEqualTo _vehicle}) then {
        _stopSince = time;
    };

    _unit setVariable ["SC_var_aiRideStop", [_vehicle, _stopSince]];

    (time - _stopSince) < SC_var_aiRideStopTime
};

// Members in a vehicle that isn't the squad vehicle: a usable vehicle a member drives becomes the squad vehicle if the
// squad has none or nobody sits in it (e.g. a vehicle an AI spawned with), riders of a player stay, the others get
// out (moved out if they are still inside at the next step). Returns the squad vehicle.
SC_fnc_aiCheckOtherVehicles = {
    params ["_group", "_able", "_vehicle"];

    {
        private _parent = objectParent _x;

        if (!(isNull _parent) && {_parent isNotEqualTo _vehicle}) then {
            switch true do {
                case (
                    ((isNull _vehicle) || {(_able findIf {(objectParent _x) isEqualTo _vehicle}) == -1}) &&
                    {(driver _parent) isEqualTo _x} &&
                    {[typeOf _parent, [count _able] call SC_fnc_aiSeatsNeeded] call SC_fnc_aiIsSquadVehicleType} &&
                    {[_parent, _group] call SC_fnc_aiIsVehicleUsable} &&
                    {!([_parent, _group] call SC_fnc_aiIsReservedByOther)}
                ): {
                    if !(isNull _vehicle) then {
                        [_group, _vehicle, "a member drives another one"] call SC_fnc_aiReleaseVehicle;
                    };

                    [_group, _parent, "adopted"] call SC_fnc_aiReserveVehicle;
                    _vehicle = _parent;
                };
                case ([_x, _parent] call SC_fnc_aiKeepsRiding): {};

                // a member drives players of the SC group (SC_fnc_aiDoChauffeur), its fire team rides along
                case ([driver _parent] call SC_fnc_aiIsChauffeur): {};

                // out of a flying aircraft only after it landed
                case ((_parent isKindOf "Air") && {!(isTouchingGround _parent)}): {};
                default {
                    if ((_x getVariable ["SC_var_aiOrderedOut", objNull]) isEqualTo _parent) then {
                        moveOut _x;
                    } else {
                        ["dismount", _group, typeOf _parent, 1, "not the squad vehicle"] call SC_fnc_aiLog;
                        _x setVariable ["SC_var_aiOrderedOut", _parent];
                    };

                    if (_parent in (assignedVehicles _group)) then {
                        _group leaveVehicle _parent;
                    };

                    unassignVehicle _x;
                    [_x] orderGetIn false;
                    doGetOut _x;
                };
            };
        };
    } forEach _able;

    _vehicle
};

// destination of a travelling vehicle (kept per objective and vehicle): ground vehicles stop
// SC_var_aiDismountDistance before the sector on the side they come from, on a road there (SC_fnc_aiRoadNear),
// helicopters land at a free flat place SC_var_aiLandingDistance before it. A vehicle stuck on its way gets a new
// destination turned to one side (SC_var_aiDestinationTurn, set by SC_fnc_aiCheckStuck).
SC_fnc_aiGetTravelDestination = {
    params ["_group", "_vehicle", "_target"];

    (_group getVariable ["SC_var_aiDestination", []]) params [["_destinationTarget", ""], ["_destinationVehicle", objNull], ["_destination", []], ["_destinationHarbor", -1]];

    private _harbor = _group getVariable ["SC_var_aiHarbor", -1];

    if((_destinationTarget == _target) && {_destinationVehicle isEqualTo _vehicle} &&
        {_destinationHarbor == _harbor}) exitWith {_destination};

    (SC_var_aiSectorInfo get _target) params ["_center", "_radius"];

    private _direction = (_center getDir _vehicle) + (_group getVariable ["SC_var_aiDestinationTurn", 0]);
    _group setVariable ["SC_var_aiDestinationTurn", nil];

    switch (true) do {
        // a boat: to a landing point at the objective's coast or to a harbour there (SC_fnc_aiBoatDestination)
        case (_vehicle isKindOf "Ship"): {
            ([_target, getPosWorld _vehicle] call SC_fnc_aiBoatDestination) params ["_boatDestination", "_harborName"];
            _destination = _boatDestination;
            ["vehicle", _group, typeOf _vehicle, "sails to", ["the coast", _harborName] select (_harborName != ""), _target] call SC_fnc_aiLog;
        };
        // a land vehicle of a squad that needs a boat: to the harbour
        case ((_harbor != -1) && {!(_vehicle isKindOf "Air")}): {
            private _shopPos = getPosWorld ((SC_var_harbors select _harbor) select 1);

            _destination = [_shopPos, _shopPos, 0] call SC_fnc_aiRoadNear;
        };
        case (_vehicle isKindOf "Air"): {
            private _approach = _center getPos [_radius + SC_var_aiLandingDistance, _direction];
            _destination = [_approach, 0, 200, 15, 0, 0.2, 0, [], [_approach, _approach]] call BIS_fnc_findSafePos;
            _destination = [_destination select 0, _destination select 1, 0];
        };
        default {
            _destination = _center getPos [_radius + (0.8 * SC_var_aiDismountDistance), _direction];
            _destination = [_destination, _center, _radius] call SC_fnc_aiRoadNear;

            if (surfaceIsWater _destination) then {
                _destination = _center;
            };
        };
    };
    _group setVariable ["SC_var_aiDestination", [_target, _vehicle, _destination, _harbor]];

    _destination
};

// The engine's route planning of a vehicle often finds no way to a point in a forest, on a slope or below a cliff (the
// driver then never starts, "DoNotPlan"), but always one to a road: the road nearest to _pos within
// SC_var_aiDismountRoadRadius m that isn't closer than half the radius to the sector's center (_pos if there is none).
SC_var_aiDismountRoadRadius = 300;

SC_fnc_aiRoadNear = {
    params ["_pos", "_center", "_radius"];

    private _roads = (_pos nearRoads SC_var_aiDismountRoadRadius) select {
        private _roadPos = getPosATL _x;
        !(surfaceIsWater _roadPos) && {(_roadPos distance2D _center) > (0.5 * _radius)}
    };

    if (_roads isEqualTo []) exitWith {_pos};

    private _distances = _roads apply {_x distance2D _pos};
    private _roadPos = getPosATL (_roads select (_distances find (selectMin _distances)));

    [_roadPos select 0, _roadPos select 1, 0]
};

// whether a position is at a spawn point of the side (its base, the middle of an own sector): AI spawn there
SC_fnc_aiAtSpawnPoint = {
    params ["_pos", "_side"];

    ((_pos distance2D (getMarkerPos ("SC_var_" + (toLower (str _side)) + "Respawn"))) < 150) ||
    {(SC_var_sectors findIf {((missionNamespace getVariable ("SC_var_owner" + _x)) == _side) &&
        {(_pos distance2D (getMarkerPos ("SC_var_sector" + _x))) < 100}}) != -1} ||
    {((missionNamespace getVariable ["SC_var_harbors", []]) findIf {
        ((_pos distance2D (_x select 2)) < 150) || {((_x param [4, []]) isNotEqualTo []) && {(_pos distance2D (_x select 4)) < 150}}
    }) != -1}
};

// A squad whose vehicle stands at a spawn point of its side waits up to SC_var_aiGatherTime seconds (from when it has the
// vehicle there) before it departs, while it has free seats and AI of its side on foot without a vehicle are within
// SC_var_aiGatherRadius: they ride along (SC_fnc_aiJoinRide) instead of walking to the front (no enemy close).
SC_var_aiGatherTime = 45;
SC_var_aiGatherRadius = 200;

SC_fnc_aiGathers = {
    params ["_group", "_vehicle", "_enemyDistance"];

    private _side = side _group;
    (_group getVariable ["SC_var_aiGather", []]) params [["_gatherVehicle", objNull], ["_since", 0]];

    if (_gatherVehicle isNotEqualTo _vehicle) then {
        _since = time;
        _group setVariable ["SC_var_aiGather", [_vehicle, _since]];
    };

    ((time - _since) < SC_var_aiGatherTime) &&
    {_enemyDistance > 300} &&
    {[getPosWorld _vehicle, _side] call SC_fnc_aiAtSpawnPoint} &&
    {((fullCrew [_vehicle, "", true]) findIf {isNull (_x select 0)}) != -1} &&
    {
        ((_vehicle nearEntities ["CAManBase", SC_var_aiGatherRadius]) findIf {
            (alive _x) &&
            {simulationEnabled _x} &&
            {!(isPlayer _x)} &&
            {isNull (objectParent _x)} &&
            {(side (group _x)) == _side} &&
            {(group _x) isNotEqualTo _group} &&
            {isNull ((group _x) getVariable ["SC_var_aiVehicle", objNull])} &&
            {((group _x) getVariable ["SC_var_aiDelivery", []]) isEqualTo []}
        }) != -1
    }
};

// Decision of a squad: fight in the sector, travel in the squad vehicle, board it or walk. Vehicles are used for long
// distances only and not in a fight unless they are right there; travellers unload at the dismount distance (an
// unarmed vehicle under fire earlier), helicopters when they landed.
SC_fnc_aiChooseMode = {
    params ["_group", "_vehicle", "_able", "_inside", "_distance", "_enemyDistance"];

    private _state = _group getVariable ["SC_var_aiState", ""];

    // a helicopter is left only after it landed (SC_fnc_aiDoTravel lands it at the landing zone)
    if (
        (_state == "TRAVEL") &&
        {_vehicle isKindOf "Air"} &&
        {_inside isNotEqualTo []} &&
        {((_group getVariable ["SC_var_aiLanding", -1]) < 0) || {!(isTouchingGround _vehicle)} || {(speed _vehicle) > 5}}
    ) exitWith {"TRAVEL"};

    if (_distance <= SC_var_aiFightMargin) exitWith {"FIGHT"};

    if !(isNull _vehicle) then {
        private _leader = leader _group;
        private _boarders = _able - (_group getVariable ["SC_var_aiLeftBehind", []]);
        private _allInside = (_boarders findIf {!(_x in _inside)}) == -1;
        private _isAir = _vehicle isKindOf "Air";

        // a landed helicopter: everybody out
        if ((_state == "TRAVEL") && _isAir) exitWith {"MOVE"};

        // (arrived: the vehicle stands at its dismount point, which can be a bit further out than the dismount distance)
        if ((_state == "TRAVEL") && {!_isAir}) exitWith {
            private _unloadEarly =(_enemyDistance < 200) && {_distance <(3 * SC_var_aiDismountDistance)} &&
                {!([_vehicle] call SC_fnc_aiIsArmed)};
            private _destination = (_group getVariable ["SC_var_aiDestination", []]) param [2, []];
            private _arrived = (_destination isNotEqualTo []) && {(_vehicle distance2D _destination) < 50} && {(abs (speed _vehicle)) < 3};

            // a boat sails on to its landing point, a land vehicle of a squad that needs a boat to the harbour
            private _ownDestination = (_vehicle isKindOf "Ship") || {(_group getVariable ["SC_var_aiHarbor", -1]) != -1};

            ["MOVE", "TRAVEL"] select (
                ((_distance > SC_var_aiDismountDistance) || _ownDestination) &&
                {!_unloadEarly || _ownDestination} &&
                {!_arrived} &&
                {(driver _vehicle) in _inside}
            )
        };

        // boarding goes on until everybody is in (or the boarding timed out), then the squad travels; it doesn't start
        // while a member helps an unconscious unit (AIS revive)
        private _reachable = (_leader distance _vehicle) < SC_var_aiVehicleWalkDistance;
        private _wantsVehicle = (_distance > ([SC_var_aiVehicleUseDistance, SC_var_aiDismountDistance] select (_state == "BOARD"))) &&
            {(_enemyDistance > 150) || {(_leader distance _vehicle) < 40}} &&
            {(_state == "BOARD") || {(_able findIf {!(isNull (_x getVariable ["AIS_isHelper", objNull]))}) == -1}};

        if (_wantsVehicle && {_reachable || {_inside isNotEqualTo []}}) exitWith {
            ["BOARD", "TRAVEL"] select (
                _allInside &&
                {(driver _vehicle) in _inside} &&
                {(_state == "TRAVEL") || {!([_group, _vehicle, _enemyDistance] call SC_fnc_aiGathers)}}
            )
        };

        "MOVE"
    } else {
        "MOVE"
    }
};

// MOVE: on foot to a point in the sector, travel stance far away, approach stance when close, combat only with
// enemies close by
SC_fnc_aiDoMove = {
    params ["_group", "_target", "_distance", "_enemyDistance"];

    private _targetPos = _group getVariable ["SC_var_aiTargetPos", []];

    if (_targetPos isEqualTo []) then {
        _targetPos = [_target, 0.5] call SC_fnc_aiRandomSectorPos;
        _group setVariable ["SC_var_aiTargetPos", _targetPos];
    };

    private _stance = switch true do {
        case (_enemyDistance < SC_var_aiCloseFightDistance): {SC_var_aiStanceCloseFight};
        case (_distance > 400): {SC_var_aiStanceTravel};
        default {SC_var_aiStanceApproach};
    };

    // first to the approach point (SC_fnc_aiGetApproachPos), unless the fire team is already closer to the sector
    private _approachPos = [_group, _target] call SC_fnc_aiGetApproachPos;

    if (
        (_approachPos isNotEqualTo []) &&
        {(((leader _group) distance2D _approachPos) < 25) || {_distance < (0.5 * SC_var_aiApproachDistance)}}
    ) then {
        (_group getVariable "SC_var_aiApproach") set [1, []];
        _approachPos = [];
    };

    // a leader on foot that hasn't come SC_var_aiFootStuckDistance m further in SC_var_aiFootStuckTime seconds (a path
    // that doesn't work, e.g. blocked in a town) gets a new point in the sector and goes there directly
    private _leaderPos = getPosWorld (leader _group);
    (_group getVariable ["SC_var_aiFootCheck", [time, _leaderPos]]) params ["_checkTime", "_checkPos"];
    private _force = false;

    if ((_leaderPos distance2D _checkPos) > SC_var_aiFootStuckDistance) then {
        _group setVariable ["SC_var_aiFootCheck", [time, _leaderPos]];
        _group setVariable ["SC_var_aiFootStuckCount", 0];
    } else {
        if (isNil {_group getVariable "SC_var_aiFootCheck"}) then {
            _group setVariable ["SC_var_aiFootCheck", [time, _leaderPos]];
        };

        if (((time - _checkTime) > SC_var_aiFootStuckTime) && {_enemyDistance > SC_var_aiCloseFightDistance}) then {
            private _stuckLeader = leader _group;
            [
                "stuck", _group, "on foot", round _distance, (getPosWorld _stuckLeader) apply {round _x}, animationState _stuckLeader,
                currentCommand _stuckLeader, typeOf (assignedVehicle _stuckLeader), _stuckLeader checkAIFeature "MOVE",
                _stuckLeader checkAIFeature "PATH", (expectedDestination _stuckLeader) select 1, behaviour _stuckLeader,
                (waypointPosition [_group, currentWaypoint _group]) apply {round _x}, count (waypoints _group)
            ] call SC_fnc_aiLog;
            _targetPos = [_target, 0.5] call SC_fnc_aiRandomSectorPos;
            _group setVariable ["SC_var_aiTargetPos", _targetPos];
            (_group getVariable ["SC_var_aiApproach", [_target, []]]) set [1, []];
            _approachPos = [];
            _force = true;
            _group setVariable ["SC_var_aiFootCheck", [time, _leaderPos]];

            // still stuck after several new paths (e.g. trapped between objects): back into the game by a respawn
            private _stuckCount = (_group getVariable ["SC_var_aiFootStuckCount", 0]) + 1;
            _group setVariable ["SC_var_aiFootStuckCount", _stuckCount];

            if((_stuckCount >= SC_var_aiFootStuckLimit) &&
                {((units _group) findIf {[_x,
                SC_var_aiSeenDistance] call SC_fnc_aiIsSeenByPlayers}) == -1}) then {
                _group setVariable ["SC_var_aiFootStuckCount", 0];

                {
                    [_x, "stuck"] call SC_fnc_suspendUnit;
                } forEach ((units _group) select {!(isPlayer _x)});
            };
        };
    };

    private _destination = [_approachPos, _targetPos] select (_approachPos isEqualTo []);

    // an objective across the water: first to the harbour (SC_fnc_aiBoatHarbor)
    private _harbor = _group getVariable ["SC_var_aiHarbor", -1];

    if (_harbor != -1) then {
        _destination = getPosWorld ((SC_var_harbors select _harbor) select 1);
    };

    // a long walk goes in legs (SC_fnc_aiFootLeg)
    if (((leader _group) distance2D _destination) > (1.25 * SC_var_aiFootLegLength)) then {
        (_group getVariable ["SC_var_aiFootLeg", []]) params [["_legGoal", []], ["_legPos", []]];

        if (
            _force ||
            {_legPos isEqualTo []} ||
            {(_legGoal distance2D _destination) > 50} ||
            {((leader _group) distance2D _legPos) < SC_var_aiFootLegReach}
        ) then {
            _legPos = [_leaderPos, _destination, _force] call SC_fnc_aiFootLeg;
            _group setVariable ["SC_var_aiFootLeg", [_destination, _legPos]];
        };

        _destination = _legPos;
    };

    [_group, _destination, "MOVE", _force] call SC_fnc_aiSetWaypoint;
    [_group, _stance, true] call SC_fnc_aiSetStance;
    [units _group, false] call SC_fnc_aiSetAutoCombat;
};

// The engine's path planning of a man fails on some routes of several km (the leader then stands with his waypoint
// done, "DoNotPlan"), so a walk farther than 1.25 legs goes in legs of SC_var_aiFootLegLength m towards the destination;
// the next leg is given SC_var_aiFootLegReach m before the end of the current one.
SC_var_aiFootLegLength = 800;
SC_var_aiFootLegReach = 120;

// end of the next leg from _from towards _to: on land, straight or turned a bit (a turn at random after getting stuck)
SC_fnc_aiFootLeg = {
    params ["_from", "_to", ["_turn", false]];

    private _direction = _from getDir _to;
    private _turns = if _turn then {[selectRandom [-35, 35], selectRandom [-70, 70], 0]} else {[0, -25, 25, -50, 50]};
    private _leg = [];

    {
        private _turnAngle = _x;

        {
            private _candidate = _from getPos [SC_var_aiFootLegLength * _x, _direction + _turnAngle];

            if !(surfaceIsWater _candidate) exitWith {
                _leg = _candidate;
            };
        } forEach [1, 0.7, 0.45];

        if (_leg isNotEqualTo []) exitWith {};
    } forEach _turns;

    [_leg, _to] select (_leg isEqualTo [])
};

// a squad on foot (MOVE) that came less than this far (m) in this time (s) out of a fight gets a new path
SC_var_aiFootStuckDistance = 5;
SC_var_aiFootStuckTime = 45;

// ... and one that is still stuck after this many new paths is brought back by a respawn (only unseen)
SC_var_aiFootStuckLimit = 4;

// BOARD: seats for the members outside, the squad waits (the leader drives to the others if they are far away). When
// the boarding takes too long, members close to the vehicle that still aren't in (blocked path, bad seat) take any
// free seat (only unseen), the others stay behind; a squad without a driver then gets one from the passengers.
// _boardState: the squad's state while boarding (a delivery of a spawn vehicle boards in its own state).
SC_var_aiBoardBaseTime = 20;     // s of a boarding besides the walk to the vehicle
SC_var_aiBoardWalkSpeed = 2;     // m/s of the walk to the vehicle (with the way around obstacles)

SC_fnc_aiDoBoard = {
    params ["_group", "_vehicle", "_able", "_inside", ["_boardState", "BOARD"]];

    // A boarding starts when the squad enters the boarding state or boards another vehicle (a squad can stay in BOARD
    // while it changes the vehicle): seats are assigned, members without a seat (a squad bigger than the vehicle) stay
    // behind and follow on foot, and the boarding deadline is set from the walk of the farthest member then (it must
    // not shrink while the members come closer). A squad of which nobody gets a seat (all taken) gives the vehicle up.
    (_group getVariable ["SC_var_aiBoarding", []]) params [["_boardingVehicle", objNull], ["_boardingDeadline", 0], ["_timed", []]];

    if (((_group getVariable ["SC_var_aiState", ""]) != _boardState) || {_boardingVehicle isNotEqualTo _vehicle}) then {
        _group setVariable ["SC_var_aiLeftBehind", [_group, _vehicle, _able] call SC_fnc_aiAssignSeats];
        _boardingDeadline = time + SC_var_aiBoardBaseTime +((selectMax ([0] +((_able -[driver _vehicle])
            apply {_x distance _vehicle}))) / SC_var_aiBoardWalkSpeed);
        _timed = +_able;
        _group setVariable ["SC_var_aiBoarding", [_vehicle, _boardingDeadline, _timed]];
    };

    if (
        (_boardState == "BOARD") &&
        {_inside isEqualTo []} &&
        {(_able - (_group getVariable ["SC_var_aiLeftBehind", []])) isEqualTo []}
    ) exitWith {
        [_group, _vehicle, "no free seat"] call SC_fnc_aiReleaseVehicle;
        _group setVariable ["SC_var_aiLeftBehind", []];
    };

    private _leftBehind = _group getVariable ["SC_var_aiLeftBehind", []];

    // members inside keep the seat they sit in while the vehicle has a driver (a change of seats gets them out and in
    // again, which can loop)
    if !(isNull (driver _vehicle)) then {
        {
            private _unit = _x;
            private _row = (fullCrew [_vehicle, "", true]) select {(_x select 0) isEqualTo _unit};

            if (_row isNotEqualTo []) then {
                // (gunner and commander seats are turrets for assignedVehicleRole)
                private _role = (_row select 0) select 1;

                if (_role in ["gunner", "commander"]) then {
                    _role = "turret";
                };

                if ((toLower ((assignedVehicleRole _unit) param [0, ""])) != _role) then {
                    [_unit, _vehicle, _row select 0] call SC_fnc_aiAssignSeat;
                };
            };
        } forEach _inside;
    };
    private _outside = (_able - _inside) - _leftBehind;

    // a member whose seat was taken or who was unassigned (e.g. by a player) gets a new seat; members that joined for
    // the ride (SC_fnc_aiJoinRide) get the time for their walk to the vehicle (once)
    if ((_outside findIf {(assignedVehicle _x) isNotEqualTo _vehicle}) != -1) then {
        _leftBehind append ([_group, _vehicle, _outside] call SC_fnc_aiAssignSeats);
        _outside = _outside - _leftBehind;
        _group setVariable ["SC_var_aiLeftBehind", _leftBehind];
    };

    private _newcomers = _outside - _timed;

    if (_newcomers isNotEqualTo []) then {
        _boardingDeadline = _boardingDeadline max (time + SC_var_aiBoardBaseTime +((selectMax (_newcomers apply {
            _x distance _vehicle})) / SC_var_aiBoardWalkSpeed));
        _timed append _newcomers;
        _group setVariable ["SC_var_aiBoarding", [_vehicle, _boardingDeadline, _timed]];
    };

    private _farthest = selectMax ([0] + (_outside apply {_x distance _vehicle}));

    if (time > _boardingDeadline) then {
        {
            if (
                ((_x distance _vehicle) < 40) &&
                {!([_x, SC_var_aiSeenDistance] call SC_fnc_aiIsSeenByPlayers)} &&
                {_x moveInAny _vehicle}
            ) then {
                ["board", _group, typeOf _vehicle, "moved in"] call SC_fnc_aiLog;
            } else {
                _leftBehind pushBack _x;
                unassignVehicle _x;
            };
        } forEach _outside;

        _group setVariable ["SC_var_aiLeftBehind", _leftBehind];

        private _passengers = (_able select {(objectParent _x) isEqualTo _vehicle}) - [driver _vehicle];

        if ((isNull (driver _vehicle)) && {_passengers isNotEqualTo []}) then {
            private _newDriver = _passengers select 0;
            _newDriver assignAsDriver _vehicle;

            if !([_newDriver, SC_var_aiSeenDistance] call SC_fnc_aiIsSeenByPlayers) then {
                moveOut _newDriver;
                _newDriver moveInDriver _vehicle;
            };

            [_newDriver] orderGetIn true;
            ["board", _group, typeOf _vehicle, "new driver"] call SC_fnc_aiLog;
        };
    };

    private _driver = driver _vehicle;

    if ((_driver in _inside) && {_farthest > 150}) then {
        if ((leader _group) isNotEqualTo _driver) then {
            _group selectLeader _driver;
        };

        private _waitingPos = (_outside select 0) getPos [10, 0];
        [_group, _waitingPos] call SC_fnc_aiSetWaypoint;
    } else {
        [_group] call SC_fnc_aiClearWaypoints;
    };

    [_group, SC_var_aiStanceTravel, true] call SC_fnc_aiSetStance;
    [units _group, false] call SC_fnc_aiSetAutoCombat;
};

// TRAVEL: the driver leads, the squad goes to the dismount point / landing zone; stuck vehicles are handled here
SC_fnc_aiDoTravel = {
    params ["_group", "_vehicle", "_target"];

    private _driver = driver _vehicle;

    if ((leader _group) isNotEqualTo _driver) then {
        _group selectLeader _driver;
    };

    private _destination = [_group, _vehicle, _target] call SC_fnc_aiGetTravelDestination;

    if ((_group getVariable ["SC_var_aiState", ""]) != "TRAVEL") then {
        _group setVariable ["SC_var_aiStuckCheck", nil];
        _group setVariable ["SC_var_aiLanding", nil];
    };

    [_group, _destination] call SC_fnc_aiSetWaypoint;

    // a ground vehicle drives right up to its dismount point (not only into the usual 40 m around it)
    if (!(_vehicle isKindOf "Air") && {(currentWaypoint _group) < (count (waypoints _group))}) then {
        [_group, currentWaypoint _group] setWaypointCompletionRadius 10;
    };

    [_group, SC_var_aiStanceTravel, true] call SC_fnc_aiSetStance;
    [units _group, false] call SC_fnc_aiSetAutoCombat;

    if (_vehicle isKindOf "Air") then {
        _vehicle flyInHeight 80;

        if ((_vehicle distance2D _destination) < 250) then {
            private _landingSince = _group getVariable ["SC_var_aiLanding", -1];

            if (_landingSince < 0) then {
                _vehicle land "LAND";
                _group setVariable ["SC_var_aiLanding", time];
            } else {
                // a landing that doesn't end: a new landing zone
                if ((time - _landingSince) > 120) then {
                    ["stuck", _group, typeOf _vehicle, "landing", round (_vehicle distance2D _destination)] call SC_fnc_aiLog;
                    _group setVariable ["SC_var_aiDestination", nil];
                    _group setVariable ["SC_var_aiLanding", nil];
                    _vehicle land "NONE";
                };
            };
        };
    } else {
        [_group, _vehicle, _destination, true] call SC_fnc_aiCheckStuck;
    };
};

// FIGHT: the leader moves through the sector (new points at cover from time to time), the other member takes its own
// position near his point (SC_fnc_aiSpreadMembers), armed vehicles keep their crew and support
SC_fnc_aiDoFight = {
    params ["_group", "_target", "_able"];

    private _waypoint = _group getVariable ["SC_var_aiWaypoint", []];
    private _targetPos = _group getVariable ["SC_var_aiTargetPos", []];

    if (
        (_targetPos isEqualTo []) ||
        {_waypoint isEqualTo []} ||
        {((leader _group) distance2D _targetPos) < 25} ||
        {(time - (_waypoint select 2)) > SC_var_aiFightMoveTime}
    ) then {
        private _enemy = (leader _group) findNearestEnemy (leader _group);
        _targetPos =[[_target, 0.6] call SC_fnc_aiRandomSectorPos,
            [getPosATL _enemy,
            (SC_var_aiSectorInfo get _target) select 0] select (isNull _enemy)] call SC_fnc_aiCoverPos;
        _group setVariable ["SC_var_aiTargetPos", _targetPos];
        [_group, _targetPos, "MOVE", true] call SC_fnc_aiSetWaypoint;
        _group setVariable ["SC_var_aiNextSpread", -1];
    };

    if (time > (_group getVariable ["SC_var_aiNextSpread", -1])) then {
        [_group, _able, _target, _targetPos] call SC_fnc_aiSpreadMembers;
    };

    [_group, SC_var_aiStanceFight] call SC_fnc_aiSetStance;
    [units _group, true] call SC_fnc_aiSetAutoCombat;
};

// a squad on foot far away from its objective without a vehicle in reach is sent back to the front: its members are
// suspended and come back by the AI fill at the spawn point closest to the objective (only when nobody sees them and
// that spawn point is much closer)
SC_fnc_aiCheckRedeploy = {
    params ["_group", "_side", "_able", "_target", "_distance", "_enemyDistance"];

    if (
        (_distance < SC_var_aiRedeployDistance) ||
        {_enemyDistance < 500} ||
        {(_able findIf {[_x, SC_var_aiSeenDistance] call SC_fnc_aiIsSeenByPlayers}) != -1} ||
        {
            private _targetPos = getMarkerPos ("SC_var_sector" + _target);
            private _spawnPoints = [getMarkerPos ("SC_var_" + (toLower (str _side)) + "Respawn")] +
                ((SC_var_sectors select {(missionNamespace getVariable ("SC_var_owner" + _x)) == _side}) apply {getMarkerPos ("SC_var_sector" + _x)});

            (selectMin (_spawnPoints apply {_x distance2D _targetPos})) > (0.5 * _distance)
        }
    ) exitWith {
        _group setVariable ["SC_var_aiStrandedSince", -1];
    };

    private _strandedSince = _group getVariable ["SC_var_aiStrandedSince", -1];

    if (_strandedSince < 0) exitWith {
        _group setVariable ["SC_var_aiStrandedSince", time];
    };

    if ((time - _strandedSince) > 60) then {
        ["redeploy", _group, count _able, round _distance] call SC_fnc_aiLog;

        {
            [_x, "redeploy"] call SC_fnc_suspendUnit;
        } forEach ((units _group) select {!(isPlayer _x)});
    };
};

// members on foot that fell far behind their travelling squad (e.g. joined it on the way) are brought back (only
// unseen); members without a seat in the squad vehicle follow on foot
SC_fnc_aiCheckStragglers = {
    params ["_group", "_able"];

    private _leader = leader _group;

    {
        if (
            (isNull (objectParent _x)) &&
            {(_x distance _leader) > SC_var_aiStragglerDistance} &&
            {isNull (_x getVariable ["AIS_isHelper", objNull])} &&
            {!([_x, SC_var_aiSeenDistance] call SC_fnc_aiIsSeenByPlayers)}
        ) then {
            ["straggler", _group, round (_x distance _leader)] call SC_fnc_aiLog;
            [_x, "straggler"] call SC_fnc_suspendUnit;
        };
    } forEach ((_able - [_leader]) - (_group getVariable ["SC_var_aiLeftBehind", []]));
};

// one step of a squad's state machine
SC_fnc_aiUpdateSquad = {
    params ["_group"];

    private _members = (units _group) select {(alive _x) && {simulationEnabled _x}};

    // a group with a player follows its player, only pure AI squads are controlled here
    if ((_members isEqualTo []) || {(_members findIf {isPlayer _x}) != -1}) exitWith {};

    // unconscious members and members still hanging on their parachute (a parachute is a vehicle: getting them "out"
    // of it would let them fall) don't count until they are back on their feet
    private _able = _members select {
        !(_x getVariable ["AIS_unconscious", false]) &&
        {!((objectParent _x) isKindOf "ParachuteBase")}
    };

    if (_able isEqualTo []) exitWith {};

    // AI never flee (a fleeing squad runs off and then stands without an order)
    if !(_group getVariable ["SC_var_aiNoFleeing", false]) then {
        _group allowFleeing 0;
        _group setVariable ["SC_var_aiNoFleeing", true];
    };

    // moving a spawn vehicle to the front comes first (SC\ai\delivery.sqf)
    private _delivery = _group getVariable ["SC_var_aiDelivery", []];

    if (_delivery isNotEqualTo []) exitWith {
        [_group, _able, _delivery] call SC_fnc_aiDoDelivery;
    };

    // fire teams that rode together split after the ride (the leader's part goes on here, the others next pass)
    if ([_group] call SC_fnc_aiSplitFireTeam) then {
        _able = _able select {(group _x) isEqualTo _group};
    };

    if (_able isEqualTo []) exitWith {};

    private _vehicle = [_group] call SC_fnc_aiGetSquadVehicle;
    _vehicle = [_group, _able, _vehicle] call SC_fnc_aiCheckOtherVehicles;

    private _leader = [_group, _able, _vehicle] call SC_fnc_aiEnsureLeader;
    private _target = _group getVariable ["SC_var_aiTarget", ""];

    // a member drives players of the SC group: the fire team drives them
    private _chauffeurIndex = _able findIf {[_x] call SC_fnc_aiIsChauffeur};

    if (_chauffeurIndex != -1) exitWith {
        [_group, _able select _chauffeurIndex, _target] call SC_fnc_aiDoChauffeur;
    };

    if (_target == "") exitWith {
        [_group, "IDLE", "no objective"] call SC_fnc_aiSetState;
    };

    // the whole squad rides with a player: no orders until the ride ends
    if ((_able findIf {isNull (objectParent _x) || {(objectParent _x) isEqualTo _vehicle}}) == -1) exitWith {
        [_group] call SC_fnc_aiClearWaypoints;
        [_group, "RIDE"] call SC_fnc_aiSetState;
    };

    (SC_var_aiSectorInfo get _target) params ["_center", "_radius"];

    private _distance = 0 max ((_leader distance2D _center) - _radius);
    private _enemy = _leader findNearestEnemy _leader;
    private _enemyDistance = [_leader distance _enemy, 1e9] select (isNull _enemy);

    // ---- vehicle upkeep: repair, abandon, release ----
    if (!(isNull _vehicle) && {!(isNil {_group getVariable "SC_var_aiRepair"})}) exitWith {
        [_group, "REPAIR"] call SC_fnc_aiSetState;
        [_group, _vehicle] call SC_fnc_aiUpdateRepair;
    };

    // a flipped vehicle is put back on its wheels by the unflip mod (UF, about 10 s): the squad goes on on foot meanwhile
    // and keeps it (SC_fnc_aiWaitsForUnflip), then gets in again
    if (!(isNull _vehicle) && {[_vehicle] call SC_fnc_aiWaitsForUnflip}) then {
        _vehicle = objNull;
    };

    if (!(isNull _vehicle) && {!([_vehicle, _group] call SC_fnc_aiIsVehicleUsable)}) then {
        if (
            (alive _vehicle) &&
            {!(canMove _vehicle)} &&
            {(locked _vehicle) <= 1} &&
            {(_leader distance _vehicle) < SC_var_aiVehicleWalkDistance} &&
            {(_distance > SC_var_aiVehicleUseDistance) || {(_able findIf {(objectParent _x) isEqualTo _vehicle}) != -1}} &&
            {[_vehicle, _able, _enemyDistance] call SC_fnc_aiCanRepair}
        ) then {
            [_group, _vehicle, _able] call SC_fnc_aiStartRepair;
        } else {
            [_group, _vehicle, "not usable"] call SC_fnc_aiAbandonVehicle;
            _vehicle = objNull;
        };
    };

    if !(isNil {_group getVariable "SC_var_aiRepair"}) exitWith {
        [_group, "REPAIR"] call SC_fnc_aiSetState;
    };

    private _inside = if (isNull _vehicle) then {[]} else {_able select {(objectParent _x) isEqualTo _vehicle}};

    // a vehicle the squad walked away from is free for others
    if (!(isNull _vehicle) && {_inside isEqualTo []} && {(_leader distance _vehicle) > (2 * SC_var_aiVehicleWalkDistance)}) then {
        [_group, _vehicle, "left behind"] call SC_fnc_aiReleaseVehicle;
        _vehicle = objNull;
    };

    // a boat the squad got out of on its objective's land mass has done its job: the squad goes on on foot or gets a
    // vehicle at the harbour it landed at (else it would board the boat again for the rest of the way)
    if (
        !(isNull _vehicle) &&
        {_vehicle isKindOf "Ship"} &&
        {(_able findIf {(objectParent _x) isEqualTo _vehicle}) == -1} &&
        {[_group, _target] call SC_fnc_aiOnTargetLandmass}
    ) then {
        [_group, _vehicle, "landed"] call SC_fnc_aiReleaseVehicle;
        _vehicle = objNull;

        // a new leg: a vehicle may be requested at once (the wait of the last request is for the boat trip)
        _group setVariable ["SC_var_aiNextVehicleRequest", 0];
    };

    // an objective across the water (an island): by boat from a harbour of the own land mass (SC\ai\boats.sqf); not for
    // a squad in a boat or helicopter already. At the harbour the squad leaves its land vehicle and gets a boat.
    private _harbor = if (!(isNull _vehicle) && {(_vehicle isKindOf "Ship") || {_vehicle isKindOf "Air"}}) then {
        _group setVariable ["SC_var_aiHarbor", -1];
        -1
    } else {
        [_group, _target] call SC_fnc_aiBoatHarbor
    };
    private _atHarbor = (_harbor != -1) && {(_leader distance2D ((SC_var_harbors select _harbor) select 1)) < SC_var_aiHarborReach};

    if (_atHarbor && {!(isNull _vehicle)} && {(_able findIf {(objectParent _x) isEqualTo _vehicle}) == -1}) then {
        [_group, _vehicle, "boat at harbour"] call SC_fnc_aiReleaseVehicle;
        _vehicle = objNull;
    };

    // at the harbour another team's boat first (SC_fnc_aiJoinRide), else an own one
    if (_atHarbor && {isNull _vehicle} && {[_group, _able] call SC_fnc_aiJoinRide}) exitWith {};

    if (_atHarbor && {isNull _vehicle}) then {
        [_group, _able, _harbor] call SC_fnc_aiGetBoat;
        _vehicle = [_group] call SC_fnc_aiGetSquadVehicle;
    };

    // a fire team far from its objective without a vehicle rides along with another fire team of its SC group if it can
    if (
        !_atHarbor &&
        {isNull _vehicle} &&
        {_distance > SC_var_aiVehicleUseDistance} &&
        {_enemyDistance > SC_var_aiCloseFightDistance} &&
        {[_group, _able] call SC_fnc_aiJoinRide}
    ) exitWith {};

    // a squad far from its objective looks for a vehicle (no enemy close), at an own spawn point it may get one
    if(!_atHarbor && {isNull _vehicle} && {_distance > SC_var_aiVehicleUseDistance} &&
        {_enemyDistance > SC_var_aiCloseFightDistance}) then {
        private _found = [_group, _able] call SC_fnc_aiFindVehicle;

        if (isNull _found) then {
            [_group, _able] call SC_fnc_aiRequestVehicle;
        } else {
            [_group, _found, "objective far"] call SC_fnc_aiReserveVehicle;
            _vehicle = _found;
        };
    };

    _group setVariable ["SC_var_aiMobile", !(isNull _vehicle)];

    // ---- mode ----
    private _mode = [_group, _vehicle, _able, _inside, _distance, _enemyDistance] call SC_fnc_aiChooseMode;
    private _state = _group getVariable ["SC_var_aiState", ""];

    // getting out: everybody, or the passengers of an armed vehicle when the squad fights at the sector
    if ((_mode in ["MOVE", "FIGHT"]) && {_inside isNotEqualTo []} && {_state in ["TRAVEL", "BOARD"]}) then {
        if (_vehicle isKindOf "Air") then {
            _vehicle land "NONE";
        };

        [_group, _vehicle, (_mode == "FIGHT") && {[_vehicle] call SC_fnc_aiIsArmed} && {!(_vehicle isKindOf "Air")}, _mode] call SC_fnc_aiDismount;
        _leader = leader _group;
    };

    // on foot: nobody keeps walking to a seat (the crew of an armed vehicle that supports the squad stays inside)
    if ((_mode in ["MOVE", "FIGHT"]) && {!(isNull _vehicle)}) then {
        {
            if (((assignedVehicle _x) isEqualTo _vehicle) && {(objectParent _x) isNotEqualTo _vehicle}) then {
                unassignVehicle _x;
                [_x] orderGetIn false;
            };
        } forEach _able;
    };

    // members that were ordered out (no seat any more) but still sit in the stopped vehicle 10 s later (an exit that
    // doesn't happen, e.g. from a person turret) are moved out; not out of a vehicle a player or a chauffeur drives
    if (
        (_mode in ["MOVE", "FIGHT"]) &&
        {(time - (_group getVariable ["SC_var_aiDismountTime", -1e9])) > 10} &&
        {(time - (_group getVariable ["SC_var_aiDismountTime", -1e9])) < 300}
    ) then {
        {
            private _parent = objectParent _x;

            if (
                !(isNull _parent) &&
                {!(_parent isKindOf "ParachuteBase")} &&
                {((assignedVehicleRole _x) param [0, ""]) == ""} &&
                {(abs (speed _parent)) < 3} &&
                {!(_parent isKindOf "Air") || {isTouchingGround _parent}} &&
                {!(isPlayer (driver _parent))} &&
                {!([driver _parent] call SC_fnc_aiIsChauffeur)}
            ) then {
                moveOut _x;
            };
        } forEach _able;
    };

    // spread out in a fight; together again for a vehicle, a new objective or a long walk
    if ((_mode != "FIGHT") && {(_mode != "MOVE") || {_distance > SC_var_aiApproachDistance} || {(_group getVariable ["SC_var_aiSpreadTarget", ""]) != _target}}) then {
        [_group] call SC_fnc_aiRegroup;
    };

    switch _mode do {
        case "FIGHT": {
            [_group, _target, _able] call SC_fnc_aiDoFight;
        };
        case "BOARD": {
            [_group, _vehicle, _able, _inside] call SC_fnc_aiDoBoard;
        };
        case "TRAVEL": {
            [_group, _vehicle, _target] call SC_fnc_aiDoTravel;
            [_group, _able] call SC_fnc_aiCheckStragglers;
        };
        default {
            [_group, _target, _distance, _enemyDistance] call SC_fnc_aiDoMove;

            if (isNull _vehicle) then {
                [_group, side _group, _able, _target, _distance, _enemyDistance] call SC_fnc_aiCheckRedeploy;
            };
        };
    };

    [_group, _mode] call SC_fnc_aiSetState;
};

// a UAV crew flies / drives to the objective of its own choice; while a player controls the UAV its AI is off
SC_fnc_aiUpdateUav = {
    params ["_group", "_side"];

    private _uav = vehicle (leader _group);
    private _enableAI = (([_uav] call SC_fnc_uavControlUnits) findIf {isPlayer _x}) == -1;

    {
        if ((_x checkAIFeature "MOVE") != _enableAI) then {
            [_x, ["ALL", _enableAI]] remoteExecCall ["enableAIFeature", (owner _x)];
        };
    } forEach (crew _uav);

    if (!_enableAI || {time < (_group getVariable ["SC_var_aiNextUavPlan", 0])}) exitWith {};

    _group setVariable ["SC_var_aiNextUavPlan", time + 30];

    private _target = [_group, _side] call SC_fnc_aiPlanUav;

    if (_target != "") then {
        _group setVariable ["SC_var_aiTarget", _target];
        [_group, ([_target, 0.5] call SC_fnc_aiRandomSectorPos), (["MOVE", "LOITER"] select (_uav isKindOf "Plane"))] call SC_fnc_aiSetWaypoint;
    };
};

// ---- units ----

// one AI loop step for a registered unit: bleeding out, removal of stray units, the despawn countdown of dead units
SC_fnc_aiUpdateUnit = {
    params ["_unit"];

    if !(alive _unit) exitWith {
        if ([_unit] call SC_fnc_isUavAi) exitWith {};

        private _timeRemaining = _unit getVariable "SC_var_timeRemaining";

        if (isNil "_timeRemaining" || {_timeRemaining <= 0}) exitWith {};

        private _isInBase = (getPosWorld _unit) inArea ("SC_var_" + (str (side (group _unit))) + "Base");
        private _minDistanceFromUnitToDespawn = [SC_var_minDistanceFromUnitToDespawn, 1] select _isInBase;
        _timeRemaining = [_unit, _timeRemaining, SC_var_unitDespawnTime, _minDistanceFromUnitToDespawn, 3] call SC_fnc_getNewDespawnTime;

        if (_timeRemaining > 0) exitWith {
            _unit setVariable ["SC_var_timeRemaining", _timeRemaining];
        };

        if (isPlayer _unit) then {
            _unit enableSimulationGlobal false;
            _unit setPos [0, 0, 10];
        } else {
            [_unit, "dead"] call SC_fnc_suspendUnit;
        };
    };

    if (isPlayer _unit) exitWith {};

    if (_unit getVariable ["AIS_unconscious", false]) exitWith {
        private _unconsciousSince = _unit getVariable ["AIS_unconscious_since", -999];

        if ((_unconsciousSince >= 0) && {(random 10) < ((time - _unconsciousSince) / AIS_BLEEDOUT_TIME)}) then {
            _unit setDamage 1;
        };
    };

    if ([_unit] call SC_fnc_isUavAi) exitWith {};

    // a non-player unit without an AI name doesn't belong to the game (a player's slot unit in the handover to the AI
    // pool is renamed first)
    if (!(" (AI)" in (name _unit)) && {!(_unit getVariable ["SC_var_handover", false])}) exitWith {
        private _parent = objectParent _unit;

        if (isNull _parent) then {
            [_unit] remoteExecCall ["deleteVehicle", 2];
        } else {
            [_parent, _unit] remoteExecCall ["deleteVehicleCrew", 2];
        };
    };

    if (_unit inArea "SC_var_spawnArea") then {
        [_unit, "spawn area"] call SC_fnc_suspendUnit;
    };
};

// called by SC_fnc_spawnVehicle (vehicles\spawning.sqf) once an AI sits in the vehicle it spawned: its squad takes it
SC_fnc_aiAdoptVehicle = {
    params ["_unit"];

    private _vehicle = objectParent _unit;

    if ((isPlayer _unit) || {isNull _vehicle}) exitWith {};

    private _group = group _unit;

    if (isNull ([_group] call SC_fnc_aiGetSquadVehicle)) then {
        [_group, _vehicle, "spawned"] call SC_fnc_aiReserveVehicle;
    };
};
