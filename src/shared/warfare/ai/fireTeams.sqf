// AI on foot (SC\groups.sqf): every AI is an engine group of its own ("fire team" here; more than one only for a ride)
// that shares the objective of its SC group (SC\ai\objectives.sqf) but moves on its own: it comes in from its own
// direction (approach point) and takes its own points at cover in the sector; AI with the same or a neighbouring
// objective that ride one vehicle are one engine group for the ride.

// A fire team on foot first walks to its approach point outside the sector, on the side it comes from turned by up to
// 70 degrees, as far as possible from the approach directions of the other fire teams of the side with the same
// objective; with a chance of SC_var_aiFlankChance it flanks instead (110 - 140 degrees). The point is this far outside
// the sector's edge ([factor of the sector spacing, min, max], SC_fnc_aiInitTuning).
SC_var_aiApproachScale = [0.25, 30, 150];
SC_var_aiFlankChance = 0.25;

// In a fight the members except the leader (the anchor at the fire team's point in the sector) get their own position
// near that point, this far from it ([factor of the sector radius, per member, min, max] in m), at cover if there is
// some (building positions, walls, rocks, trees); new positions with a new point or after SC_var_aiSpreadTime seconds
// (plus up to the same again at random). On the way they follow the leader again.
SC_var_aiSpreadScale = [0.3, 4, 10, 40];
SC_var_aiSpreadTime = 40;

// a fire team that joined another one for a ride splits off again at the earliest after this time (s) if the ride
// doesn't start
SC_var_aiRideJoinTime = 30;

// a fire team on foot looks for a ride at most this often (s)
SC_var_aiRideJoinRetry = 10;

// the members (not the leader) on foot that can get an own position: not helping a comrade (AIS)
SC_fnc_aiFreeMembers = {
    params ["_group", "_able"];

    (_able - [leader _group]) select {(isNull (objectParent _x)) && {isNull (_x getVariable ["AIS_isHelper", objNull])}}
};

// approach point of a fire team for its objective, chosen once per objective ([] when it is reached, not needed or in
// the water)
SC_fnc_aiGetApproachPos = {
    params ["_group", "_target"];

    (_group getVariable ["SC_var_aiApproach", []]) params [["_approachTarget", ""], ["_approachPos", []]];

    if (_approachTarget == _target) exitWith {_approachPos};

    (SC_var_aiSectorInfo get _target) params ["_center", "_radius"];

    private _side = side _group;
    private _homeDir = _center getDir (leader _group);
    private _otherDirs = [];

    {
        (_x getVariable ["SC_var_aiApproach", []]) params [["_otherTarget", ""], ["_otherPos", []]];

        if (
            (_x isNotEqualTo _group) &&
            {(side _x) == _side} &&
            {_otherTarget == _target} &&
            {_otherPos isNotEqualTo []} &&
            {(_x getVariable ["SC_var_aiTarget", ""]) == _target}
        ) then {
            _otherDirs pushBack (_center getDir _otherPos);
        };
    } forEach allGroups;

    private _offsets = if ((random 1) < SC_var_aiFlankChance) then {[-140, -110, 110, 140]} else {[-70, -35, 0, 35, 70]};
    private _bestDir = _homeDir;
    private _bestScore = -1;

    {
        private _dir = _homeDir + _x;
        private _score = (random 10) + (if (_otherDirs isEqualTo []) then {0} else {
            selectMin (_otherDirs apply {abs ((((_dir - _x) + 540) % 360) - 180)})
        });

        if (_score > _bestScore) then {
            _bestDir = _dir;
            _bestScore = _score;
        };
    } forEach _offsets;

    _approachPos = _center getPos [_radius + SC_var_aiApproachDistance, _bestDir];

    if (surfaceIsWater _approachPos) then {
        _approachPos = [];
    };

    _group setVariable ["SC_var_aiApproach", [_target, _approachPos]];

    _approachPos
};

// a covered position near _pos: a building position within 12 m, else 1.5 m behind (seen from _threatPos) a wall, rock
// or tree within 10 m, else behind a building within 15 m; _pos itself if there is no cover
SC_fnc_aiCoverPos = {
    params ["_pos", "_threatPos"];

    private _building = nearestBuilding _pos;
    private _buildingPositions = if ((isNull _building) || {(_building distance2D _pos) > 40}) then {[]} else {
        (_building buildingPos -1) select {(_x distance2D _pos) < 12}
    };

    if (_buildingPositions isNotEqualTo []) exitWith {selectRandom _buildingPositions};

    private _objects = nearestTerrainObjects [_pos, ["WALL", "ROCK", "ROCKS", "TREE", "HIDE"], 10, true, true];

    if (_objects isNotEqualTo []) exitWith {
        (getPosATL (_objects select 0)) getPos [1.5, _threatPos getDir (_objects select 0)]
    };

    _objects = nearestTerrainObjects [_pos, ["BUILDING", "HOUSE"], 15, true, true];

    if (_objects isNotEqualTo []) exitWith {
        private _object = _objects select 0;
        (getPosATL _object) getPos [1.5 + (0.7 * ((boundingBoxReal _object) select 2)), _threatPos getDir _object]
    };

    _pos
};

