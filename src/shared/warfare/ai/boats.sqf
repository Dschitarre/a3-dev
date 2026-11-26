// AI boats (whole-map maps with harbours, SC\vehicles\harbors.sqf): a squad whose objective lies on another land mass
// than itself (an island; land masses joined by a bridge are one) goes to a harbour of its own land mass (on foot or by
// land vehicle), gets a free boat there or has one spawned (within the side's AI vehicle budget) and sails to whichever
// is faster (SC_fnc_aiBoatDestination): a landing point at the objective's coast, from where it walks, or a harbour of
// the objective's land mass, where it gets a vehicle or helicopter and goes on with it. Helicopters cross the water as
// before (server).

// ---- constants ----

SC_var_aiLandCell = 100;          // m: cell of the land mass grid
SC_var_aiHarborReach = 60;        // m from a harbour's shop where a squad gets its boat
SC_var_aiLandingDepth = 1;        // m the sea floor at a landing point lies below sea level
SC_var_aiLandingRange = 2500;     // m from an objective the landing point may lie
SC_var_aiBoatSeats = 12;          // seats a boat spawned for the AI has at least (if its rank allows): other teams at the
                                  // harbour ride along (SC_fnc_aiJoinRide), the boat waits for them (SC_fnc_aiGathers)
SC_var_aiBridgeGap = 40;          // m between two road ends that count as joined (the engine leaves a few gaps at bridges)

// travel time estimate of SC_fnc_aiBoatDestination: speeds (m/s, straight line) by boat, on foot and by vehicle, and
// the seconds from the arrival at a harbour until the vehicle spawned there departs
SC_var_aiBoatSpeed = 12;
SC_var_aiWalkSpeed = 1.5;
SC_var_aiDriveSpeed = 8;
SC_var_aiHarborVehicleDelay = 90;

// a boat route is estimated along the straight line: its land parts (sampled every SC_var_aiSeaStep m) count
// SC_var_aiSeaDetour times (the boat sails around the island; a harbour on its far side is no shortcut)
SC_var_aiSeaStep = 50;
SC_var_aiSeaDetour = 3;

// ---- land masses ----

