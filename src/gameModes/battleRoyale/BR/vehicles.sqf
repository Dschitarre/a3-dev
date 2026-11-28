// Battle Royale vehicles (server): a shared area-scaled budget, split between settlements and rural roads.
// Populated drop spots have priority within the settlement share; military sites can receive armed vehicles.
// Rural cars must actually be outside settlements, rather than drawing another town-biased sample.
// boats along the coast, a few civilian helicopters on open flat ground, unarmed planes and helicopters on the airfields.
// Little fuel, empty cargo, unlocked. Far from all combatants a vehicle is not simulated (BR_fnc_vehicleLodLoop). AI
// uses them too (BR\aiVehicles.sqf), planes excepted.
// The vehicle classes are the world group's (BR_worldPool of BR\loot\lootPool<mapGroup>.hpp): cars (civilian), military
// (only at military drop spots), boats (transport/civilian only), helis (unarmed transport only); the airfield planes
// are the loaded game's unarmed planes of the same content (BR_fnc_airfieldPlaneTypes).

BR_var_militaryVehicleChance = 0.5;     // a car at a military drop spot is a military vehicle this often
BR_var_militarySpotHouses = 3;          // a drop spot with this many military buildings is a military site
BR_var_boatSpacing = 450;               // coast spots (BR\landmass.sqf coast cells) for boats at least this far apart, picked
                                        // in random order: about 1.5 boats per km of coastline, evenly spread ...
BR_var_boatIslandMinCells = 20;         // ... with one on every landmass of at least this many grid cells first
BR_var_boatShoreDistance = [10, 120];   // a boat floats this far from the shore at most ...
BR_var_boatDepth = [-1.5, -25];         // ... where the water is this deep ...
BR_var_boatMinGap = 100;                // ... and no other boat is this close
BR_var_heliShare = 0.05;                // share of the vehicles that are helicopters ...
BR_var_heliSpotClearance = 12;          // ... on ground without objects this far around ...
BR_var_heliSpotGradient = 0.25;         // ... and at most this steep
BR_var_vehiclesPerCombatant = 0.25;     // cars on random roads: the area's count and this many per combatant; on top:
BR_var_townVehiclesPerSpot = 3;         // capped team pressure contributes to the shared total budget
BR_var_townVehicleRadius = 200;         // ... this close to the spot ...
BR_var_townVehicleSpacing = 100;        // minimum spacing between settlement cars
BR_var_townVehicleShare = 0.45;         // reserve the majority of cars for roads outside settlements
BR_var_ruralVehicleTownGap = 500;
BR_var_vehicleSpawnTries = 40;          // random tries per vehicle
BR_var_vehicleDensity = 0.6;           // scales cars and helicopters together, their shares kept
BR_var_vehicleSpawnSleep = 0.03;        // s between two vehicles (scheduled, the server does not stall)
BR_var_roadSearchRadius = 150;
BR_var_vehicleFuel = [0.25, 0.7];       // random fuel in [min, max]
BR_var_vehicleSpawnProtection = 5;      // seconds without damage, the physics settle
BR_var_vehicleLodDistance = 500;        // a vehicle with a living combatant this close is simulated, others not ...
BR_var_vehicleLodInterval = 3;          // ... checked this often
// Airfields (1-3 planes and 1-3 helicopters on every airfield, by its size and chance): the runways of
// the world in the play area (CfgWorlds ilsPosition and SecondaryAirports, BR_fnc_airfields), on top of the random
// helicopters above
BR_var_airfieldSizeSteps = [400, 1000];         // runway length (m) for size 2 and 3: Altis main 1360, its five strips
                                                // 310-590; Chernarus NWAF 1420, Balota 690, Krasnostav 570
BR_var_airfieldVehicleSpread = 1;               // planes and helicopters each: the size, up to this much more or less
BR_var_airfieldVehicleRange = [1, 3];           // ... at random, within this range
BR_var_airfieldPlaneMaxSize = [22, 32, 45];     // largest plane (config mapSize, about the wingspan) per size: no C-130 or
                                                // Blackfish on a short strip
BR_var_airfieldRunwayHalfWidth = 30;            // m: no vehicle reaches this close to the runway's centre line ...
BR_var_airfieldRunwayEndGap = 150;              // ... along it and this far beyond both ends (approach and roll-out)
BR_var_airfieldTaxiwayHalfWidth = 12;           // m: nor this close to a taxiway's centre line (aircraft taxi past) ...
BR_var_airfieldApronDepth = 40;                 // ... but at most this much further out beside it or beside a hangar
BR_var_airfieldAnchorStep = 25;                 // m between two taxiway points a vehicle may stand beside
BR_var_airfieldHangarSearch = 400;              // hangars this far beyond the runway's half length around its middle
BR_var_airfieldSpotMargin = 6;                  // m free around a vehicle's footprint (half its mapSize) ...
BR_var_airfieldLowObjectHeight = 1;             // ... where lower objects (lights, markings, flat concrete) do not count
BR_var_airfieldObjectReach = 60;                // ... (objects up to this far away are tested with their own extent) ...
BR_var_airfieldGradient = 0.15;                 // ... and the ground at most this steep
BR_var_airfieldSpotTries = 60;                  // random tries per vehicle

