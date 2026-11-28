// Harbours (whole-map maps): every side can spawn boats, land vehicles and helicopters at the harbours of the island. They are found from the
// terrain's pier and quay objects (terrain types SC_var_harborTypes, model name with one of SC_var_harborModelWords): a harbour is
// a cluster of at least SC_var_harborMinObjects such objects (each within SC_var_harborLink m of another) in the play
// zone; its boat spawn point lies in the sea (piers at lakes have none). The search takes ~15 s on a large island, so
// it runs in the background after the server init. Its shop (an info stand with the vehicle spawn action) stands on
// land next to the piers, its boat spawn point is free, deep water next to them, its vehicle spawn point (land vehicles
// and helicopters; a harbour without room for one has none) a free, flat place on land near the shop: a squad that came
// by boat goes on by vehicle (SC\ai\boats.sqf). A map marker and the 3D icons (SC_fnc_getBaseIcons) show it (server,
// client dialog in SC\vehicles\spawning.sqf).

// ---- constants ----

// terrain object types of the piers and quays and parts of their model names (lower case): Altis/Malden pier_f,
// Chernarus nav_pier_*, Tanoa pier*_01/02/03 and the quay walls quayconcrete_01_* most of its harbours are built of
// (without "quay" Harcourt and others would have no harbour)
SC_var_harborTypes = ["HOUSE", "QUAY"];
SC_var_harborModelWords = ["pier", "quay"];
SC_var_harborLink = 120;          // m between two objects of the same harbour
SC_var_harborMinObjects = 4;      // objects a harbour has at least (a lone jetty is none)
SC_var_harborMinSpacing = 1500;   // m between two harbours: of closer ones the larger (more piers) is kept (Tanoa: 57 -> few)
SC_var_harborShopRange = 200;     // m from the harbour center the shop may stand (on land)
SC_var_harborSpawnRange = 200;    // m from the harbour center the boat spawn point may lie (in the water)
SC_var_harborMinDepth = 2;        // m the sea floor at the boat spawn point lies below sea level
SC_var_harborSpawnClear = 12;     // m around the boat spawn point without terrain objects (piers, rocks)
SC_var_harborBoatGap = 9;         // m between a spawned boat and other vehicles or men
SC_var_harborVehicleRange = 400;  // m from the shop the vehicle spawn point may lie
SC_var_harborVehicleClear = 10;   // m around the vehicle spawn point without obstacles (a helicopter's rotor)
SC_var_harborVehicleFlat = 0.95;  // surface normal (z) at and around the vehicle spawn point at least (nearly flat)

// ---- server ----

// server init (after the map setup): the harbours [name, shop, boat spawn position ASL, direction, vehicle spawn
// position ATL ([] if none)] (published, empty until SC_fnc_createHarbors found them)
SC_fnc_initHarborsServer = {
    SC_var_harbors = [];
    SC_var_harborsReady = !SC_var_wholeMap;
    publicVariable "SC_var_harbors";
    publicVariable "SC_var_harborsReady";

    if SC_var_wholeMap then {
        SC_var_harborsScript = [] spawn SC_fnc_createHarbors;
    };
};

// server: finds the harbours and sets up their shops, actions, markers and spawn semaphores (background)
SC_fnc_createHarbors = {
    private _harbors = [];

    {
        _x params ["_name", "_shopPos", "_spawnPos", "_dir", "_vehiclePos"];

        private _index = count _harbors;
        private _shop = createVehicle ["Land_InfoStand_V2_F", _shopPos, [], 0, "CAN_COLLIDE"];

        _shop setDir _dir;
        _shop allowDamage false;
        _shop setVectorUp (surfaceNormal _shopPos);

        [
            _shop, [
                "<img size='1' color='#ffffff' shadow='2' image='\A3\ui_f\data\Map\Markers\NATO\c_ship.paa'/> Vehicles",
                {params ["", "", "", "_arguments"]; [false, (_arguments select 0), -1, true] call SC_fnc_setupVehicleSpawnDialog;},
                [_name], 1.5, true, false, "", "", 3
            ]
        ] remoteExecCall ["addAction", 0, true];

        missionNamespace setVariable [("SC_var_boatSpawnSemaphore" + (str _index)), false, true];
        missionNamespace setVariable [("SC_var_harborVehicleSpawnSemaphore" + (str _index)), false, true];

        private _marker = createMarker [("SC_var_harborMarker" + (str _index)), _shopPos];
        _marker setMarkerType "c_ship";

        _harbors pushBack [_name, _shop, _spawnPos, _dir, _vehiclePos];
    } forEach (call SC_fnc_findHarbors);

    SC_var_harbors = _harbors;
    SC_var_harborsReady = true;
    publicVariable "SC_var_harbors";
    publicVariable "SC_var_harborsReady";
    diag_log format ["SC: %1 harbours: %2", count SC_var_harbors, SC_var_harbors apply {
        [_x select 0, (getPosWorld (_x select 1)) apply {round _x}, (_x select 4) isNotEqualTo []]
    }];
};

