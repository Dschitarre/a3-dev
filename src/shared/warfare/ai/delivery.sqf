// AI delivery of the spawn vehicles (SC\vehicles\spawnVehicles.sqf): with top priority an AI squad near a spawn
// vehicle of its side drives / flies it from the base to a concealed spot near the front, where it becomes a respawn
// position, gets out and goes on with its objective; the vehicle is moved again when it is of no use there any more.
// Spawn vehicles with players in them and the AI of players' groups are left alone (server).

// ---- tuning ----

// a squad at most this far from a spawn vehicle fetches it (a squad on foot that isn't in a fight)
SC_var_aiDeliveryFetchDistance = 400;

// a delivery fails when it takes longer than this time (s; boarding, leaving the base, landing) plus 1 s per 4 m of
// the way from the vehicle to its spot (stuck, ...); once the vehicle left the base, at least the second time plus
// 1 s per 4 m of the remaining way
SC_var_aiDeliveryTimeout = 300;
SC_var_aiDeliveryWayTimeout = 120;

// after a failed delivery a spawn vehicle waits this long (s) for the next squad, twice as long after every further
// failure in a row (at most SC_var_aiDeliveryMaxRetryTime)
SC_var_aiDeliveryRetryTime = 60;
SC_var_aiDeliveryMaxRetryTime = 600;

// a parked spawn vehicle is checked this often (s) whether it is still useful where it stands
SC_var_aiDeliveryCheckTime = 120;

// a parked spawn vehicle that is no respawn position for this long (s; enemies near, in the water, ...) is moved
SC_var_aiDeliveryBlockedTime = 180;

// a parked spawn vehicle this far (m) from the front (its parking sectors, SC_fnc_aiDeliveryAnchors), in sector
// spacings plus a fixed part, is moved closer
SC_var_aiDeliveryFrontScale = [0.5, 300];

// a spawn vehicle at the base without a squad near it makes one AI of its side spawn there, at most once in this
// time (s)
SC_var_aiDeliveryDriverInterval = 60;

// candidate spots per front sector of the spot search (performance: every candidate costs a few ray casts)
SC_var_aiDeliveryCandidates = 12;

// a ground vehicle is delivered within this distance (m) of its spot and off the road (it drives to the spot with a
// small waypoint completion radius), a helicopter that landed after the landing order within the second one (it
// picks its landing place itself, an invisible helipad at the spot draws it there)
SC_var_aiDeliveryArrivalDistance = [15, 600];

// a ground vehicle that stands still off the road this close (m) to its spot after its squad tried again (stuck
// handling) is delivered as well
SC_var_aiDeliveryNearDistance = 50;

// ---- parking spot ----

// The sectors a spawn vehicle is parked at (the front): at most 2 own sectors, those closest to where the side fights -
// the sectors its AI squads attack (each squad counts), else the enemies' sectors, else the neutral ones (summed
// distances). Own sectors are safe, so the vehicle stands right behind the fighting instead of at the first own sector
// next to any sector the side doesn't own (on huge maps often one near the base). Without own sectors the side's
// nearest sector it doesn't own (the vehicle waits behind it). _taken: sectors left out while others are left (the
// sectors of the side's other spawn vehicles, SC_fnc_aiVehicleAnchors).
SC_fnc_aiDeliveryAnchors = {
    params ["_side", ["_taken", []]];

    // the first _count of _sorted without the taken sectors, all of _sorted if they are all taken
    private _pick = {
        params ["_sorted", "_count", "_taken"];

        private _free = _sorted - _taken;

        ([_sorted, _free] select (_free isNotEqualTo [])) select [0, _count]
    };

    private _own = SC_var_sectors select {(missionNamespace getVariable ("SC_var_owner" + _x)) == _side};
    private _other = SC_var_sectors - _own;

    if (_other isEqualTo []) exitWith {[]};

    if (_own isNotEqualTo []) exitWith {
        private _targets = [];

        {
            private _target = _x getVariable ["SC_var_aiTarget", ""];

            if (
                ((side _x) == _side) &&
                {(_x getVariable ["SC_var_aiTargetKind", ""]) == "attack"} &&
                {_target in _other}
            ) then {
                _targets pushBack _target;
            };
        } forEach allGroups;

        if (_targets isEqualTo []) then {
            _targets = _other select {(missionNamespace getVariable ("SC_var_owner" + _x)) in SC_var_sides};
        };

        if (_targets isEqualTo []) then {
            _targets = _other;
        };

        private _targetCenters = _targets apply {getMarkerPos ("SC_var_sector" + _x)};

        [([_own, [], {
            private _center = getMarkerPos ("SC_var_sector" + _x);
            private _sum = 0;

            {_sum = _sum + (_x distance2D _center)} forEach _targetCenters;
            _sum
        }, "ASCEND"] call BIS_fnc_sortBy), 2, _taken] call _pick
    };

    private _basePos = getMarkerPos ("SC_var_" + (toLower (str _side)) + "Respawn");

    [([_other, [], {(getMarkerPos ("SC_var_sector" + _x)) distance2D _basePos}, "ASCEND"] call BIS_fnc_sortBy), 1, _taken] call _pick
};

// The parking sectors of one spawn vehicle: those of its side without the sectors its other spawn vehicles were sent
// to (SC_var_aiDeliverySector: where one is parked or being taken), so trucks and helicopters spread over the front
// instead of all waiting at the same sectors (user 2026-11-27)
SC_fnc_aiVehicleAnchors = {
    params ["_vehicle", "_side"];

    private _taken = [];

    {
        private _other = _x get "vehicle";

        if (((_x get "side") == _side) && {alive _other} && {_other isNotEqualTo _vehicle}) then {
            _taken pushBackUnique (_other getVariable ["SC_var_aiDeliverySector", ""]);
        };
    } forEach SC_var_spawnVehicleSlots;

    [_side, _taken - [""]] call SC_fnc_aiDeliveryAnchors
};