// [types, weights] of the world pool's list _name ({{type, weight}, ...}, or {type, ...} with weight 1), the types the
// loaded game has
BR_fnc_vehicleTypes = {
    params ["_name"];

    private _types = [];
    private _weights = [];

    {
        private _entry = [[_x, 1], _x] select (_x isEqualType []);

        _entry params ["_type", "_weight"];

        if (isClass (configFile >> "CfgVehicles" >> _type)) then {
            _types pushBack _type;
            _weights pushBack _weight;
        };
    } forEach getArray (missionConfigFile >> "BR_worldPool" >> _name);

    [_types, _weights]
};

// scheduled
BR_fnc_spawnVehicles = {
    (["cars"] call BR_fnc_vehicleTypes) params ["_carTypes", "_carWeights"];
    (["military"] call BR_fnc_vehicleTypes) params ["_militaryTypes", "_militaryWeights"];

    private _boatTypes = (["boats"] call BR_fnc_vehicleTypes) select 0;
    // the generated pools hold helicopters armed by their pylons' default loadout (CUP AW159/Wildcat "Dynamic"
    // variants: 20 mm pod and rockets), so the loaded config decides
    private _poolHelis = (["helis"] call BR_fnc_vehicleTypes) select 0;
    private _heliTypes = _poolHelis select {[_x] call BR_fnc_isUnarmedType};
    private _dropSpots = missionNamespace getVariable ["BR_var_aiDropSpots", []];
    private _townCarCount = 0;

    {
        _townCarCount = _townCarCount + (1 max ((BR_var_aiDropCounts select _forEachIndex) min BR_var_townVehiclesPerSpot));
    } forEach _dropSpots;

    private _carCount = if (BR_var_vehicleCountBase <= 0) then {0} else {
        round ((_townCarCount + BR_var_vehicleCount + BR_var_vehiclesPerCombatant * count BR_var_rosterUnits) * BR_var_vehicleDensity)
    };
    _townCarCount = round (_carCount * BR_var_townVehicleShare);
    private _coastCells = if (isNil "BR_var_landmasses") then {[]} else {
        (BR_var_landmasses select 6) select {([_x] call BR_fnc_landCellPos) distance2D BR_var_playAreaCenter < BR_var_playAreaRadius}
    };
    if (BR_var_vehicleCountBase <= 0) then {_coastCells = []};
    private _heliCount = [0, round (_carCount * BR_var_heliShare)] select (_heliTypes isNotEqualTo []);
    private _vehicleCount = _carCount + _heliCount;
    private _takenPositions = [];

    BR_var_vehicles = [];
    BR_var_vehicleSettlements = (nearestLocations [BR_var_playAreaCenter, ["NameCityCapital", "NameCity", "NameVillage"], BR_var_playAreaRadius]) apply {locationPosition _x};
    BR_var_vehicleHelipads = (nearestObjects [BR_var_playAreaCenter, ["HeliH", "Land_HelipadSquare_F", "Land_HelipadCircle_F"], BR_var_playAreaRadius, true]) apply {getPosATL _x};
    [] spawn BR_fnc_vehicleLodLoop;

    // One car per settlement drop spot, with occupied spots first, within the capped town share.
    if (_carTypes isNotEqualTo []) then {
        private _spots = [];

        {
            _spots pushBack [(BR_var_aiDropCounts select _forEachIndex) min BR_var_townVehiclesPerSpot, _x];
        } forEach _dropSpots;

        _spots = _spots select {
            private _center = (_x select 1) select 0;
            (BR_var_vehicleSettlements findIf {_x distance2D _center < 400}) >= 0 ||
            {[(_x select 1) select 3] call BR_fnc_isMilitarySpot}
        };
        _spots = (_spots select {(_x select 0) > 0}) + ((_spots select {(_x select 0) == 0}) call BIS_fnc_arrayShuffle);

        {
            _x params ["", "_spot"];
            _spot params ["_center", "", "", "_houses"];

            if (_townCarCount <= 0) exitWith {};

            private _military = [_houses] call BR_fnc_isMilitarySpot;

                private _roadSpot =[_takenPositions, _center, BR_var_townVehicleRadius,
                    BR_var_townVehicleSpacing] call BR_fnc_findRoadSpot;

                if (_roadSpot isNotEqualTo [] && {_townCarCount > 0}) then {
                    private _type = if (_military && {_militaryTypes isNotEqualTo []} && {random 1 < BR_var_militaryVehicleChance}) then {
                        _militaryTypes selectRandomWeighted _militaryWeights
                    } else {
                        _carTypes selectRandomWeighted _carWeights
                    };

                    _takenPositions pushBack (_roadSpot select 0);
                    [_roadSpot, _type] call BR_fnc_createVehicle;
                    _townCarCount = _townCarCount - 1;
                    _carCount = _carCount - 1;
                    sleep BR_var_vehicleSpawnSleep;
                };
        } forEach _spots;
    };

    diag_log format ["BR aircraft types: helis %1 of %2 unarmed", count _heliTypes, count _poolHelis];

    // the airfields before the random helicopters: their planes need the most free ground
    if (BR_var_vehicleCountBase > 0) then {
        _vehicleCount = _vehicleCount + ([_takenPositions, _heliTypes] call BR_fnc_spawnAirfieldVehicles);
    };

    for "_i" from 1 to _heliCount do {
        // large transport helicopters (Huron, Taru, Mohawk) need more free ground than the light ones
        private _type = selectRandom _heliTypes;
        private _clearance = BR_var_heliSpotClearance max (0.6 * getNumber (configFile >> "CfgVehicles" >> _type >> "mapSize"));
        private _spot = [_takenPositions, _clearance] call BR_fnc_findHeliSpot;

        if (_spot isNotEqualTo []) then {
            _takenPositions pushBack (_spot select 0);
            [_spot, _type] call BR_fnc_createVehicle;
        };

        sleep BR_var_vehicleSpawnSleep;
    };

    if (_carTypes isNotEqualTo []) then {
        for "_i" from 1 to _carCount do {
            private _spot =[_takenPositions, BR_var_playAreaCenter, BR_var_playAreaRadius, BR_var_vehicleSpacing,
                true] call BR_fnc_findRoadSpot;

            if (_spot isNotEqualTo []) then {
                _takenPositions pushBack (_spot select 0);
                [_spot, _carTypes selectRandomWeighted _carWeights] call BR_fnc_createVehicle;
            };

            sleep BR_var_vehicleSpawnSleep;
        };
    };

    if (_boatTypes isNotEqualTo [] && {_coastCells isNotEqualTo []}) then {
        // one random coast cell per landmass first (an AI on an island needs a boat), then all coast cells in random order;
        // a cell is taken if no taken one is closer than BR_var_boatSpacing (looked up on a grid of that cell size)
        private _islandCoasts = createHashMap;
        private _labels = BR_var_landmasses select 4;
        private _sizes = BR_var_landmasses select 5;

        {
            if ((_sizes select (_labels select _x)) >= BR_var_boatIslandMinCells) then {
                (_islandCoasts getOrDefaultCall [_labels select _x, {[]}, true]) pushBack _x;
            };
        } forEach _coastCells;

        private _plans = [];
        private _grid = createHashMap;

        {
            private _pos = [_x] call BR_fnc_landCellPos;
            private _gx = floor ((_pos select 0) / BR_var_boatSpacing);
            private _gy = floor ((_pos select 1) / BR_var_boatSpacing);
            private _free = true;

            for "_dx" from -1 to 1 do {
                for "_dy" from -1 to 1 do {
                    if(_free &&
                        {((_grid getOrDefault [[_gx + _dx, _gy + _dy],
                        []]) findIf {_x distance2D _pos < BR_var_boatSpacing}) >= 0}) then {
                        _free = false;
                    };
                };
            };

            if (_free) then {
                (_grid getOrDefaultCall [[_gx, _gy], {[]}, true]) pushBack _pos;
                _plans pushBack _x;
            };
        } forEach (((values _islandCoasts) apply {selectRandom _x}) + (_coastCells call BIS_fnc_arrayShuffle));

        _vehicleCount = _vehicleCount + count _plans;

        // boats keep their distance to each other only: a coastal road with cars does not block the shore
        private _boatPositions = [];

        {
            private _spot = [_boatPositions, [_x]] call BR_fnc_findCoastSpot;

            if (_spot isNotEqualTo []) then {
                _boatPositions pushBack (_spot select 0);
                [_spot, selectRandom _boatTypes] call BR_fnc_createVehicle;
            };

            sleep BR_var_vehicleSpawnSleep;
        } forEach _plans;
    };

    diag_log format ["BR vehicles: %1 of %2 placed", count BR_var_vehicles, _vehicleCount];
};