// server, background (after the harbours are known): land mass id of every land cell of the island (4-neighbour flood
// fill over a grid of SC_var_aiLandCell m), SC_var_aiLandGrid: rows of ids (-1 water); SC_var_aiLandmassesReady
SC_fnc_aiBuildLandmasses = {
    SC_var_aiLandmassesReady = false;

    waitUntil {sleep 1; missionNamespace getVariable ["SC_var_harborsReady", false]};

    if (SC_var_harbors isEqualTo []) exitWith {};

    private _cells = ceil (worldSize / SC_var_aiLandCell);
    private _grid = [];

    for "_gx" from 0 to (_cells - 1) do {
        private _row = [];

        for "_gy" from 0 to (_cells - 1) do {
            _row pushBack ([-1, 0] select !(surfaceIsWater [(_gx + 0.5) * SC_var_aiLandCell, (_gy + 0.5) * SC_var_aiLandCell]));
        };

        _grid pushBack _row;

        if ((_gx mod 20) == 0) then {sleep 0.01};
    };

    // 0: land without an id yet
    private _nextId = 1;

    for "_gx" from 0 to (_cells - 1) do {
        for "_gy" from 0 to (_cells - 1) do {
            if (((_grid select _gx) select _gy) == 0) then {
                private _queue = [[_gx, _gy]];

                (_grid select _gx) set [_gy, _nextId];

                for "_k" from 0 to 1e9 do {
                    if (_k >= (count _queue)) exitWith {};

                    (_queue select _k) params ["_cx", "_cy"];

                    {
                        _x params ["_nx", "_ny"];

                        if ((_nx >= 0) && {_ny >= 0} && {_nx < _cells} && {_ny < _cells} && {((_grid select _nx) select _ny) == 0}) then {
                            (_grid select _nx) set [_ny, _nextId];
                            _queue pushBack [_nx, _ny];
                        };
                    } forEach [[_cx + 1, _cy], [_cx - 1, _cy], [_cx, _cy + 1], [_cx, _cy - 1]];
                };

                _nextId = _nextId + 1;
            };
        };

        if ((_gx mod 20) == 0) then {sleep 0.01};
    };

    // Land masses joined by roads (bridges) are one: the AI drives across. Union-find over the land mass ids and the
    // roads (node _nextId + road index): a road belongs to the land mass it stands on (the nearest one for a road on
    // the shore, none for one far out on a bridge) and to the roads connected to it (the engine's connections and roads
    // closer than SC_var_aiBridgeGap m).
    private _half = worldSize / 2;
    private _roads = [_half, _half] nearRoads (worldSize * 0.75);
    private _roadIndex = createHashMap;
    private _parent = [];

    {
        _roadIndex set [str _x, _forEachIndex];
    } forEach _roads;

    for "_i" from 0 to (_nextId + (count _roads) - 1) do {
        _parent pushBack _i;
    };

    private _root = {
        params ["_node"];

        private _top = _node;

        while {(_parent select _top) != _top} do {
            _top = _parent select _top;
        };

        // path compression
        while {(_parent select _node) != _top} do {
            private _next = _parent select _node;
            _parent set [_node, _top];
            _node = _next;
        };

        _top
    };

    private _join = {
        params ["_a", "_b"];

        private _rootA = [_a] call _root;
        private _rootB = [_b] call _root;

        if (_rootA != _rootB) then {
            // a land mass id stays the root (the grid keeps its ids)
            if (_rootB < _nextId) then {
                _parent set [_rootA, _rootB];
            } else {
                _parent set [_rootB, _rootA];
            };
        };
    };

    {
        private _node = _nextId + _forEachIndex;
        private _pos = getPosWorld _x;
        private _land = [_grid, _pos] call SC_fnc_aiLandmassInGrid;

        if (_land > 0) then {
            [_node, _land] call _join;
        };

        {
            private _other = _roadIndex getOrDefault [str _x, -1];

            if (_other != -1) then {
                [_node, _nextId + _other] call _join;
            };
        } forEach ((roadsConnectedTo [_x, true]) + (_pos nearRoads SC_var_aiBridgeGap));

        if ((_forEachIndex mod 200) == 0) then {sleep 0.01};
    } forEach _roads;

    private _landmasses = [];

    {
        private _row = _x;

        {
            if (_x > 0) then {
                private _id = [_x] call _root;

                _row set [_forEachIndex, _id];
                _landmasses pushBackUnique _id;
            };
        } forEach _row;
    } forEach _grid;

    SC_var_aiLandGrid = _grid;
    SC_var_aiSectorLandmass = createHashMap;
    SC_var_aiLandmassesReady = true;
    diag_log format ["SC: %1 land masses (%2 m grid, %3 before the bridges)", count _landmasses, SC_var_aiLandCell, _nextId - 1];
};

// land mass id at a position (the nearest land cell within 3 cells for a point on the shore), -1 if none / not ready
SC_fnc_aiLandmassAt = {
    params ["_pos"];

    if !(missionNamespace getVariable ["SC_var_aiLandmassesReady", false]) exitWith {-1};

    [SC_var_aiLandGrid, _pos] call SC_fnc_aiLandmassInGrid
};

SC_fnc_aiLandmassInGrid = {
    params ["_grid", "_pos"];

    private _cells = count _grid;
    private _cx = floor ((_pos select 0) / SC_var_aiLandCell);
    private _cy = floor ((_pos select 1) / SC_var_aiLandCell);
    private _result = -1;

    // the ring of the first land cells, and of them the one whose center is nearest to _pos (not the first one found:
    // a sliver of land next to the shore point must not win over the land it belongs to)
    for "_ring" from 0 to 3 do {
        private _best = 1e9;

        for "_dx" from -_ring to _ring do {
            for "_dy" from -_ring to _ring do {
                private _gx = _cx + _dx;
                private _gy = _cy + _dy;

                if ((((abs _dx) max (abs _dy)) == _ring) && {_gx >= 0} && {_gy >= 0} && {_gx < _cells} && {_gy < _cells}) then {
                    private _id = (_grid select _gx) select _gy;
                    private _distance = _pos distance2D [(_gx + 0.5) * SC_var_aiLandCell, (_gy + 0.5) * SC_var_aiLandCell];

                    if ((_id != -1) && {_distance < _best}) then {
                        _best = _distance;
                        _result = _id;
                    };
                };
            };
        };

        if (_result != -1) exitWith {};
    };

    _result
};