// share (0 - 1) of the lines of sight from a spot (2 m above it) towards the enemy points (up to 500 m in their
// direction) that terrain or objects block
SC_fnc_aiConcealment = {
    params ["_pos", "_enemyPoints"];

    if (_enemyPoints isEqualTo []) exitWith {0.5};

    private _eye = (AGLToASL _pos) vectorAdd [0, 0, 2];
    private _blocked = {
        private _target = (AGLToASL (_pos getPos [500 min (_pos distance2D _x), _pos getDir _x])) vectorAdd [0, 0, 2];

        (terrainIntersectASL [_eye, _target]) ||
        {(lineIntersectsSurfaces [_eye, _target, objNull, objNull, true, 1, "VIEW", "FIRE"]) isNotEqualTo []}
    } count _enemyPoints;

    _blocked / (count _enemyPoints)
};

// parking spots: [ground vehicle, helicopter] values
// no road (a road surface or a road segment) within this distance (m) of the spot
SC_var_aiParkingRoadDistance = [6, 12];

// at least this much cover (SC_fnc_aiCoverAround) within the cover radius (m); a helicopter's landing zone itself is
// free (BIS_fnc_findSafePos), its cover stands around it
SC_var_aiParkingCoverRadius = [20, 45];
SC_var_aiParkingMinCover = [3, 4];

// terrain objects that hide a vehicle and their weight in the cover of a spot (a building hides more than a tree)
SC_var_aiCoverTypes = [
    [["BUILDING", "HOUSE", "CHURCH", "CHAPEL", "BUNKER", "FORTRESS", "RUIN", "HOSPITAL", "FUELSTATION", "VIEW-TOWER", "WATERTOWER", "LIGHTHOUSE"], 2],
    [["WALL", "ROCK", "ROCKS", "TREE", "HIDE"], 1],
    [["SMALL TREE", "BUSH"], 0.5]
];

// cover around a spot: the terrain objects within _radius by their weight (SC_var_aiCoverTypes)
SC_fnc_aiCoverAround = {
    params ["_pos", "_radius"];

    private _cover = 0;

    {
        _x params ["_types", "_weight"];
        _cover = _cover + (_weight * (count (nearestTerrainObjects [_pos, _types, _radius, false, true])));
    } forEach SC_var_aiCoverTypes;

    _cover
};

// a free place for a vehicle type 10 - 30 m from a position, off the road (SC_var_aiParkingRoadDistance), on land and
// flat; [] if none is found
SC_fnc_aiFindOffRoadSpot = {
    params ["_pos", "_type"];

    private _spot = [];

    for "_i" from 1 to 8 do {
        private _candidate = (_pos getPos [10 + (random 20), random 360]) findEmptyPosition [0, 8, _type];

        if (
            (_candidate isNotEqualTo []) &&
            {!(surfaceIsWater _candidate)} &&
            {((surfaceNormal _candidate) select 2) > 0.95} &&
            {!([_candidate, SC_var_aiParkingRoadDistance select 0] call SC_fnc_aiIsNearRoad)}
        ) exitWith {
            _spot = _candidate;
        };
    };

    _spot
};

// whether a road is within _distance of a spot: the spot or a point on two rings around it on a road surface, or a road
// segment that close
SC_fnc_aiIsNearRoad = {
    params ["_pos", "_distance"];

    (isOnRoad _pos) ||
    {(_pos nearRoads _distance) isNotEqualTo []} ||
    {
        ([0.5, 1] findIf {
            private _ringDistance = _x * _distance;
            ([0, 45, 90, 135, 180, 225, 270, 315] findIf {isOnRoad (_pos getPos [_ringDistance, _x])}) != -1
        }) != -1
    }
};

// Rating of a parking spot (-1: unusable): close to the sector (just outside it), concealed from the enemy directions,
// much cover around it. Unusable: in the water, outside the play zone, in a base, on a slope, in a sector of another
// side, enemies near, a road within SC_var_aiParkingRoadDistance or less cover than _minCover.
SC_fnc_aiRateParkingSpot = {
    params ["_pos", "_sectorInd", "_side", "_isAir", "_enemyPoints", "_minCover"];

    private _marker = "SC_var_sector" + _sectorInd;

    if (
        (surfaceIsWater _pos) ||
        {!(_pos inArea "SC_var_playZone")} ||
        {(SC_var_sides findIf {_pos inArea ("SC_var_" + (toLower (str _x)) + "Base")}) != -1} ||
        {((surfaceNormal _pos) select 2) < ([0.95, 0.97] select _isAir)} ||
        {(SC_var_sectors findIf {((missionNamespace getVariable ("SC_var_owner" + _x)) != _side) && {_pos inArea ("SC_var_sector" + _x)}}) != -1} ||
        {[_pos, SC_var_aiParkingRoadDistance select _isAir] call SC_fnc_aiIsNearRoad} ||
        {[_pos, _side, 2 * SC_var_spawnVehicleEnemyRadius] call SC_fnc_isEnemyNear}
    ) exitWith {-1};

    private _cover = [_pos, SC_var_aiParkingCoverRadius select _isAir] call SC_fnc_aiCoverAround;

    if (_cover < _minCover) exitWith {-1};

    private _edgeDistance = (_pos distance2D (getMarkerPos _marker)) - (selectMax (getMarkerSize _marker));

    (1 - ((0 max (_edgeDistance / 300)) min 1)) +
    (0.05 * (_cover min 16)) +
    (1.2 * ([_pos, _enemyPoints] call SC_fnc_aiConcealment)) -
    ([0, 0.3] select (_pos inArea _marker))
};