// a drop spot's houses ([position, name, capacity, houses] of BR_var_aiDropSpots) make a military site
BR_fnc_isMilitarySpot = {
    params ["_houses"];

    private _militaryWeights = (BR_var_buildingLootClasses select 0) select 1;

    ({(([_x] call BR_fnc_buildingLootQuality) select 0) isEqualTo _militaryWeights} count _houses) >= BR_var_militarySpotHouses
};

/*
    Scheduled: a vehicle is simulated while a living combatant is within BR_var_vehicleLodDistance or someone is in it;
    an empty one at rest far from everyone is not (hundreds of vehicles on a whole map). BR_fnc_aiBoard switches it on
    as well.
*/
BR_fnc_vehicleLodLoop = {
    waitUntil {
        {
            private _vehicle = _x;

            if (alive _vehicle) then {
                private _wanted = ((crew _vehicle) findIf {alive _x}) != -1 ||
                    {((_vehicle nearEntities [["CAManBase"], BR_var_vehicleLodDistance]) findIf {alive _x && {_x getVariable ["BR_var_inMatch", false]}}) != -1} ||
                    {speed _vehicle > 1} ||
                    {!isTouchingGround _vehicle && {!(_vehicle isKindOf "Ship")}};

                if (_wanted isNotEqualTo (simulationEnabled _vehicle)) then {
                    _vehicle enableSimulationGlobal _wanted;
                };
            };
        } forEach BR_var_vehicles;

        sleep BR_var_vehicleLodInterval;
        BR_var_state == "ended"
    };
};