// ---- boats ----

// land mass id of an objective (cached), -1 if none / not ready: the one with the most land cells in the sector (its
// center can lie on the shore or on a sliver of land; Tanoa's Koumac), else the one at its center
SC_fnc_aiTargetLandmass = {
    params ["_target"];

    if !(missionNamespace getVariable ["SC_var_aiLandmassesReady", false]) exitWith {-1};

    private _targetLand = SC_var_aiSectorLandmass getOrDefault [_target, -2];

    if (_targetLand == -2) then {
        (SC_var_aiSectorInfo get _target) params ["_center", "_radius"];

        private _counts = createHashMap;
        private _reach = _radius max SC_var_aiLandCell;
        private _cells = count SC_var_aiLandGrid;

        for "_gx" from (floor (((_center select 0) - _reach) / SC_var_aiLandCell)) to (floor (((_center select 0) + _reach) / SC_var_aiLandCell)) do {
            for "_gy" from (floor (((_center select 1) - _reach) / SC_var_aiLandCell)) to (floor (((_center select 1) + _reach) / SC_var_aiLandCell)) do {
                if (
                    (_gx >= 0) && {_gy >= 0} && {_gx < _cells} && {_gy < _cells} &&
                    {(_center distance2D [(_gx + 0.5) * SC_var_aiLandCell, (_gy + 0.5) * SC_var_aiLandCell]) <= _reach}
                ) then {
                    private _id = (SC_var_aiLandGrid select _gx) select _gy;

                    if (_id != -1) then {
                        _counts set [_id, (_counts getOrDefault [_id, 0]) + 1];
                    };
                };
            };
        };

        _targetLand = if ((count _counts) == 0) then {[_center] call SC_fnc_aiLandmassAt} else {
            private _ids = keys _counts;
            private _sizes = _ids apply {_counts get _x};

            _ids select (_sizes find (selectMax _sizes))
        };
        SC_var_aiSectorLandmass set [_target, _targetLand];
    };

    _targetLand
};

// whether a squad can wade or swim to its objective on another land mass: the straight line from its leader to the
// objective's center crosses at most SC_var_aiSwimGap m of water (sampled every SC_var_aiSwimStep m; a sector on a
// small island right off the coast). Cached per squad, objective and land mass of the leader.
SC_var_aiSwimGap = 150;
SC_var_aiSwimStep = 20;

SC_fnc_aiCanSwimAcross = {
    params ["_group", "_target", "_ownLand", "_center"];

    (_group getVariable ["SC_var_aiSwimCheck", []]) params [["_checkTarget", ""], ["_checkLand", -2], ["_result", false]];

    if ((_checkTarget != _target) || {_checkLand != _ownLand}) then {
        private _from = getPosWorld (leader _group);
        private _length = _from distance2D _center;
        private _water = 0;

        for "_d" from 0 to _length step SC_var_aiSwimStep do {
            if (surfaceIsWater (_from getPos [_d, _from getDir _center])) then {
                _water = _water + SC_var_aiSwimStep;
            };

            if (_water > SC_var_aiSwimGap) exitWith {};
        };

        _result = _water <= SC_var_aiSwimGap;
        _group setVariable ["SC_var_aiSwimCheck", [_target, _ownLand, _result]];
    };

    _result
};

// whether a squad's leader is on its objective's land mass (a squad that came by boat is across)
SC_fnc_aiOnTargetLandmass = {
    params ["_group", "_target"];

    private _targetLand = [_target] call SC_fnc_aiTargetLandmass;

    (_targetLand != -1) && {([getPosWorld (leader _group)] call SC_fnc_aiLandmassAt) == _targetLand}
};