// Parking spot of a spawn vehicle near its parking sectors (_anchors, SC_fnc_aiVehicleAnchors), on their side that
// faces the own base, a bit outside their
// edge (scaled with the sector spacing). Half of the candidates lie right behind a building, wall, rock or tree there
// (on the side away from the nearest enemy sector), the others at random places; each is moved to a place that is
// free for the vehicle (a helicopter: a free flat landing zone). The best rated one; if none has the cover
// SC_var_aiParkingMinCover, the best one with a third of it (never on or at a road). [position, rating, sector] or []
// if no candidate is usable.
SC_fnc_aiFindParkingSpot = {
    params ["_vehicle", "_side", "_anchors"];

    private _isAir = _vehicle isKindOf "Air";
    private _type = typeOf _vehicle;
    private _basePos = getMarkerPos ("SC_var_" + (toLower (str _side)) + "Respawn");
    private _offset = 40 max (250 min (0.15 * SC_var_aiSectorSpacing));
    private _minCover = SC_var_aiParkingMinCover select _isAir;
    private _candidates = [];

    {
        private _sectorInd = _x;
        private _marker = "SC_var_sector" + _sectorInd;
        private _center = getMarkerPos _marker;
        private _radius = selectMax (getMarkerSize _marker);
        private _homeDir = _center getDir _basePos;
        private _innerRadius = _radius + (0.3 * _offset);
        private _outerRadius = _radius + (1.6 * _offset);

        // the enemy points: the sectors of the other sides closest to this one
        private _enemyPoints = (([SC_var_sectors select {(missionNamespace getVariable ("SC_var_owner" + _x)) != _side}, [], {
            (getMarkerPos ("SC_var_sector" + _x)) distance2D _center
        }, "ASCEND"] call BIS_fnc_sortBy) select [0, 3]) apply {getMarkerPos ("SC_var_sector" + _x)};

        // cover objects on the home side of the sector
        private _coverObjects = (nearestTerrainObjects [_center, ["BUILDING", "HOUSE", "WALL", "ROCK", "ROCKS", "TREE", "RUIN", "BUNKER"], _outerRadius, false, true]) select {
            private _distance = _center distance2D _x;
            (_distance > _innerRadius) && {(abs (((((_center getDir _x) - _homeDir) + 540) % 360) - 180)) < 70}
        };

        for "_i" from 1 to SC_var_aiDeliveryCandidates do {
            private _candidate = if (((_i % 2) == 1) && {_coverObjects isNotEqualTo []}) then {
                private _object = _coverObjects deleteAt (floor (random (count _coverObjects)));
                private _objectPos = getPosATL _object;
                private _awayDir = if (_enemyPoints isEqualTo []) then {_objectPos getDir _basePos} else {
                    ((_enemyPoints select 0) getDir _objectPos)
                };

                _objectPos getPos [([0.7 * ((boundingBoxReal _object) select 2) + 4, 25] select _isAir), _awayDir]
            } else {
                _center getPos [_radius + (_offset * (0.6 + (random 0.8))), _homeDir - 70 + (random 140)]
            };

            _candidate = if _isAir then {
                private _landingZone = [_candidate, 0, 30, 12, 0, 0.15, 0, [], [[0, 0, 0], [0, 0, 0]]] call BIS_fnc_findSafePos;

                [[], [_landingZone select 0, _landingZone select 1, 0]] select ((_landingZone distance2D [0, 0, 0]) > 1)
            } else {
                _candidate findEmptyPosition [0, 12, _type]
            };

            if (_candidate isNotEqualTo []) then {
                _candidates pushBack [_candidate, _sectorInd, _enemyPoints];
            };
        };
    } forEach _anchors;

    // the side's other spawn vehicles (trucks and helicopters): where they stand, or where they are being taken - a spot
    // close to one of them is taken only if there is no other (user 2026-11-26: not parked next to each other)
    private _spacing = 150 max (400 min (0.5 * SC_var_aiSectorSpacing));
    private _occupied = [];

    {
        private _other = _x get "vehicle";

        if (((_x get "side") == _side) && {alive _other} && {_other isNotEqualTo _vehicle}) then {
            private _task = _other getVariable ["SC_var_aiDeliveryTask", []];

            _occupied pushBack ([getPosATL _other, _task select 0] select (_task isNotEqualTo []));
        };
    } forEach SC_var_spawnVehicleSlots;

    private _best = [];

    {
        private _requiredCover = _x;
        private _bestRating = -1;

        {
            _x params ["_pos", "_sectorInd", "_enemyPoints"];

            private _rating = [_pos, _sectorInd, _side, _isAir, _enemyPoints, _requiredCover] call SC_fnc_aiRateParkingSpot;

            if (_rating >= 0 && {_occupied isNotEqualTo []}) then {
                private _nearest = selectMin (_occupied apply {_x distance2D _pos});

                if (_nearest < _spacing) then {
                    _rating = -0.99 max (_rating - 3 * (1 - (_nearest / _spacing)));
                };
            };

            if (_rating > _bestRating) then {
                _best = [_pos, _rating, _sectorInd];
                _bestRating = _rating;
            };
        } forEach _candidates;

        if (_best isNotEqualTo []) exitWith {};
    } forEach [_minCover, _minCover / 3];

    _best
};

