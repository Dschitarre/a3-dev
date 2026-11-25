// Battle Royale landmasses (server): the connected pieces of land in the play area, labelled once per match on a grid of
// land/water samples (4-neighbour flood fill). The AI picks its zone spot on a landmass it can reach (or on the largest
// piece of the zone, which it then crosses to), takes cars only on its own landmass and boats to another one; boats are
// placed along the coast cells of the grid.

BR_var_landCellsMax = 320;              // grid cells per side at most (whole Altis: ~100 m cells) ...
BR_var_landCellMin = 40;                // ... and never finer than this many metres
BR_var_landChunkCells = 2500;           // cells per unscheduled step while building (no server hitch)
BR_var_landCircleSamples = 4000;        // grid cells sampled at most to measure the land of a zone circle

// scheduled: builds BR_var_landmasses [originX, originY, cell, size, labels, sizes, coastCells] for the play area.
// labels: landmass index per cell (row-major), -2 water; sizes: cells per landmass; coastCells: land cells next to water
BR_fnc_buildLandmasses = {
    private _startTime = diag_tickTime;
    private _radius = BR_var_playAreaRadius;
    private _cell = BR_var_landCellMin max (2 * _radius / BR_var_landCellsMax);
    private _size = ceil (2 * _radius / _cell);
    private _ox = (BR_var_playAreaCenter select 0) - _radius;
    private _oy = (BR_var_playAreaCenter select 1) - _radius;
    private _count = _size * _size;
    private _labels = [];
    private _rowsPerStep = 1 max floor (BR_var_landChunkCells / _size);
    private _row = 0;

    // land (-1, not yet labelled) or water (-2) at each cell centre
    while {_row < _size} do {
        isNil {
            for "_r" from _row to ((_row + _rowsPerStep - 1) min (_size - 1)) do {
                private _y = _oy + (_r + 0.5) * _cell;

                for "_c" from 0 to (_size - 1) do {
                    _labels pushBack ([-1, -2] select (surfaceIsWater [_ox + (_c + 0.5) * _cell, _y]));
                };
            };
        };

        _row = _row + _rowsPerStep;
        sleep 0.001;
    };

    // flood fill, resumable: a large island is labelled over several steps
    private _sizes = [];
    private _queue = [];
    private _head = 0;
    private _scan = 0;

    while {_scan < _count || {_head < count _queue}} do {
        isNil {
            private _budget = BR_var_landChunkCells;

            while {_budget > 0 && {_scan < _count || {_head < count _queue}}} do {
                _budget = _budget - 1;

                if (_head < count _queue) then {
                    private _i = _queue select _head;
                    private _id = _labels select _i;
                    private _c = _i mod _size;
                    private _neighbours = [];

                    _head = _head + 1;
                    if (_c > 0) then {_neighbours pushBack (_i - 1)};
                    if (_c < _size - 1) then {_neighbours pushBack (_i + 1)};
                    if (_i >= _size) then {_neighbours pushBack (_i - _size)};
                    if (_i + _size < _count) then {_neighbours pushBack (_i + _size)};

                    {
                        if ((_labels select _x) == -1) then {
                            _labels set [_x, _id];
                            _queue pushBack _x;
                            _sizes set [_id, (_sizes select _id) + 1];
                        };
                    } forEach _neighbours;
                } else {
                    if ((_labels select _scan) == -1) then {
                        _labels set [_scan, count _sizes];
                        _sizes pushBack 1;
                        _queue = [_scan];
                        _head = 0;
                    };

                    _scan = _scan + 1;
                };
            };
        };

        sleep 0.001;
    };

    // coast: land cells with a water neighbour (where boats go)
    private _coast = [];
    private _index = 0;

    while {_index < _count} do {
        isNil {
            for "_i" from _index to ((_index + BR_var_landChunkCells - 1) min (_count - 1)) do {
                if ((_labels select _i) >= 0) then {
                    private _c = _i mod _size;

                    if (
                        (_c > 0 && {(_labels select (_i - 1)) == -2}) ||
                        {_c < _size - 1 && {(_labels select (_i + 1)) == -2}} ||
                        {_i >= _size && {(_labels select (_i - _size)) == -2}} ||
                        {_i + _size < _count && {(_labels select (_i + _size)) == -2}}
                    ) then {
                        _coast pushBack _i;
                    };
                };
            };
        };

        _index = _index + BR_var_landChunkCells;
        sleep 0.001;
    };

    BR_var_landmasses = [_ox, _oy, _cell, _size, _labels, _sizes, _coast];
    BR_var_landCircleCache = createHashMap;
    diag_log format ["BR landmasses: %1 pieces (largest %2 cells), %3 coast cells, cell %4 m, %5 s",
        count _sizes, selectMax (_sizes + [0]), count _coast, round _cell, (diag_tickTime - _startTime) toFixed 1];
};