// index of the harbour a squad goes to for a boat (-1: its objective is on its own land mass, or there is no harbour on
// its land mass): the one with the shortest way leader -> harbour -> objective (SC_var_aiHarbor of the group)
SC_fnc_aiBoatHarbor = {
    params ["_group", "_target"];

    private _harbor = -1;

    if (missionNamespace getVariable ["SC_var_aiLandmassesReady", false]) then {
        private _center = (SC_var_aiSectorInfo get _target) select 0;
        private _targetLand = [_target] call SC_fnc_aiTargetLandmass;
        private _leader = leader _group;
        private _ownLand = [getPosWorld _leader] call SC_fnc_aiLandmassAt;

        if ((_ownLand != -1) && {_targetLand != -1} && {_ownLand != _targetLand} && {!([_group, _target, _ownLand, _center] call SC_fnc_aiCanSwimAcross)}) then {
            private _best = 1e9;

            {
                private _shopPos = getPosWorld (_x select 1);

                if (([_shopPos] call SC_fnc_aiLandmassAt) == _ownLand) then {
                    private _way = (_leader distance2D _shopPos) + ((_x select 2) distance2D _center);

                    if (_way < _best) then {
                        _best = _way;
                        _harbor = _forEachIndex;
                    };
                };
            } forEach SC_var_harbors;
        };
    };

    _group setVariable ["SC_var_aiHarbor", _harbor];
    _harbor
};