// [position, direction] on open, flat land (_clearance m free around) away from _takenPositions, [] if none was found
BR_fnc_findHeliSpot = {
    params ["_takenPositions", ["_clearance", BR_var_heliSpotClearance]];

    private _spot = [];

    for "_i" from 1 to BR_var_vehicleSpawnTries do {
        private _anchors = BR_var_vehicleHelipads + BR_var_vehicleSettlements;
        if (_anchors isEqualTo []) exitWith {};
        private _anchor = selectRandom _anchors;
        private _pos = [_anchor, [250, 35] select (_anchor in BR_var_vehicleHelipads)] call BR_fnc_randomPosInCircle;

        if (
            !surfaceIsWater _pos && {_pos distance2D BR_var_playAreaCenter < BR_var_playAreaRadius} &&
            {_anchor in BR_var_vehicleHelipads || {(_pos nearRoads 50) isNotEqualTo []}} &&
            (_takenPositions findIf {_x distance2D _pos < (BR_var_heliSpotClearance + _clearance)}) == -1 &&
            {(_pos isFlatEmpty [_clearance, -1, BR_var_heliSpotGradient, _clearance, 0, false, objNull]) isNotEqualTo []}
        ) then {
            _spot = [_pos, random 360];
        };

        if (_spot isNotEqualTo []) exitWith {};
    };

    _spot
};

// [position, direction] on a road (not on a bridge) in the circle, away from _takenPositions, [] if none was found
BR_fnc_findRoadSpot = {
    params ["_takenPositions", ["_center", BR_var_playAreaCenter], ["_radius", BR_var_playAreaRadius], ["_spacing", BR_var_vehicleSpacing], ["_ruralOnly",false]];

    private _spot = [];

    for "_i" from 1 to BR_var_vehicleSpawnTries do {
        private _roads = ([_center, _radius] call BR_fnc_randomPosInCircle) nearRoads BR_var_roadSearchRadius;

        if (_roads isNotEqualTo []) then {
            private _road = selectRandom _roads;
            private _roadPos = [getPosATL _road] call BR_fnc_groundPos;

            if (!surfaceIsWater _roadPos && {_roadPos distance2D _center <= _radius} &&
                {_roadPos distance2D BR_var_playAreaCenter <= BR_var_playAreaRadius} && {!((getRoadInfo _road) param [8, false])} &&
                {!_ruralOnly || {(BR_var_vehicleSettlements findIf {_x distance2D _roadPos < BR_var_ruralVehicleTownGap})<0}}) then {
                private _connected = roadsConnectedTo _road;
                private _direction = if (_connected isEqualTo []) then {random 360} else {_road getDir (_connected select 0)};

                private _width = (getRoadInfo _road) param [1, 6];
                {
                    private _park = _roadPos getPos [_width / 2 + 2.5, _direction + _x];
                    if (!surfaceIsWater _park && {_park distance2D _center <= _radius} &&
                        {_park distance2D BR_var_playAreaCenter <= BR_var_playAreaRadius} &&
                        {(_takenPositions findIf {_x distance2D _park < _spacing}) == -1} &&
                        {(nearestTerrainObjects [_park, ["HOUSE", "WALL", "FENCE", "TREE", "ROCK", "ROCKS"], 4, false, true]) isEqualTo []} &&
                        {(_park isFlatEmpty [3, -1, 0.2, 4, 0, false, objNull]) isNotEqualTo []}) exitWith {
                        _spot = [[_park] call BR_fnc_groundPos, _direction];
                    };
                } forEach [90, -90];
            };
        };

        if (_spot isNotEqualTo []) exitWith {};
    };

    _spot
};