// distance from a position to the front: the edge of the nearest of a spawn vehicle's parking sectors (_anchors,
// SC_fnc_aiVehicleAnchors; 0 if there is none)
SC_fnc_aiFrontDistance = {
    params ["_pos", "_anchors"];

    private _distances = _anchors apply {
        private _marker = "SC_var_sector" + _x;
        (_pos distance2D (getMarkerPos _marker)) - (selectMax (getMarkerSize _marker))
    };

    if (_distances isEqualTo []) exitWith {0};

    0 max (selectMin _distances)
};

// how far (m) a parked spawn vehicle may stand from the front (SC_var_aiDeliveryFrontScale)
SC_fnc_aiDeliveryFrontLimit = {
    SC_var_aiDeliveryFrontScale params ["_spacings", "_fixed"];

    (_spacings * SC_var_aiSectorSpacing) + _fixed
};

// ---- planning ----

// why a spawn vehicle should be delivered ("" if not): it waits at the base, it was no respawn position for long
// (enemies near, in the water, outside the play zone, in an enemy base), or the front moved far away from it
SC_fnc_aiDeliveryReason = {
    params ["_vehicle", "_anchors"];

    private _state = _vehicle getVariable ["SC_var_spawnVehicleState", ""];

    if (_state == "at the base") exitWith {"base"};

    // a vehicle that can't drive any more is replaced by the spawn vehicle system
    if (!(canMove _vehicle) || {(fuel _vehicle) < 0.05} || {((vectorUp _vehicle) select 2) < SC_var_spawnVehicleMinUp}) exitWith {""};

    if (_state in ["", "moving", "recently hit"]) then {
        _vehicle setVariable ["SC_var_aiBlockedSince", -1];
    } else {
        if ((_vehicle getVariable ["SC_var_aiBlockedSince", -1]) < 0) then {
            _vehicle setVariable ["SC_var_aiBlockedSince", time];
        };
    };

    private _blockedSince = _vehicle getVariable ["SC_var_aiBlockedSince", -1];

    if ((_blockedSince >= 0) && {(time - _blockedSince) > SC_var_aiDeliveryBlockedTime}) exitWith {"blocked: " + _state};

    if (([getPosWorld _vehicle, _anchors] call SC_fnc_aiFrontDistance) > (call SC_fnc_aiDeliveryFrontLimit)) exitWith {"front moved"};

    ""
};

// The squad that fetches a spawn vehicle: the AI squad with a member nearest to it (within
// SC_var_aiDeliveryFetchDistance), that isn't in a fight and not busy (no player group, no other delivery, no repair);
// its members far away wait meanwhile. [squad, its nearest member] or [] if there is none.
SC_fnc_aiFindDeliverySquad = {
    params ["_vehicle", "_squads", ["_fetchDistance", SC_var_aiDeliveryFetchDistance]];

    private _best = [];
    private _bestDistance = _fetchDistance;

    {
        private _members = (units _x) select {(alive _x) && {simulationEnabled _x} && {!(_x getVariable ["AIS_unconscious", false])}};
        private _distances = _members apply {_x distance _vehicle};
        private _distance = selectMin (_distances + [1e9]);

        if (
            (_distance < _bestDistance) &&
            {((_x getVariable ["SC_var_aiDelivery", []]) isEqualTo [])} &&
            {isNil {_x getVariable "SC_var_aiRepair"}} &&
            {([_x] call SC_fnc_aiGetSquadPlayerPos) isEqualTo []}
        ) then {
            private _nearest = _members select (_distances find _distance);
            private _enemy = _nearest findNearestEnemy _nearest;

            if ((isNull _enemy) || {(_nearest distance _enemy) > 300}) then {
                _best = [_x, _nearest];
                _bestDistance = _distance;
            };
        };
    } forEach _squads;

    _best
};

// a squad takes over a delivery (_task: [spot, start time, reason, deadline]): its driver leads, it gives up its own
// vehicle and every other seat (a group with members ordered into another vehicle doesn't drive off)
SC_fnc_aiStartDelivery = {
    params ["_group", "_vehicle", "_driver", "_task"];

    private _squadVehicle = [_group] call SC_fnc_aiGetSquadVehicle;

    if !(isNull _squadVehicle) then {
        [_group, _squadVehicle, "delivery of a spawn vehicle"] call SC_fnc_aiReleaseVehicle;
    };

    {
        if !((assignedVehicle _x) in [objNull, _vehicle]) then {
            unassignVehicle _x;
        };
    } forEach (units _group);

    _group setVariable ["SC_var_aiDelivery", [_vehicle] + _task];
    _group selectLeader _driver;
    _group addVehicle _vehicle;

    // an invisible helipad at the spot: a helicopter ordered to land picks the nearest helipad
    if ((_vehicle isKindOf "Air") && {isNull (_vehicle getVariable ["SC_var_aiDeliveryPad", objNull])}) then {
        _vehicle setVariable ["SC_var_aiDeliveryPad", createVehicle ["Land_HelipadEmpty_F", _task select 0, [], 0, "CAN_COLLIDE"]];
    };
    _vehicle setVariable ["SC_var_aiDeliveryGroup", _group];
    _vehicle setVariable ["SC_var_aiDeliveryDriver", _driver];
    _vehicle setVariable ["SC_var_aiDeliveryTask", _task];
};