// the centre of grid cell _i
BR_fnc_landCellPos = {
    params ["_i"];

    BR_var_landmasses params ["_ox", "_oy", "_cell", "_size"];

    [_ox + ((_i mod _size) + 0.5) * _cell, _oy + (floor (_i / _size) + 0.5) * _cell, 0]
};

/*
    The landmass at _pos (object or position), or the nearest one within _reach cells (the cell centre of a shore spot or
    of a boat close to land is water); -1 if there is none or the grid is not built.
*/
BR_fnc_landmassNear = {
    params ["_pos", ["_reach", 2]];

    if (isNil "BR_var_landmasses") exitWith {-1};
    if (_pos isEqualType objNull) then {_pos = getPosATL _pos};

    BR_var_landmasses params ["_ox", "_oy", "_cell", "_size", "_labels"];

    private _c0 = floor (((_pos select 0) - _ox) / _cell);
    private _r0 = floor (((_pos select 1) - _oy) / _cell);
    private _found = -1;

    for "_ring" from 0 to _reach do {
        for "_dr" from -_ring to _ring do {
            for "_dc" from -_ring to _ring do {
                private _c = _c0 + _dc;
                private _r = _r0 + _dr;

                if ((abs _dr == _ring || {abs _dc == _ring}) && {_c >= 0} && {_r >= 0} && {_c < _size} && {_r < _size}) then {
                    private _label = _labels select (_r * _size + _c);

                    if (_label >= 0 && {_found < 0}) then {_found = _label};
                };
            };
        };

        if (_found >= 0) exitWith {};
    };

    _found
};

/*
    The land in a circle per landmass, largest first: [[landmass, sampled cells, [cell indices]], ...]. Sampled on a
    stride so a large circle costs at most BR_var_landCircleSamples cells; cached per circle.
*/
BR_fnc_landmassesInCircle = {
    params ["_center", "_radius"];

    if (isNil "BR_var_landmasses") exitWith {[]};

    private _key = str [round (_center select 0), round (_center select 1), round _radius];
    private _cached = BR_var_landCircleCache get _key;

    if (!isNil "_cached") exitWith {_cached};

    BR_var_landmasses params ["_ox", "_oy", "_cell", "_size", "_labels"];

    private _span = ceil (_radius / _cell);
    private _stride = 1 max ceil (sqrt (((2 * _span + 1) ^ 2) / BR_var_landCircleSamples));
    private _c0 = floor (((_center select 0) - _ox) / _cell);
    private _r0 = floor (((_center select 1) - _oy) / _cell);
    private _cells = createHashMap;

    for "_r" from ((_r0 - _span) max 0) to ((_r0 + _span) min (_size - 1)) step _stride do {
        for "_c" from ((_c0 - _span) max 0) to ((_c0 + _span) min (_size - 1)) step _stride do {
            private _i = _r * _size + _c;
            private _label = _labels select _i;

            if (_label >= 0 && {[_ox + (_c + 0.5) * _cell, _oy + (_r + 0.5) * _cell] distance2D _center <= _radius}) then {
                (_cells getOrDefaultCall [_label, {[]}, true]) pushBack _i;
            };
        };
    };

    private _result = (_cells toArray false) apply {[_x select 0, count (_x select 1), _x select 1]};

    _result = [_result, [], {_x select 1}, "DESCEND"] call BIS_fnc_sortBy;
    BR_var_landCircleCache set [_key, _result];
    _result
};

// a land position on _landmass close to _near: the closest sampled cell of that landmass in the circle, a land point in it
BR_fnc_landmassSpot = {
    params ["_near", "_landmass", "_center", "_radius"];

    private _entry = ([_center, _radius] call BR_fnc_landmassesInCircle) select {(_x select 0) == _landmass};

    if (_entry isEqualTo []) exitWith {_near};

    private _cells = (_entry select 0) select 2;
    private _distances = _cells apply {([_x] call BR_fnc_landCellPos) distance2D _near};
    private _cellPos = [_cells select (_distances find selectMin _distances)] call BR_fnc_landCellPos;
    private _spot = [_cellPos, (BR_var_landmasses select 2) / 2] call BR_fnc_randomLandPos;

    [[_cellPos] call BR_fnc_groundPos, _spot] select (([_spot, 0] call BR_fnc_landmassNear) == _landmass)
};