// the harbours of the play zone: [name, shop position ATL, boat spawn position ASL, direction from shop to water, vehicle
// spawn position ATL ([] if none)]
SC_fnc_findHarbors = {
    private _size = worldSize;
    private _positions = ((nearestTerrainObjects [[_size / 2, _size / 2], SC_var_harborTypes, _size, false, true]) select {
        private _model = toLower ((getModelInfo _x) select 0);

        ((SC_var_harborModelWords findIf {_x in _model}) != -1) && {(getPosWorld _x) inArea "SC_var_playZone"}
    }) apply {getPosWorld _x};

    // clusters: objects linked within SC_var_harborLink m (breadth-first)
    private _clusterOf = _positions apply {-1};
    private _clusters = [];

    {
        if ((_clusterOf select _forEachIndex) == -1) then {
            private _id = count _clusters;
            private _members = [_forEachIndex];

            _clusterOf set [_forEachIndex, _id];

            for "_k" from 0 to 1e6 do {
                if (_k >= (count _members)) exitWith {};

                private _pos = _positions select (_members select _k);

                {
                    if (((_clusterOf select _forEachIndex) == -1) && {(_x distance2D _pos) < SC_var_harborLink}) then {
                        _clusterOf set [_forEachIndex, _id];
                        _members pushBack _forEachIndex;
                    };
                } forEach _positions;
            };

            _clusters pushBack (_members apply {_positions select _x});
        };
    } forEach _positions;

    private _harbors = [];
    private _names = [];
    private _taken = [];

    // the larger harbours first, so of two close ones the larger is kept (SC_var_harborMinSpacing)
    _clusters = [_clusters, [], {count _x}, "DESCEND"] call BIS_fnc_sortBy;

    {
        private _cluster = _x;
        private _clusterCenter = [0, 0, 0];

        {_clusterCenter = _clusterCenter vectorAdd _x} forEach _cluster;
        _clusterCenter = _clusterCenter vectorMultiply (1 / ((count _cluster) max 1));

        if ((count _cluster) >= SC_var_harborMinObjects && {(_taken findIf {(_x distance2D _clusterCenter) < SC_var_harborMinSpacing}) == -1}) then {
            private _center = [0, 0, 0];

            {_center = _center vectorAdd _x} forEach _cluster;
            _center = _center vectorMultiply (1 / (count _cluster));
            _center set [2, 0];

            private _shopPos = [_center, _cluster] call SC_fnc_harborShopPos;
            private _spawnPos = if (_shopPos isEqualTo []) then {[]} else {[_center, _shopPos] call SC_fnc_harborSpawnPos};

            if (_spawnPos isNotEqualTo []) then {
                private _town = (nearestLocations [_center, ["NameCityCapital", "NameCity", "NameVillage"], 5000]) param [0, locationNull];
                private _name = (if (isNull _town) then {"Coast"} else {text _town}) + " Harbor";

                // several harbours of one town: "Kavala Harbor", "Kavala Harbor 2", ...
                private _same = {_x == _name} count _names;

                _names pushBack _name;

                if (_same > 0) then {
                    _name = format ["%1 %2", _name, _same + 1];
                };
                _harbors pushBack [_name, _shopPos, _spawnPos, _shopPos getDir _spawnPos, [_shopPos] call SC_fnc_harborVehiclePos];
                _taken pushBack _clusterCenter;
            };
        };
    } forEach _clusters;

    _harbors
};

// a place for the shop on land next to the harbour: the free land spot nearest to its objects' center
SC_fnc_harborShopPos = {
    params ["_center", "_cluster"];

    private _result = [];

    for "_ring" from 0 to SC_var_harborShopRange step 10 do {
        for "_dir" from 0 to 345 step 15 do {
            private _pos = _center getPos [_ring, _dir];

            if (!(surfaceIsWater _pos) && {((ATLToASL _pos) select 2) > 0.5}) then {
                private _free = _pos findEmptyPosition [0, 15, "Land_InfoStand_V2_F"];

                if ((_free isNotEqualTo []) && {!(surfaceIsWater _free)}) exitWith {
                    _result = _free;
                };
            };
        };

        if (_result isNotEqualTo []) exitWith {};
    };

    _result
};