// Planning pass of a side (with the objective planning): every spawn vehicle of the side that needs a delivery and
// has none running gets the nearest free squad and a parking spot. A spawn vehicle at the base without a squad near it
// makes the next AI of the side that doesn't spawn with its squad spawn at the base (SC_fnc_spawnAi).
SC_fnc_aiPlanDeliveries = {
    params ["_side", "_squads"];

    private _driverWanted = false;

    {
        private _vehicle = _x;
        private _driverGroup = _vehicle getVariable ["SC_var_aiDeliveryGroup", grpNull];
        private _isRunning = !(isNull _driverGroup) && {((_driverGroup getVariable ["SC_var_aiDelivery", []]) param [0, objNull]) isEqualTo _vehicle};

        // the driver changed his squad (the squads form at the start of a round): the delivery goes with him
        private _driverUnit = _vehicle getVariable ["SC_var_aiDeliveryDriver", objNull];

        if (
            !_isRunning &&
            {alive _driverUnit} &&
            {!(isPlayer _driverUnit)} &&
            {(_driverUnit distance _vehicle) < SC_var_aiDeliveryFetchDistance} &&
            {((_vehicle getVariable ["SC_var_aiDeliveryTask", []]) isNotEqualTo [])} &&
            {((group _driverUnit) getVariable ["SC_var_aiDelivery", []]) isEqualTo []} &&
            {(((units (group _driverUnit)) findIf {isPlayer _x}) == -1)}
        ) then {
            _driverGroup = group _driverUnit;
            [_driverGroup, _vehicle, _driverUnit, (_vehicle getVariable "SC_var_aiDeliveryTask")] call SC_fnc_aiStartDelivery;
            _isRunning = true;
            ["delivery", _driverGroup, typeOf _vehicle, "taken over"] call SC_fnc_aiLog;
        };

        // a delivery of a squad that can't act any more (all members unconscious, ...) ends here
        if _isRunning then {
            (_driverGroup getVariable "SC_var_aiDelivery") params ["", "", "", "", "_deadline"];

            if (time > (_deadline + 60)) then {
                [_driverGroup, _vehicle, "failed: stalled"] call SC_fnc_aiEndDelivery;
                _isRunning = false;
            };
        };

        // the first time a delivered vehicle is a respawn position (debug log: seconds since the assignment)
        if (((_vehicle getVariable ["SC_var_spawnVehicleState", ""]) == "") && {(_vehicle getVariable ["SC_var_aiDeliveredSince", -1]) >= 0}) then {
            ["delivery", grpNull, typeOf _vehicle, "usable", round (time - (_vehicle getVariable "SC_var_aiDeliveredSince"))] call SC_fnc_aiLog;
            _vehicle setVariable ["SC_var_aiDeliveredSince", -1];
        };

        if (
            !_isRunning &&
            {((crew _vehicle) findIf {(alive _x) && {isPlayer _x}}) == -1} &&
            {time >= (_vehicle getVariable ["SC_var_aiDeliveryNext", 0])}
        ) then {
            private _anchors = [_vehicle, _side] call SC_fnc_aiVehicleAnchors;
            private _reason = [_vehicle, _anchors] call SC_fnc_aiDeliveryReason;

            if (_reason == "") exitWith {
                // a parked vehicle is checked again later, one at the base at every pass
                if ((_vehicle getVariable ["SC_var_spawnVehicleState", ""]) != "at the base") then {
                    _vehicle setVariable ["SC_var_aiDeliveryNext", time + SC_var_aiDeliveryCheckTime];
                };
            };

            private _fetcher = [_vehicle, _squads] call SC_fnc_aiFindDeliverySquad;

            if (_fetcher isEqualTo []) exitWith {
                if (_reason == "base") then {
                    _driverWanted = true;
                };
            };

            _fetcher params ["_squad", "_driver"];

            private _spot = [_vehicle, _side, _anchors] call SC_fnc_aiFindParkingSpot;

            if (_spot isEqualTo []) exitWith {
                _vehicle setVariable ["SC_var_aiDeliveryNext", time + SC_var_aiDeliveryRetryTime];
                ["delivery", _squad, typeOf _vehicle, "no parking spot", _reason] call SC_fnc_aiLog;
            };

            _spot params ["_destination", "_rating", "_sectorInd"];

            // a parked vehicle is only moved for a spot clearly closer to the front
            if (
                (_reason == "front moved") &&
                {([_destination,
                    _anchors] call SC_fnc_aiFrontDistance) >(([getPosWorld _vehicle,
                    _anchors] call SC_fnc_aiFrontDistance) -(0.5 *(call SC_fnc_aiDeliveryFrontLimit)))}
            ) exitWith {
                _vehicle setVariable ["SC_var_aiDeliveryNext", time + SC_var_aiDeliveryCheckTime];
            };

            // its sector from now on: the side's other spawn vehicles are sent to other sectors
            _vehicle setVariable ["SC_var_aiDeliverySector", _sectorInd];

            // the nearest member leads and drives
            [_squad, _vehicle, _driver,
                [_destination, time, _reason,
                time + SC_var_aiDeliveryTimeout +((_vehicle distance2D _destination) / 4)]] call
                SC_fnc_aiStartDelivery;
            [
                "delivery", _squad, typeOf _vehicle, "assigned", _reason, _sectorInd,
                (round (_rating * 100)) / 100, round (_vehicle distance2D _destination), _destination
            ] call SC_fnc_aiLog;
        };
    } forEach ([_side] call SC_fnc_getSideSpawnVehicles);

    // at most one AI per SC_var_aiDeliveryDriverInterval is sent to the base this way
    private _nextDriverVar = "SC_var_aiDeliveryNextDriver" + (str _side);

    if (_driverWanted && {time >= (missionNamespace getVariable [_nextDriverVar, 0])}) then {
        missionNamespace setVariable [("SC_var_aiDeliveryDriverWanted" + (str _side)), true];
        missionNamespace setVariable [_nextDriverVar, time + SC_var_aiDeliveryDriverInterval];
    };

    if !_driverWanted then {
        missionNamespace setVariable [("SC_var_aiDeliveryDriverWanted" + (str _side)), false];
    };
};