/*
    [position, direction] on the water close to the shore of one of the coast cells _cells (BR\landmass.sqf), [] if none
    was found: the shore between the cell and a random direction's water (bisection), then outwards in steps to the first
    spot that is deep enough and free (a few metres of shallow beach, a pier or rocks are passed).
*/
BR_fnc_findCoastSpot = {
    params ["_takenPositions", "_cells"];

    private _spot = [];

    BR_var_landmasses params ["", "", "_cell", "_size", "_labels"];

    for "_i" from 1 to BR_var_vehicleSpawnTries do {
        // from a point in the cell towards one of its water neighbours (+-45 degrees)
        private _index = selectRandom _cells;
        private _cellPos = [_index] call BR_fnc_landCellPos;
        private _land = [_cellPos, _cell / 2] call BR_fnc_randomPosInCircle;
        private _waterNeighbours = [_index - 1, _index + 1, _index - _size, _index + _size] select {
            _x >= 0 && {_x < _size * _size} && {(_labels select _x) == -2}
        };
        private _direction = if (_waterNeighbours isEqualTo []) then {random 360} else {
            (_cellPos getDir ([selectRandom _waterNeighbours] call BR_fnc_landCellPos)) + random 90 - 45
        };
        private _water = [];

        if (!surfaceIsWater _land) then {
            for "_d" from 25 to 300 step 25 do {
                private _pos = _land getPos [_d, _direction];
                if (surfaceIsWater _pos) exitWith {_water = _pos};
            };
        };

        if (_water isNotEqualTo []) then {
            while {_land distance2D _water > 1} do {
                private _mid = (_land vectorAdd _water) vectorMultiply 0.5;
                if (surfaceIsWater _mid) then {_water = _mid} else {_land = _mid};
            };

            BR_var_boatShoreDistance params ["_minShore", "_maxShore"];

            for "_d" from _minShore to _maxShore step 10 do {
                private _pos = _water getPos [_d, _direction];
                private _depth = getTerrainHeightASL _pos;

                if (!surfaceIsWater _pos) exitWith {};

                if (
                    _depth < (BR_var_boatDepth select 0) && {_depth > (BR_var_boatDepth select 1)} &&
                    {_pos distance2D BR_var_playAreaCenter < BR_var_playAreaRadius} &&
                    {(nearestObjects [_pos, ["House", "Ship"], 10, true]) isEqualTo []} &&
                    {(nearestTerrainObjects [_pos, ["ROCK", "ROCKS", "HIDE"], 10, false, true]) isEqualTo []} &&
                    {(_takenPositions findIf {_x distance2D _pos < BR_var_boatMinGap}) == -1}
                ) exitWith {
                    _spot = [_pos, _direction + 90];
                };
            };
        };

        if (_spot isNotEqualTo []) exitWith {};
    };

    _spot
};

// ---- airfields ----

/*
    True if the vehicle class carries nothing that does damage: no weapon of its own or of a turret (also nested ones)
    with a magazine whose ammo hits (countermeasure launchers, horns and designators do not), no pylon with a default
    attachment (the CUP Wildcat "Dynamic" variants and the armed Cessna T-41 list no weapons, their pylons carry them).
*/
BR_fnc_isUnarmedType = {
    params ["_type"];

    private _config = configFile >> "CfgVehicles" >> _type;
    private _weapons = getArray (_config >> "weapons");
    private _turretLists = [_config >> "Turrets"];

    while {_turretLists isNotEqualTo []} do {
        {
            _weapons append getArray (_x >> "weapons");
            _turretLists pushBack (_x >> "Turrets");
        } forEach ("true" configClasses (_turretLists deleteAt 0));
    };

    private _armedWeapon = _weapons findIf {
        private _weapon = configFile >> "CfgWeapons" >> _x;

        getText (_weapon >> "simulation") != "cmlauncher" &&
        {((getArray (_weapon >> "magazines")) findIf {
            private _ammo = configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _x >> "ammo");
            getNumber (_ammo >> "hit") > 0 || {getNumber (_ammo >> "indirectHit") > 0}
        }) >= 0}
    };

    _armedWeapon == -1 &&
    {("getText (_x >> 'attachment') != ''" configClasses (_config >> "Components" >> "TransportPylonsComponent" >> "Pylons")) isEqualTo []}
};