// every free member gets its own position near the fire team's point in the sector (SC_var_aiSpreadScale), spread
// evenly around it
SC_fnc_aiSpreadMembers = {
    params ["_group", "_able", "_target", "_targetPos"];

    _group setVariable ["SC_var_aiNextSpread", time + (SC_var_aiSpreadTime * (1 + (random 1)))];
    _group setVariable ["SC_var_aiSpreadTarget", _target];

    private _members = [_group, _able] call SC_fnc_aiFreeMembers;

    if (_members isEqualTo []) exitWith {};

    (SC_var_aiSectorInfo get _target) params ["_center", "_radius"];
    SC_var_aiSpreadScale params ["_radiusFactor", "_perMember", "_min", "_max"];

    private _leader = leader _group;
    private _spread = _min max (_max min ((_radiusFactor * _radius) + (_perMember * (count _able))));
    private _enemy = _leader findNearestEnemy _leader;
    private _threatPos = if (isNull _enemy) then {_center} else {getPosATL _enemy};
    private _startDir = random 360;
    private _step = 360 / (count _members);

    {
        private _pos = _targetPos getPos [_spread * (0.5 + (random 0.5)), _startDir + (_forEachIndex * _step) + (random 30) - 15];
        _pos = [_pos, _threatPos] call SC_fnc_aiCoverPos;

        if !(surfaceIsWater _pos) then {
            _x doMove _pos;
            _x setVariable ["SC_var_aiSpreadPos", _pos];
        };
    } forEach _members;
};

// members with an own position (spread) follow the leader again
SC_fnc_aiRegroup = {
    params ["_group"];

    private _leader = leader _group;

    {
        if !(isNil {_x getVariable "SC_var_aiSpreadPos"}) then {
            _x setVariable ["SC_var_aiSpreadPos", nil];

            if ((alive _x) && {_x isNotEqualTo _leader}) then {
                _x doFollow _leader;
            };
        };
    } forEach (units _group);
};

// An engine group of more than SC_var_aiFireTeamSize active AI (AI that rode together, respawned members) splits once
// nobody of it sits in a vehicle and it doesn't board (a group that just joined for a ride SC_var_aiRideJoinTime later):
// the leader keeps the vehicle, every other AI gets a group of its own without an objective (the planning gives it the
// one of its SC group at once, a ride can have gone to a neighbouring sector). True if it split.
SC_fnc_aiSplitFireTeam = {
    params ["_group"];

    private _active = [_group] call SC_fnc_getActiveUnits;

    if (
        ((count _active) <= SC_var_aiFireTeamSize) ||
        {(_active findIf {!(isNull (objectParent _x))}) != -1} ||
        {(_group getVariable ["SC_var_aiState", ""]) == "BOARD"} ||
        {(time - (_group getVariable ["SC_var_aiRideJoinedAt", -1e9])) < SC_var_aiRideJoinTime}
    ) exitWith {false};

    private _leader = leader _group;
    private _rest = ([(_active - [_leader]), [], {_x distance _leader}, "ASCEND"] call BIS_fnc_sortBy) select [SC_var_aiFireTeamSize - 1];

    while {_rest isNotEqualTo []} do {
        private _team = _rest select [0, SC_var_aiFireTeamSize];
        _rest = _rest select [SC_var_aiFireTeamSize];

        private _newGroup = createGroup [side _group, true];
        _team joinSilent _newGroup;

        {
            unassignVehicle _x;
            [_x] orderGetIn false;
        } forEach _team;

        ["split", _newGroup, count _team, netId _group] call SC_fnc_aiLog;
    };

    true
};