// ---- the delivering squad ----

// changes element _index of a running delivery (SC_var_aiDelivery of the squad: [vehicle, spot, start time, reason,
// deadline]) and of the vehicle's copy of the task (without the vehicle), so that a takeover keeps it
SC_fnc_aiUpdateDeliveryTask = {
    params ["_group", "_vehicle", "_index", "_value"];

    (_group getVariable ["SC_var_aiDelivery", []]) set [_index, _value];

    private _task = _vehicle getVariable ["SC_var_aiDeliveryTask", []];

    if (_task isNotEqualTo []) then {
        _task set [_index - 1, _value];
    };
};

// end of a delivery: the squad goes on with its objective, the vehicle waits for its next check (or, after a failure,
// for the next squad)
SC_fnc_aiEndDelivery = {
    params ["_group", "_vehicle", "_result"];

    (_group getVariable ["SC_var_aiDelivery", []]) params ["", ["_destination", getPosWorld _vehicle], ["_startTime", time]];

    _group setVariable ["SC_var_aiDelivery", nil];
    _group setVariable ["SC_var_aiLanding", nil];
    _group setVariable ["SC_var_aiDeliveryLeftBase", nil];

    if (_vehicle in (assignedVehicles _group)) then {
        _group leaveVehicle _vehicle;
    };

    {
        if (_x getVariable ["SC_var_aiDeliveryHold", false]) then {
            _x setVariable ["SC_var_aiDeliveryHold", nil];
            _x doFollow (leader _group);
        };
    } forEach (units _group);

    if ((_vehicle getVariable ["SC_var_aiDeliveryGroup", grpNull]) isEqualTo _group) then {
        _vehicle setVariable ["SC_var_aiDeliveryGroup", grpNull];
    };

    _vehicle setVariable ["SC_var_aiDeliveryDriver", objNull];
    _vehicle setVariable ["SC_var_aiDeliveryTask", []];
    deleteVehicle (_vehicle getVariable ["SC_var_aiDeliveryPad", objNull]);
    _vehicle setVariable ["SC_var_aiDeliveryPad", nil];

    if (_result == "delivered") then {
        _vehicle setVariable ["SC_var_aiDeliveryFailures", 0];
        _vehicle setVariable ["SC_var_aiDeliveryNext", time + SC_var_aiDeliveryCheckTime];
        _vehicle setVariable ["SC_var_aiDeliveredSince", _startTime];
    } else {
        // still at the base: it holds no sector for the side's other spawn vehicles
        if ((_vehicle getVariable ["SC_var_spawnVehicleState", ""]) == "at the base") then {
            _vehicle setVariable ["SC_var_aiDeliverySector", nil];
        };

        private _failures = (_vehicle getVariable ["SC_var_aiDeliveryFailures", 0]) + 1;
        _vehicle setVariable ["SC_var_aiDeliveryFailures", _failures];
        _vehicle setVariable ["SC_var_aiDeliveryNext", time + (SC_var_aiDeliveryMaxRetryTime min (SC_var_aiDeliveryRetryTime * (2 ^ (_failures - 1))))];
    };

    ["delivery", _group, typeOf _vehicle, _result, round (_vehicle distance2D _destination)] call SC_fnc_aiLog;
};