/*
    [types, weights, sizes] of the planes for the airfields: every unarmed plane of the loaded game that belongs to the
    world group. The pools list no small planes (their "aircraft" are the transports with 16+ seats for the flight, by
    the generator), and a generic config scan finds them on any modset: the group's content is the classes whose name
    begins like one of the pool's vehicles (CUP_..., or the base game's C_/B_/O_/I_), so Altis gets no CUP An-2 and
    Chernarus no Caesar. Not a drone, not indestructible scenery (the CUP ambient airliners), a pilot's seat. Weight
    1 / classes of the same model: every airframe as often, not the one with the most liveries. Size: config mapSize.
*/
BR_fnc_airfieldPlaneTypes = {
    private _prefixes = [];

    {
        {
            private _type = if (_x isEqualType []) then {_x select 0} else {_x};
            _prefixes pushBackUnique toLowerANSI ((_type splitString "_") param [0, ""]);
        } forEach getArray (missionConfigFile >> "BR_worldPool" >> _x);
    } forEach ["cars", "military", "boats", "helis", "aircraft"];

    private _types = (("getNumber (_x >> 'scope') == 2 && {configName _x isKindOf 'Plane'}" configClasses
        (configFile >> "CfgVehicles")) apply {configName _x}) select {
        private _config = configFile >> "CfgVehicles" >> _x;

        (toLowerANSI ((_x splitString "_") param [0, ""])) in _prefixes &&
        {getNumber (_config >> "isUav") != 1} &&
        {getText (_config >> "destrType") != "DestructNo"} &&
        {getNumber (_config >> "hasDriver") == 1} &&
        {getNumber (_config >> "mapSize") > 0} &&
        {[_x] call BR_fnc_isUnarmedType}
    };
    private _models = _types apply {toLowerANSI getText (configFile >> "CfgVehicles" >> _x >> "model")};
    private _modelCounts = createHashMap;

    {_modelCounts set [_x, (_modelCounts getOrDefault [_x, 0]) + 1]} forEach _models;

    [_types, _models apply {1 / (_modelCounts get _x)}, _types apply {getNumber (configFile >> "CfgVehicles" >> _x >> "mapSize")}]
};

/*
    The world's airfields in the play area: [name, threshold, runway direction, runway start, runway end, taxi segments,
    size, [taxiway anchors, hangar anchors]], from the main runway and the SecondaryAirports of CfgWorlds.
    - ilsPosition is the runway's touchdown point, ilsDirection ([x, glide slope, y]) points from there to the approach:
      the runway runs the other way.
    - ilsTaxiOff (landing roll along the runway, then to the parking area) and ilsTaxiIn (from there to the runway's
      start) are flat x, y lists: the taxi segments. The runway's extent: their points along its direction (start <= 0:
      the taxi-in ends at the hold point before the threshold); its length gives the size 1-3 (BR_var_airfieldSizeSteps),
      the aerodrome configs have no other measure of it.
    - anchors [position, reach, outward directions (empty: any), face the anchor]: taxiway points every
      BR_var_airfieldAnchorStep m off the runway, a vehicle beside them faces the taxiway to roll out; hangars ("hangar"
      in class or model), a vehicle beside one faces away from it.
*/
BR_fnc_airfields = {
    private _world = configFile >> "CfgWorlds" >> worldName;
    private _airfields = [];

    {
        private _config = _x;
        private _threshold = getArray (_config >> "ilsPosition");
        private _ilsDirection = getArray (_config >> "ilsDirection");

        if (count _threshold >= 2 && {count _ilsDirection >= 3} &&
            {_threshold distance2D BR_var_playAreaCenter <= BR_var_playAreaRadius}) then {
            private _name = [worldName, configName _config] select (_forEachIndex > 0);
            private _direction = (((-(_ilsDirection select 0)) atan2 (-(_ilsDirection select 2))) + 360) % 360;
            private _segments = [];

            _threshold = [_threshold select 0, _threshold select 1, 0];

            {
                private _path = getArray (_config >> _x);

                for "_i" from 0 to count _path - 4 step 2 do {
                    _segments pushBack [[_path select _i, _path select (_i + 1), 0], [_path select (_i + 2), _path select (_i + 3), 0]];
                };
            } forEach ["ilsTaxiOff", "ilsTaxiIn"];

            private _along = [0];

            {
                {
                    private _offset = _x vectorDiff _threshold;
                    _along pushBack ((_offset select 0) * sin _direction + (_offset select 1) * cos _direction);
                } forEach _x;
            } forEach _segments;

            private _start = selectMin _along;
            private _end = selectMax _along;
            private _runway = [_name, _threshold, _direction, _start, _end];
            private _taxiAnchors = [];

            {
                _x params ["_from", "_to"];

                private _steps = (ceil ((_from distance2D _to) / BR_var_airfieldAnchorStep)) max 1;
                private _heading = _from getDir _to;

                for "_k" from 0 to _steps - 1 do {
                    private _point = _from vectorAdd ((_to vectorDiff _from) vectorMultiply (_k / _steps));

                    if !([_runway, _point, 0] call BR_fnc_onRunway) then {
                        _taxiAnchors pushBack [_point, BR_var_airfieldTaxiwayHalfWidth, [_heading + 90, _heading - 90], true];
                    };
                };
            } forEach _segments;

            private _middle = _threshold vectorAdd [sin _direction * (_start + _end) / 2, cos _direction * (_start + _end) / 2, 0];
            private _hangarAnchors = ((nearestObjects [_middle, ["House"], (_end - _start) / 2 + BR_var_airfieldHangarSearch, true]) select {
                "hangar" in toLowerANSI typeOf _x || {"hangar" in toLowerANSI ((getModelInfo _x) select 0)}
            }) apply {
                (boundingBoxReal _x) params ["_min", "_max"];
                private _halfDiagonal = 0.5 * vectorMagnitude [(_max select 0) - (_min select 0), (_max select 1) - (_min select 1), 0];

                [getPosATL _x, _halfDiagonal, [], false]
            };

            _airfields pushBack (_runway + [_segments, 1 + ({_end - _start >= _x} count BR_var_airfieldSizeSteps),
                [_taxiAnchors, _hangarAnchors]]);
        };
    } forEach ([_world] + ("true" configClasses (_world >> "SecondaryAirports")));

    _airfields
};