// whether a helicopter can stand at _pos: dry land, flat at the point and SC_var_harborVehicleClear m around it, and no
// terrain object whose ground plan (bounding box) reaches within SC_var_harborVehicleClear m - except the walkable
// quays and piers (Tanoa's quay walls are large objects that cover the whole quay; isFlatEmpty counts them as obstacles).
// findEmptyPosition is no help here: it puts helicopters into lamps and piers.
SC_fnc_harborSpotFree = {
    params ["_pos"];

    if ((surfaceIsWater _pos) || {(getTerrainHeightASL _pos) < 0.5}) exitWith {false};

    private _flat = ([[0, 0]] + ([0, 90, 180, 270] apply {[SC_var_harborVehicleClear * (sin _x), SC_var_harborVehicleClear * (cos _x)]})) findIf {
        private _p = _pos vectorAdd [_x select 0, _x select 1, 0];
        (surfaceIsWater _p) || {((surfaceNormal _p) select 2) < SC_var_harborVehicleFlat}
    };

    if (_flat != -1) exitWith {false};

    ((nearestTerrainObjects [_pos, [], SC_var_harborVehicleClear + 30, false, true]) findIf {
        private _model = toLower ((getModelInfo _x) select 0);

        !((["quay", "pier"] findIf {_x in _model}) != -1) && {
            (boundingBoxReal _x) params ["_min", "_max"];
            private _local = _x worldToModel (ASLToAGL [_pos select 0, _pos select 1, getTerrainHeightASL _pos]);
            ((_max select 0) - (_min select 0)) > 0.3 &&
            {(_local select 0) > ((_min select 0) - SC_var_harborVehicleClear)} &&
            {(_local select 0) < ((_max select 0) + SC_var_harborVehicleClear)} &&
            {(_local select 1) > ((_min select 1) - SC_var_harborVehicleClear)} &&
            {(_local select 1) < ((_max select 1) + SC_var_harborVehicleClear)}
        }
    }) == -1
};

// the vehicle spawn point: the free place (SC_fnc_harborSpotFree) nearest to the shop within SC_var_harborVehicleRange
// m, [] if there is none
SC_fnc_harborVehiclePos = {
    params ["_shopPos"];

    private _result = [];

    for "_ring" from 15 to SC_var_harborVehicleRange step 15 do {
        for "_dir" from 0 to 340 step 20 do {
            private _pos = _shopPos getPos [_ring, _dir];

            if ([_pos] call SC_fnc_harborSpotFree) exitWith {
                _result = [_pos select 0, _pos select 1, 0];
            };
        };

        if (_result isNotEqualTo []) exitWith {};

        sleep 0.01;
    };

    _result
};

// the boat spawn point: deep water without terrain objects (piers, rocks) near it, the one nearest to the shop
SC_fnc_harborSpawnPos = {
    params ["_center", "_shopPos"];

    private _best = [];
    private _bestDistance = 1e9;

    for "_ring" from 15 to SC_var_harborSpawnRange step 10 do {
        for "_dir" from 0 to 350 step 10 do {
            private _pos = _center getPos [_ring, _dir];

            if (
                (surfaceIsWater _pos) &&
                {(getTerrainHeightASL _pos) < -SC_var_harborMinDepth} &&
                {(_pos distance2D _shopPos) < _bestDistance} &&
                {(nearestTerrainObjects [_pos, [], SC_var_harborSpawnClear, false, true]) isEqualTo []}
            ) then {
                _best = [_pos select 0, _pos select 1, 0];
                _bestDistance = _pos distance2D _shopPos;
            };
        };
    };

    _best
};

// a free place for a boat near a harbour's spawn point (ASL, on the water surface), [] if there is none
SC_fnc_boatSpawnPos = {
    params ["_spawnPos"];

    private _result = [];

    for "_ring" from 0 to 60 step 10 do {
        for "_i" from 1 to 8 do {
            private _pos = _spawnPos getPos [_ring + (random 10), random 360];

            if (
                (surfaceIsWater _pos) &&
                {(getTerrainHeightASL _pos) < -SC_var_harborMinDepth} &&
                {(_pos nearEntities [["LandVehicle", "Air", "Ship", "CAManBase"], SC_var_harborBoatGap]) isEqualTo []} &&
                {(nearestTerrainObjects [_pos, [], SC_var_harborBoatGap, false, true]) isEqualTo []}
            ) exitWith {
                _result = [_pos select 0, _pos select 1, 0];
            };
        };

        if (_result isNotEqualTo []) exitWith {};
    };

    _result
};