// An AI (group) without a vehicle in reach that would take one rides along with another AI group of its side that is
// boarding its vehicle (reserved, usable, within SC_var_aiVehicleWalkDistance) with a seat for everybody, if the ride
// brings it closer: that group's objective is the same or a neighbouring sector (less than 1.5 sector spacings apart),
// or it is less than half as far from the AI's objective as the AI itself (on a huge map a ride from the base towards
// the own objective). It joins that group for the ride (SC_fnc_aiSplitFireTeam splits them after it). At most every
// SC_var_aiRideJoinRetry seconds per AI. True if it joined.
SC_fnc_aiJoinRide = {
    params ["_group", "_able"];

    private _leader = leader _group;

    if (time < (_leader getVariable ["SC_var_aiNextRideJoin", 0])) exitWith {false};

    _leader setVariable ["SC_var_aiNextRideJoin", time + SC_var_aiRideJoinRetry];

    private _target = _group getVariable ["SC_var_aiTarget", ""];

    if (_target == "") exitWith {false};

    private _side = side _group;
    private _targetCenter = getMarkerPos ("SC_var_sector" + _target);
    private _ownDistance = _leader distance2D _targetCenter;
    private _host = grpNull;

    {
        private _other = _x;
        private _otherTarget = _other getVariable ["SC_var_aiTarget", ""];
        private _vehicle = _other getVariable ["SC_var_aiVehicle", objNull];

        if (
            (isNull _host) &&
            {_other isNotEqualTo _group} &&
            {(side _other) == _side} &&
            {alive _vehicle} &&
            {_otherTarget != ""} &&
            {
                (_otherTarget == _target) ||
                {((getMarkerPos ("SC_var_sector" + _otherTarget)) distance2D _targetCenter) < ((1.5 * SC_var_aiSectorSpacing) max (0.5 * _ownDistance))}
            } &&
            {(_other getVariable ["SC_var_aiState", ""]) == "BOARD"} &&
            {((_other getVariable ["SC_var_aiDelivery", []]) isEqualTo [])} &&
            {(_vehicle getVariable ["SC_var_aiVehicleGroup", grpNull]) isEqualTo _other} &&
            {(_leader distance _vehicle) < SC_var_aiVehicleWalkDistance} &&
            {((units _other) findIf {isPlayer _x}) == -1} &&
            {[_vehicle, _other] call SC_fnc_aiIsVehicleUsable} &&
            // a team that needs a boat (SC\ai\boats.sqf) rides a boat or helicopter, the others no boat
            {(_vehicle isKindOf "Air") || {(_vehicle isKindOf "Ship") == ((_group getVariable ["SC_var_aiHarbor", -1]) != -1)}} &&
            {((count ([_other] call SC_fnc_getActiveUnits)) + (count _able)) <= (([typeOf _vehicle] call SC_fnc_aiSeatCounts) select 0)}
        ) then {
            _host = _other;
        };
    } forEach allGroups;

    if (isNull _host) exitWith {false};

    ["rideJoin", _host, count _able, netId _group, typeOf (_host getVariable ["SC_var_aiVehicle", objNull])] call SC_fnc_aiLog;
    _able joinSilent _host;
    _host setVariable ["SC_var_aiRideJoinedAt", time];

    true
};

// whether an AI drives a vehicle with players of its SC group in it (it drives them, SC_fnc_aiDoChauffeur); never a
// spawn vehicle (SC\vehicles\spawnVehicles.sqf: a respawn position, the AI moves it only by a delivery)
SC_fnc_aiIsChauffeur = {
    params ["_unit"];

    private _vehicle = objectParent _unit;

    !(isNull _vehicle) &&
    {!(isPlayer _unit)} &&
    {!(_vehicle getVariable ["SC_var_spawnVehicle", false])} &&
    {(driver _vehicle) isEqualTo _unit} &&
    {
        private _groupUnits = [_unit] call SC_fnc_getGroupUnits;
        ((crew _vehicle) findIf {(alive _x) && {isPlayer _x} && {_x in _groupUnits}}) != -1
    }
};

// CHAUFFEUR: an AI drives players of its SC group (they can't order an AI of another engine group): to the custom
// waypoint of one of them (Shift + click on the map, SC_fnc_customWaypointLoop) if one is set, else to the dismount
// point / landing zone of the objective; it waits there until they get out or set a new waypoint
SC_fnc_aiDoChauffeur = {
    params ["_group", "_driver", "_target"];

    private _vehicle = objectParent _driver;
    private _groupUnits = [_driver] call SC_fnc_getGroupUnits;
    private _players = (crew _vehicle) select {(alive _x) && {isPlayer _x} && {_x in _groupUnits}};
    private _index = _players findIf {((_x getVariable ["SC_var_customWaypoint", []]) isNotEqualTo [])};

    if ((leader _group) isNotEqualTo _driver) then {
        _group selectLeader _driver;
    };

    private _destination = switch true do {
        case (_index != -1): {(_players select _index) getVariable "SC_var_customWaypoint"};
        case (_target != ""): {[_group, _vehicle, _target] call SC_fnc_aiGetTravelDestination};
        default {getPosATL _vehicle};
    };

    [_group, _destination] call SC_fnc_aiSetWaypoint;
    [_group, SC_var_aiStanceTravel, true] call SC_fnc_aiSetStance;
    [units _group, false] call SC_fnc_aiSetAutoCombat;

    if (_vehicle isKindOf "Air") then {
        _vehicle flyInHeight 80;

        private _landing = _group getVariable ["SC_var_aiChauffeurLanding", []];

        // landing near the destination, taking off again for a new one far away
        if (((_vehicle distance2D _destination) < 250) && {_landing isNotEqualTo _destination}) then {
            _vehicle land "LAND";
            _group setVariable ["SC_var_aiChauffeurLanding", _destination];
        };

        if (((_vehicle distance2D _destination) > 400) && {_landing isNotEqualTo []}) then {
            _vehicle land "NONE";
            _group setVariable ["SC_var_aiChauffeurLanding", []];
        };
    };

    [_group, "CHAUFFEUR"] call SC_fnc_aiSetState;
};