// One step of a delivering squad (instead of its normal state machine): board (the leader takes the driver / pilot
// seat), drive / fly to the spot, stop (a helicopter lands), everybody gets out. Players in the vehicle or a timeout
// end it; a helicopter in the air lands first.
SC_fnc_aiDoDelivery = {
    params ["_group", "_able", "_delivery"];
    _delivery params ["_vehicle", "_destination", "_startTime", "", "_deadline"];

    private _inside = _able select {(objectParent _x) isEqualTo _vehicle};

    // an unconscious leader is replaced by the able member nearest to the vehicle
    if !((leader _group) in _able) then {
        _group selectLeader (([_able, [], {_x distance _vehicle}, "ASCEND"] call BIS_fnc_sortBy) select 0);
    };

    // the leader (the driver) and the members close by board, the others wait where they are (in their vehicle too)
    // until the delivery ends
    private _boarding = _able select {(_x in _inside) || {_x isEqualTo (leader _group)} || {(_x distance _vehicle) < 100}};

    {
        if (!(_x getVariable ["SC_var_aiDeliveryHold", false]) && {isNull (_x getVariable ["AIS_isHelper", objNull])}) then {
            _x setVariable ["SC_var_aiDeliveryHold", true];
            doStop _x;
        };
    } forEach (_able - _boarding);
    private _isAir = _vehicle isKindOf "Air";
    private _landed = !_isAir || {(isTouchingGround _vehicle) && {(speed _vehicle) < 5}};

    // the first time it leaves the base: the time for the way starts now (a long boarding doesn't shorten it)
    if (
        (alive _vehicle) &&
        {!(_group getVariable ["SC_var_aiDeliveryLeftBase", false])} &&
        {(_vehicle getVariable ["SC_var_spawnVehicleState", ""]) != "at the base"}
    ) then {
        _group setVariable ["SC_var_aiDeliveryLeftBase", true];
        _deadline = _deadline max (time + SC_var_aiDeliveryWayTimeout + ((_vehicle distance2D _destination) / 4));
        [_group, _vehicle, 4, _deadline] call SC_fnc_aiUpdateDeliveryTask;
        ["delivery", _group, typeOf _vehicle, "left the base", round (time - _startTime)] call SC_fnc_aiLog;
    };

    private _failure = switch true do {
        case !(alive _vehicle): {"failed: destroyed"};
        // players riding along (spawned at a squad mate) don't stop the delivery, a player driving does
        case (isPlayer (driver _vehicle)): {"failed: player drives"};
        case (time > _deadline): {"failed: timeout"};
        default {""};
    };

    // a failure in the air: land where it is first
    if ((_failure != "") && {!_landed} && {alive _vehicle} && {(driver _vehicle) in _inside}) then {
        if (isNil {_group getVariable "SC_var_aiLanding"}) then {
            _vehicle land "LAND";
            _group setVariable ["SC_var_aiLanding", time];
        };

        _failure = "";
    };

    if (_failure != "") exitWith {
        if ((_inside isNotEqualTo []) && {_landed}) then {
            [_group, _vehicle, false, _failure] call SC_fnc_aiDismount;
        };

        [_group, _vehicle, _failure] call SC_fnc_aiEndDelivery;
    };

    // arrived: the vehicle stands at its spot off the road (a helicopter landed after the landing order), or stands
    // still off the road near it after the squad tried again
    if (
        ((driver _vehicle) in _inside) &&
        {(abs (speed _vehicle)) < 2} &&
        {
            if _isAir then {
                ((_vehicle distance2D _destination) < (SC_var_aiDeliveryArrivalDistance select 1)) &&
                {_landed && {!(isNil {_group getVariable "SC_var_aiLanding"})}}
            } else {
                !([getPosATL _vehicle, 3] call SC_fnc_aiIsNearRoad) &&
                {
                    ((_vehicle distance2D _destination) < (SC_var_aiDeliveryArrivalDistance select 0)) ||
                    {
                        ((_vehicle distance2D _destination) < SC_var_aiDeliveryNearDistance) &&
                        {((_group getVariable ["SC_var_aiStuckCheck", [0, [0, 0, 0], 0]]) select 2) > 0}
                    }
                }
            }
        }
    ) exitWith {
        [_group, _vehicle, false, "delivered"] call SC_fnc_aiDismount;
        [_group, _vehicle, "delivered"] call SC_fnc_aiEndDelivery;
    };

    private _boarders = _boarding - (_group getVariable ["SC_var_aiLeftBehind", []]);

    // boarding (the timeout of SC_fnc_aiDoBoard also finds a driver among the passengers)
    if (!((driver _vehicle) in _inside) || {(_boarders findIf {!(_x in _inside)}) != -1}) exitWith {
        [_group, _vehicle, _boarding, _inside, "DELIVERBOARD"] call SC_fnc_aiDoBoard;
        [_group, "DELIVERBOARD"] call SC_fnc_aiSetState;
    };

    // a ground vehicle that got close but stands on or at a road (the driver doesn't get to the spot itself): a free
    // place off the road next to it becomes the spot
    if (
        !_isAir &&
        {(abs (speed _vehicle)) < 2} &&
        {(_vehicle distance2D _destination) < SC_var_aiDeliveryNearDistance} &&
        {((_group getVariable ["SC_var_aiStuckCheck", [0, [0, 0, 0], 0]]) select 2) > 0}
    ) then {
        private _spot = [getPosATL _vehicle, typeOf _vehicle] call SC_fnc_aiFindOffRoadSpot;

        if (_spot isNotEqualTo []) then {
            _destination = _spot;
            [_group, _vehicle, 1, _spot] call SC_fnc_aiUpdateDeliveryTask;
            _group setVariable ["SC_var_aiStuckCheck", nil];
            ["delivery", _group, typeOf _vehicle, "spot moved off the road", round (_vehicle distance2D _spot)] call SC_fnc_aiLog;
        };
    };

    // driving / flying to the spot
    private _driver = driver _vehicle;

    if ((leader _group) isNotEqualTo _driver) then {
        _group selectLeader _driver;
    };

    if ((_group getVariable ["SC_var_aiState", ""]) != "DELIVER") then {
        _group setVariable ["SC_var_aiStuckCheck", nil];
        _group setVariable ["SC_var_aiLanding", nil];
    };

    // a ground vehicle drives to the road nearest to its spot first: the spot lies off the road in cover, where the
    // engine's route planning often finds no way from far away (the driver never starts), but it does to a road; from
    // there on to the spot itself
    private _waypointPos = _destination;

    if (!_isAir) then {
        private _roadPos = [_destination, _destination, 0] call SC_fnc_aiRoadNear;

        if ((_vehicle distance2D _destination) > ((_roadPos distance2D _destination) + SC_var_aiDeliveryNearDistance)) then {
            _waypointPos = _roadPos;
        };
    };

    [_group, _waypointPos] call SC_fnc_aiSetWaypoint;

    // a ground vehicle drives right up to its spot (not only into the usual 40 m around it, mostly a road)
    if (!_isAir && {(currentWaypoint _group) < (count (waypoints _group))}) then {
        [_group, currentWaypoint _group] setWaypointCompletionRadius 5;
    };

    [_group, SC_var_aiStanceTravel, true] call SC_fnc_aiSetStance;
    [units _group, false] call SC_fnc_aiSetAutoCombat;
    [_group, "DELIVER"] call SC_fnc_aiSetState;

    if _isAir then {
        _vehicle flyInHeight 60;

        // a helicopter that doesn't take off counts as stuck as well
        if ((isTouchingGround _vehicle) && {isNil {_group getVariable "SC_var_aiLanding"}}) then {
            _vehicle engineOn true;

            if !([_group, _vehicle, _destination] call SC_fnc_aiCheckStuck) then {
                [_group, _vehicle, "failed: stuck"] call SC_fnc_aiEndDelivery;
            };
        };

        if (((_vehicle distance2D _destination) < 250) && {isNil {_group getVariable "SC_var_aiLanding"}}) then {
            _vehicle land "LAND";
            _group setVariable ["SC_var_aiLanding", time];
        };
    } else {
        // stuck for good: the squad gets out (SC_fnc_aiAbandonVehicle), the delivery fails
        if !([_group, _vehicle, _destination] call SC_fnc_aiCheckStuck) then {
            [_group, _vehicle, "failed: stuck"] call SC_fnc_aiEndDelivery;
        };
    };
};

