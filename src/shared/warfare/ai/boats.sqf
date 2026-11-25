// AI boats (whole-map maps with harbours, SC\vehicles\harbors.sqf): a squad whose objective lies on another land mass
// than itself (an island) goes to a harbour of its own land mass (on foot or by land vehicle), gets a free boat there
// or has one spawned (within the side's AI vehicle budget), sails to a landing point at the objective's coast and gets
// out there. Helicopters cross the water as before (server).

// ---- constants ----

SC_var_aiLandCell = 100;          // m: cell of the land mass grid
SC_var_aiHarborReach = 60;        // m from a harbour's shop where a squad gets its boat
SC_var_aiLandingDepth = 1;        // m the sea floor at a landing point lies below sea level
SC_var_aiLandingRange = 2500;     // m from an objective the landing point may lie
SC_var_aiBoatSeats = 12;          // seats a boat spawned for the AI has at least (if its rank allows): other teams at the
                                  // harbour ride along (SC_fnc_aiJoinRide), the boat waits for them (SC_fnc_aiGathers)

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

    SC_var_aiLandGrid = _grid;
    SC_var_aiSectorLandmass = createHashMap;
    SC_var_aiLandmassesReady = true;
    diag_log format ["SC: %1 land masses (%2 m grid)", _nextId - 1, SC_var_aiLandCell];
};

// land mass id at a position (the nearest land cell within 3 cells for a point on the shore), -1 if none / not ready
SC_fnc_aiLandmassAt = {
    params ["_pos"];

    if !(missionNamespace getVariable ["SC_var_aiLandmassesReady", false]) exitWith {-1};

    private _cells = count SC_var_aiLandGrid;
    private _cx = floor ((_pos select 0) / SC_var_aiLandCell);
    private _cy = floor ((_pos select 1) / SC_var_aiLandCell);
    private _result = -1;

    for "_ring" from 0 to 3 do {
        for "_dx" from -_ring to _ring do {
            for "_dy" from -_ring to _ring do {
                private _gx = _cx + _dx;
                private _gy = _cy + _dy;

                if ((_result == -1) && {_gx >= 0} && {_gy >= 0} && {_gx < _cells} && {_gy < _cells}) then {
                    _result = (SC_var_aiLandGrid select _gx) select _gy;
                };
            };
        };

        if (_result != -1) exitWith {};
    };

    _result
};

// ---- boats ----

// index of the harbour a squad goes to for a boat (-1: its objective is on its own land mass, or there is no harbour on
// its land mass): the one with the shortest way leader -> harbour -> objective (SC_var_aiHarbor of the group)
SC_fnc_aiBoatHarbor = {
    params ["_group", "_target"];

    private _harbor = -1;

    if (missionNamespace getVariable ["SC_var_aiLandmassesReady", false]) then {
        private _center = (SC_var_aiSectorInfo get _target) select 0;
        private _targetLand = SC_var_aiSectorLandmass getOrDefault [_target, -2];

        if (_targetLand == -2) then {
            _targetLand = [_center] call SC_fnc_aiLandmassAt;
            SC_var_aiSectorLandmass set [_target, _targetLand];
        };

        private _leader = leader _group;
        private _ownLand = [getPosWorld _leader] call SC_fnc_aiLandmassAt;

        if ((_ownLand != -1) && {_targetLand != -1} && {_ownLand != _targetLand}) then {
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

    _group setVariable ["SC_var_aiNextVehicleRequest", time + 60];

    private _type = [(_leader getVariable ["SC_var_rank", 1]), (count _able) max SC_var_aiBoatSeats] call SC_fnc_aiPickBoatType;

    if (_type == "") exitWith {};

    ["vehicle", _group, _type, "requested", _name] call SC_fnc_aiLog;
    [_leader, _name, _type] call SC_fnc_aiQueueVehicle;
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