// true if a vehicle _radius m around _pos reaches onto the runway of _airfield (BR_fnc_airfields) or its ends
BR_fnc_onRunway = {
    params ["_airfield", "_pos", "_radius"];
    _airfield params ["", "_threshold", "_direction", "_start", "_end"];

    private _offset = [_pos select 0, _pos select 1, 0] vectorDiff _threshold;
    private _along = (_offset select 0) * sin _direction + (_offset select 1) * cos _direction;
    private _across = abs ((_offset select 0) * cos _direction - (_offset select 1) * sin _direction);

    _across < BR_var_airfieldRunwayHalfWidth + _radius &&
    {_along > _start - BR_var_airfieldRunwayEndGap - _radius} &&
    {_along < _end + BR_var_airfieldRunwayEndGap + _radius}
};

// distance (2D) from _pos to the segment _from - _to (both [x, y, 0])
BR_fnc_segmentDistance = {
    params ["_pos", "_from", "_to"];

    private _point = [_pos select 0, _pos select 1, 0];
    private _line = _to vectorDiff _from;
    private _lengthSqr = _line vectorDotProduct _line;
    private _share = if (_lengthSqr == 0) then {0} else {
        (0 max (((_point vectorDiff _from) vectorDotProduct _line) / _lengthSqr)) min 1
    };

    _point distance2D (_from vectorAdd (_line vectorMultiply _share))
};

/*
    True if _radius m around _pos the ground is flat enough and nothing stands there: every object (terrain or placed)
    at least BR_var_airfieldLowObjectHeight tall counts with its own extent (half its bounding box diagonal), so a
    vehicle neither stands in a hangar nor has a wing in its wall; runway and taxiway lights, markings and flat concrete
    are lower (isFlatEmpty's object test counts them all and found no room on the aprons).
*/
BR_fnc_airfieldGroundFree = {
    params ["_pos", "_radius"];

    private _search = _radius + BR_var_airfieldObjectReach;

    (_pos isFlatEmpty [-1, -1, BR_var_airfieldGradient, _radius, 0, false, objNull]) isNotEqualTo [] &&
    {(((nearestObjects [_pos, [], _search, true]) + (nearestTerrainObjects [_pos, [], _search, false, true])) findIf {
        (boundingBoxReal _x) params ["_min", "_max"];

        (_max select 2) - (_min select 2) >= BR_var_airfieldLowObjectHeight &&
        {_x distance2D _pos < _radius + 0.5 * vectorMagnitude [(_max select 0) - (_min select 0), (_max select 1) - (_min select 1), 0]}
    }) == -1}
};

/*
    [position, direction] for a vehicle _radius m around on _airfield (BR_fnc_airfields), [] if none was found: beside a
    random taxiway point or hangar (either kind as often: a few hangars against a hundred taxiway points), off the
    runway and the taxiways, clear of this airfield's vehicles (_taken: [position, radius]), the other vehicles
    (_takenPositions) and every object (BR_fnc_airfieldGroundFree).
*/
BR_fnc_findAirfieldSpot = {
    params ["_airfield", "_radius", "_taken", "_takenPositions"];

    private _anchorGroups = (_airfield select 7) select {_x isNotEqualTo []};
    private _spot = [];

    if (_anchorGroups isEqualTo []) exitWith {_spot};

    for "_i" from 1 to BR_var_airfieldSpotTries do {
        (selectRandom selectRandom _anchorGroups) params ["_anchorPos", "_reach", "_directions", "_faceAnchor"];

        private _outward = if (_directions isEqualTo []) then {random 360} else {selectRandom _directions};
        private _pos = _anchorPos getPos [_reach + _radius + random BR_var_airfieldApronDepth, _outward];

        if (
            !surfaceIsWater _pos && {_pos distance2D BR_var_playAreaCenter < BR_var_playAreaRadius} &&
            {!([_airfield, _pos, _radius] call BR_fnc_onRunway)} &&
            {((_airfield select 5) findIf {([_pos, _x select 0, _x select 1] call BR_fnc_segmentDistance) <
                BR_var_airfieldTaxiwayHalfWidth + _radius}) == -1} &&
            {(_taken findIf {((_x select 0) distance2D _pos) < (_x select 1) + _radius}) == -1} &&
            {(_takenPositions findIf {_x distance2D _pos < _radius + BR_var_airfieldSpotMargin}) == -1} &&
            {[_pos, _radius] call BR_fnc_airfieldGroundFree}
        ) then {
            _spot = [[_pos select 0, _pos select 1, 0], [_anchorPos getDir _pos, _pos getDir _anchorPos] select _faceAnchor];
        };

        if (_spot isNotEqualTo []) exitWith {};
    };

    _spot
};