// ---- attacking enemy spawn vehicles ----
// AI with a launcher destroy enemy spawn vehicles (trucks, helicopters) they see, also empty ones (user 2026-11-26).
// The AI does not target empty vehicles by itself (they are no enemies): the nearest AI on foot with a loaded launcher
// that sees one gets it as an order (doTarget + doFire: tested, an RPG destroys an empty truck in ~15 s) until it is
// destroyed, out of reach or SC_var_aiHuntTimeout has passed, then it returns to its squad. Spawn vehicles in a base and
// the AI of players' groups are left alone. One hunter per vehicle (server).

SC_var_aiHuntRange = 400;           // m, unguided launchers
SC_var_aiHuntRangeGuided = 800;     // m, launchers that lock on (Titan, PCML, ...)
SC_var_aiHuntTimeout = 40;          // s per order
SC_var_aiHuntInterval = 5;          // s between two passes

SC_fnc_aiHuntRange = {
    params ["_launcher"];

    [SC_var_aiHuntRange, SC_var_aiHuntRangeGuided] select ((getNumber (configFile >> "CfgWeapons" >> _launcher >> "canLock")) > 0)
};

SC_fnc_aiCanHunt = {
    params ["_unit"];

    private _launcher = secondaryWeapon _unit;

    (alive _unit) && {!(isPlayer _unit)} && {simulationEnabled _unit} && {isNull (objectParent _unit)} &&
        {_launcher != ""} && {!(_unit getVariable ["AIS_unconscious", false])} &&
        {((units (group _unit)) findIf {isPlayer _x}) == -1} &&
        {((_unit ammo _launcher) > 0) || {((magazines _unit) arrayIntersect (compatibleMagazines _launcher)) isNotEqualTo []}}
};

SC_fnc_aiHuntLoop = {
    waitUntil {
        sleep SC_var_aiHuntInterval;

        {
            private _vehicle = _x get "vehicle";
            private _owner = _x get "side";
            private _hunter = _vehicle getVariable ["SC_var_aiHunter", objNull];
            private _inBase = (SC_var_sides findIf {_vehicle inArea ("SC_var_" + toLower (str _x) + "Base")}) != -1;

            // a running order: kept while it can still work
            if (!(isNull _hunter) && {
                !(alive _vehicle) || {_inBase} || {!([_hunter] call SC_fnc_aiCanHunt)} ||
                {time > (_hunter getVariable ["SC_var_aiHuntUntil", 0])} ||
                {(_hunter distance _vehicle) > ([secondaryWeapon _hunter] call SC_fnc_aiHuntRange)}
            }) then {
                _hunter doWatch objNull;
                _hunter doFollow (leader (group _hunter));
                _hunter setVariable ["SC_var_aiHuntTarget", nil];
                _vehicle setVariable ["SC_var_aiHunter", nil];
                _hunter = objNull;
            };

            if ((alive _vehicle) && {!_inBase} && {isNull _hunter}) then {
                private _pos = getPosATL _vehicle;
                private _candidates = (_pos nearEntities [["CAManBase"], SC_var_aiHuntRangeGuided]) select {
                    (side (group _x)) != _owner && {(side (group _x)) in SC_var_sides} &&
                        {isNull (_x getVariable ["SC_var_aiHuntTarget", objNull])} &&
                        {[_x] call SC_fnc_aiCanHunt} &&
                        {(_x distance _vehicle) <= ([secondaryWeapon _x] call SC_fnc_aiHuntRange)} &&
                        {([_vehicle, "VIEW", _x] checkVisibility [eyePos _x, aimPos _vehicle]) > 0.3}
                };

                if (_candidates isNotEqualTo []) then {
                    private _unit = ([_candidates, [], {_x distance _vehicle}, "ASCEND"] call BIS_fnc_sortBy) select 0;

                    _vehicle setVariable ["SC_var_aiHunter", _unit];
                    _unit setVariable ["SC_var_aiHuntTarget", _vehicle];
                    _unit setVariable ["SC_var_aiHuntUntil", time + SC_var_aiHuntTimeout];
                    _unit selectWeapon (secondaryWeapon _unit);
                    _unit doWatch _vehicle;
                    _unit doTarget _vehicle;
                    _unit doFire _vehicle;
                    ["huntSpawnVehicle", group _unit, typeOf _vehicle, round (_unit distance _vehicle)] call SC_fnc_aiLog;
                };
            };

            // the order is repeated every pass (the AI drops a fire order once it reloaded)
            if (!(isNull _hunter) && {alive _vehicle}) then {
                _hunter doTarget _vehicle;
                _hunter doFire _vehicle;
            };
        } forEach ((missionNamespace getVariable ["SC_var_spawnVehicleSlots", []]) select {alive (_x get "vehicle")});

        false
    };
};