// the boat type for _size units with rank _rank: the smallest one with a seat for everybody that isn't oversized (at
// most twice the seats: a big landing craft like the LCVP gets stuck at the harbour, AI drive it badly), else the one
// with the most seats of those, else the smallest one with a seat for everybody; "" if none
SC_fnc_aiPickBoatType = {
    params ["_rank", "_size"];

    private _boats = (SC_var_availableVehicles select {((_x select 0) isKindOf "Ship") && {(_x select 1) <= _rank}}) apply {
        [_x select 0, (([_x select 0] call SC_fnc_aiSeatCounts) select 0)]
    };

    if (_boats isEqualTo []) exitWith {""};

    _boats = [_boats, [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy;

    private _handy = _boats select {(_x select 1) <= (2 * _size)};
    private _fitting = _handy select {(_x select 1) >= _size};

    if (_fitting isNotEqualTo []) exitWith {(_fitting select 0) select 0};
    if (_handy isNotEqualTo []) exitWith {(_handy select -1) select 0};

    ((_boats select {(_x select 1) >= _size}) param [0, _boats select -1]) select 0
};

// a squad at its harbour without a vehicle: a free boat there, else one spawned for it (like SC_fnc_aiRequestVehicle)
SC_fnc_aiGetBoat = {
    params ["_group", "_able", "_harbor"];

    (SC_var_harbors select _harbor) params ["_name", "_shop", "_spawnPos"];

    private _leader = leader _group;

    if ((_leader distance2D _shop) > SC_var_aiHarborReach) exitWith {};

    private _seatsNeeded = [count _able] call SC_fnc_aiSeatsNeeded;
    private _free = (_spawnPos nearEntities [["Ship"], 150]) select {
        ([_x, _group] call SC_fnc_aiIsVehicleUsable) &&
        {!([_x, _group] call SC_fnc_aiIsReservedByOther)} &&
        {({isNull (_x select 0)} count (fullCrew [_x, "", true])) >= _seatsNeeded}
    };

    if (_free isNotEqualTo []) exitWith {
        [_group, _free select 0, "boat at harbour"] call SC_fnc_aiReserveVehicle;
    };

    if (time < (_group getVariable ["SC_var_aiNextVehicleRequest", 0])) exitWith {};
    if ([_leader, SC_var_aiSeenDistance] call SC_fnc_aiIsSeenByPlayers) exitWith {};

    // within the side's AI vehicle budget, like the other vehicles (SC_fnc_aiPickVehicleType): the squad waits for a
    // boat of another team or a free place in the budget
    if !([side _group] call SC_fnc_aiCanSpawnVehicle) exitWith {};

    _group setVariable ["SC_var_aiNextVehicleRequest", time + 60];

    private _type = [(_leader getVariable ["SC_var_rank", 1]), (count _able) max SC_var_aiBoatSeats] call SC_fnc_aiPickBoatType;

    if (_type == "") exitWith {};

    ["vehicle", _group, _type, "requested", _name] call SC_fnc_aiLog;
    [_leader, _name, _type] call SC_fnc_aiQueueVehicle;
};

// Where a boat at _from sails for objective _target: the faster way by the estimate of SC_var_aiBoatSpeed etc. of
// a landing point at the objective's coast (SC_fnc_aiLandingPoint) and the walk from there, or a harbour with a vehicle
// spawn point on the objective's land mass (its berth: the landing point nearest to its shop), the wait for a vehicle
// there and the drive. [destination, harbour name ("" for the landing point)]
SC_fnc_aiBoatDestination = {
    params ["_target", "_from"];

    private _center = (SC_var_aiSectorInfo get _target) select 0;
    private _landing = [_center, _from] call SC_fnc_aiLandingPoint;
    private _result = [[_landing, _center] select (_landing isEqualTo []), ""];
    private _best = if (_landing isEqualTo []) then {1e9} else {
        (([_from, _landing] call SC_fnc_aiSeaDistance) / SC_var_aiBoatSpeed) + ((_landing distance2D _center) / SC_var_aiWalkSpeed)
    };
    private _targetLand = [_target] call SC_fnc_aiTargetLandmass;

    if (_targetLand == -1) exitWith {_result};

    {
        _x params ["_name", "_shop", "_spawnPos", "", ["_vehiclePos", []]];

        private _shopPos = getPosWorld _shop;
        private _rest = SC_var_aiHarborVehicleDelay + ((_shopPos distance2D _center) / SC_var_aiDriveSpeed);

        if (
            (_vehiclePos isNotEqualTo []) &&
            {((_from distance2D _spawnPos) / SC_var_aiBoatSpeed) + _rest < _best} &&
            {([_shopPos] call SC_fnc_aiLandmassAt) == _targetLand}
        ) then {
            private _time = (([_from, _spawnPos] call SC_fnc_aiSeaDistance) / SC_var_aiBoatSpeed) + _rest;
            private _berth = if (_time < _best) then {[_shopPos, _from] call SC_fnc_aiLandingPoint} else {[]};

            if (_berth isNotEqualTo []) then {
                _best = _time;
                _result = [_berth, _name];
            };
        };
    } forEach SC_var_harbors;

    _result
};

// estimated length (m) of a boat route from _from to _to: the straight line, its land parts SC_var_aiSeaDetour times
SC_fnc_aiSeaDistance = {
    params ["_from", "_to"];

    private _length = _from distance2D _to;
    private _direction = _from getDir _to;
    private _land = 0;

    for "_d" from SC_var_aiSeaStep to (_length - SC_var_aiSeaStep) step SC_var_aiSeaStep do {
        if !(surfaceIsWater (_from getPos [_d, _direction])) then {
            _land = _land + SC_var_aiSeaStep;
        };
    };

    _length + ((SC_var_aiSeaDetour - 1) * _land)
};

// a boat's landing point: water SC_var_aiLandingDepth m deep nearest to the objective's center (within
// SC_var_aiLandingRange m), [] if there is none
SC_fnc_aiLandingPoint = {
    params ["_center", "_from"];

    private _result = [];

    for "_ring" from 25 to SC_var_aiLandingRange step 25 do {
        private _best = 1e9;

        for "_dir" from 0 to 350 step 10 do {
            private _pos = _center getPos [_ring, _dir];

            if ((surfaceIsWater _pos) && {(getTerrainHeightASL _pos) < -SC_var_aiLandingDepth} && {(_pos distance2D _from) < _best}) then {
                _best = _pos distance2D _from;
                _result = [_pos select 0, _pos select 1, 0];
            };
        };

        if (_result isNotEqualTo []) exitWith {};
    };

    _result
};