// how many planes (or helicopters) an airfield of size _size gets: its size, BR_var_airfieldVehicleSpread more or less
BR_fnc_airfieldVehicleCount = {
    params ["_size"];
    BR_var_airfieldVehicleRange params ["_least", "_most"];

    (_least max (_size + floor random (2 * BR_var_airfieldVehicleSpread + 1) - BR_var_airfieldVehicleSpread)) min _most
};

/*
    Scheduled: unarmed planes and helicopters on every airfield of the play area (BR_fnc_airfields), as many as its size
    and chance give (BR_fnc_airfieldVehicleCount) - the planes of the world group up to the size's largest
    (BR_var_airfieldPlaneMaxSize), none without such planes. Placed by BR_fnc_createVehicle like every BR vehicle
    (fuel, cargo, lock, spawn protection, BR_var_vehicles and its LOD loop) and pushed to _takenPositions. Returns how
    many were planned, for the "BR vehicles" line.
*/
BR_fnc_spawnAirfieldVehicles = {
    params ["_takenPositions", "_heliTypes"];

    private _airfields = [] call BR_fnc_airfields;

    if (_airfields isEqualTo []) exitWith {0};

    ([] call BR_fnc_airfieldPlaneTypes) params ["_planeTypes", "_planeWeights", "_planeSizes"];

    private _planned = 0;

    diag_log format ["BR airfield plane types: %1", _planeTypes];

    {
        private _airfield = _x;
        _airfield params ["_name", "", "", "_start", "_end", "", "_size", "_anchorGroups"];

        private _maxSize = BR_var_airfieldPlaneMaxSize select (_size - 1);
        private _fitting = [];
        private _fittingWeights = [];

        {
            if ((_planeSizes select _forEachIndex) <= _maxSize) then {
                _fitting pushBack _x;
                _fittingWeights pushBack (_planeWeights select _forEachIndex);
            };
        } forEach _planeTypes;

        private _taken = [];
        private _report = [];

        {
            _x params ["_kind", "_types", "_weights"];

            private _count = [0, [_size] call BR_fnc_airfieldVehicleCount] select (_types isNotEqualTo []);
            private _placed = [];

            for "_i" from 1 to _count do {
                private _type = _types selectRandomWeighted _weights;
                private _radius = BR_var_airfieldSpotMargin + 0.5 * getNumber (configFile >> "CfgVehicles" >> _type >> "mapSize");
                private _spot = [_airfield, _radius, _taken, _takenPositions] call BR_fnc_findAirfieldSpot;

                if (_spot isNotEqualTo []) then {
                    _taken pushBack [_spot select 0, _radius];
                    _takenPositions pushBack (_spot select 0);
                    [_spot, _type] call BR_fnc_createVehicle;
                    _placed pushBack _type;
                };

                sleep BR_var_vehicleSpawnSleep;
            };

            _planned = _planned + _count;
            _report pushBack format ["%1 %2 of %3 %4", _kind, count _placed, _count, _placed];
        } forEach [["planes", _fitting, _fittingWeights], ["helis", _heliTypes, _heliTypes apply {1}]];

        diag_log format ["BR airfield vehicles: %1 size %2 (runway %3 m, %4 taxiway points, %5 hangars): %6", _name, _size,
            round (_end - _start), count (_anchorGroups select 0), count (_anchorGroups select 1), _report joinString ", "];
    } forEach _airfields;

    _planned
};

BR_fnc_createVehicle = {
    params ["_spot", "_type"];
    _spot params ["_pos", "_direction"];

    private _vehicle = createVehicle [_type, _pos, [], 0, "NONE"];

    BR_var_vehicles pushBack _vehicle;
    if (_vehicle isKindOf "Ship") then {_vehicle setPosASL [_pos select 0,_pos select 1,0]} else {_vehicle setPosATL _pos};
    _vehicle setDir _direction;
    if !(_vehicle isKindOf "Ship") then {_vehicle setVectorUp surfaceNormal _pos};
    _vehicle lock false;
    [_vehicle, false] call ADG_fnc_allowDamage;
    clearItemCargoGlobal _vehicle;
    clearWeaponCargoGlobal _vehicle;
    clearMagazineCargoGlobal _vehicle;
    clearBackpackCargoGlobal _vehicle;
    _vehicle setFuel ((BR_var_vehicleFuel select 0) + random ((BR_var_vehicleFuel select 1) - (BR_var_vehicleFuel select 0)));

    [_vehicle] spawn {
        params ["_vehicle"];

        sleep BR_var_vehicleSpawnProtection;
        [_vehicle, true] call ADG_fnc_allowDamage;
    };
};
