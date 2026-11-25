// Unflip (server and clients): the settings, the checks and the unflip itself, which runs on the machine where the
// vehicle is local (setVectorDirAndUp, setVelocity and allowDamage need a local vehicle): the server, a client or a
// headless client.

// ---- settings ----
// Missions may set them before the mod starts; the module sets them on the server; the start publishes them.
// UF_var_enabled may change at any time (set it on the server and publicVariable it): false pauses the action and
// the AI unflip. Units: distance m, tilt degrees from upright, speed m/s, durations s, masses kg (getMass).

if (isNil "UF_var_enabled") then {UF_var_enabled = true;};
if (isNil "UF_var_maxDistance") then {UF_var_maxDistance = 6;};           // from the player's eyes to the vehicle's box
if (isNil "UF_var_minTilt") then {UF_var_minTilt = 65;};                  // tilt from which a vehicle is flipped
if (isNil "UF_var_maxSpeed") then {UF_var_maxSpeed = 1;};                 // faster: still tumbling or sliding
if (isNil "UF_var_durationMin") then {UF_var_durationMin = 3;};           // hold for light vehicles (UF_var_massLight) ...
if (isNil "UF_var_durationMax") then {UF_var_durationMax = 8;};           // ... up to heavy ones (UF_var_massHeavy)
if (isNil "UF_var_massLight") then {UF_var_massLight = 500;};             // quad bike
if (isNil "UF_var_massHeavy") then {UF_var_massHeavy = 40000;};           // tank; linear in between
if (isNil "UF_var_damageProtection") then {UF_var_damageProtection = 2;}; // no damage after the unflip (landing)
if (isNil "UF_var_aiAutoUnflip") then {UF_var_aiAutoUnflip = true;};      // the server unflips AI vehicles ...
if (isNil "UF_var_aiDelay") then {UF_var_aiDelay = 10;};                  // ... once they are flipped for this long

// ---- tuning ----

UF_var_lift = 0.3;          // metres between the vehicle's bottom and the highest ground below it after the unflip
UF_var_liftStep = 0.5;      // metres the vehicle is raised further while its box would still intersect something ...
UF_var_maxLiftSteps = 3;    // ... at most this many times (then it is set down there anyway)
UF_var_maxForwards = 3;     // times an unflip / a damage protection follows a vehicle that changed its owner on the way
UF_var_boxes = createHashMap;   // class -> [min, max] of the vehicle's box in model coordinates

// ---- checks ----

// box of a vehicle class in model coordinates, cached: its geometry (the default box also holds antennas and memory
// points), down to the lowest point of the visual model (the wheels are not part of every geometry). [min, max]
UF_fnc_box = {
    params ["_vehicle"];

    private _type = typeOf _vehicle;
    private _box = UF_var_boxes get _type;

    if (isNil "_box") then {
        (2 boundingBoxReal _vehicle) params ["_min", "_max"];

        // a class without geometry: the whole model
        if ((vectorMagnitude (_max vectorDiff _min)) < 0.1) then {
            (boundingBoxReal _vehicle) params ["_modelMin", "_modelMax"];

            _min = _modelMin;
            _max = _modelMax;
        };

        // a machine without the visual model (dedicated server) may get an empty box here, which min ignores
        _min set [2, (_min select 2) min (((0 boundingBoxReal _vehicle) select 0) select 2)];

        _box = [_min, _max];
        UF_var_boxes set [_type, _box];
    };

    _box
};

// living crew (unconscious counts as living); the AI units that operate a UAV / UGV are no crew
UF_fnc_livingCrew = {
    params ["_vehicle"];

    if (unitIsUAV _vehicle) exitWith {[]};

    (crew _vehicle) select {alive _x}
};

// whether a vehicle may be unflipped now: a land vehicle (also a static weapon) or a boat, flipped (tilted beyond
// UF_var_minTilt), alive, simulated (no decoration), nearly standing still and without living crew; _allowAiCrew:
// AI crew may be inside (the AI unflip), players never. The cheap tilt test first: the action checks every frame.
UF_fnc_canUnflip = {
    params ["_vehicle", ["_allowAiCrew", false]];

    !isNull _vehicle &&
    {((vectorUp _vehicle) select 2) < (cos UF_var_minTilt)} &&
    {(_vehicle isKindOf "LandVehicle") || {_vehicle isKindOf "Ship"}} &&
    {alive _vehicle} &&
    {simulationEnabled _vehicle} &&
    {!isSimpleObject _vehicle} &&
    {(vectorMagnitude (velocity _vehicle)) < UF_var_maxSpeed} &&
    {
        private _crew = [_vehicle] call UF_fnc_livingCrew;

        (_crew isEqualTo []) || {_allowAiCrew && {(_crew findIf {isPlayer _x}) == -1}}
    }
};

// ---- upright pose ----

// a model-space offset in world space for the orientation [right, forward, up]
UF_fnc_rotate = {
    params ["_offset", "_axes"];
    _axes params ["_right", "_forward", "_up"];

    ((_right vectorMultiply (_offset select 0)) vectorAdd (_forward vectorMultiply (_offset select 1))) vectorAdd
        (_up vectorMultiply (_offset select 2))
};

// whether a surface a ray hit (lineIntersectsSurfaces result) blocks the vehicle: the terrain (no object) and objects
// do; men (dead crew inside, players next to it) and what is attached to the vehicle do not
UF_fnc_isObstacle = {
    params ["_hit", "_vehicle"];
    _hit params ["", "", "_object", "_parent"];

    if (!isNull _parent) then {
        _object = _parent;
    };

    isNull _object || {!(_object isKindOf "CAManBase") && {(attachedTo _object) isNotEqualTo _vehicle}}
};

// the highest surface below a point a vehicle can stand on: terrain, roads, bridges and floors (roadway LOD), rocks,
// walls and wrecks (geometry). The ray starts 1 m above _posASL (or the terrain), so a bridge or roof above the
// vehicle does not count. Over the sea the water surface instead of the sea floor. [height ASL, surface normal]
UF_fnc_groundBelow = {
    params ["_posASL", "_vehicle"];

    private _terrainHeight = getTerrainHeightASL _posASL;
    private _from = [_posASL select 0, _posASL select 1, ((_posASL select 2) max _terrainHeight) + 1];
    private _to = [_posASL select 0, _posASL select 1, _terrainHeight - 1];
    private _hits = lineIntersectsSurfaces [_from, _to, _vehicle, objNull, true, 5, "ROADWAY", "GEOM"];
    private _index = _hits findIf {[_x, _vehicle] call UF_fnc_isObstacle};
    private _ground = [_terrainHeight, surfaceNormal _posASL];

    if (_index != -1) then {
        (_hits select _index) params ["_hitPos", "_hitNormal"];

        _ground = [_hitPos select 2, _hitNormal];
    };

    if (((_ground select 0) < 0) && {surfaceIsWater _posASL}) then {
        _ground = [0, [0, 0, 1]];
    };

    _ground
};

// whether the box (8 corners ASL, the bottom ones first, both counterclockwise) would intersect the terrain or an
// object: rays along the bottom edges and along the four diagonals through the box
UF_fnc_boxBlocked = {
    params ["_corners", "_vehicle"];

    private _blockedRay = [[0, 1], [1, 2], [2, 3], [3, 0], [0, 6], [1, 7], [2, 4], [3, 5]] findIf {
        _x params ["_from", "_to"];

        private _hits = lineIntersectsSurfaces [
            _corners select _from,
            _corners select _to,
            _vehicle,
            objNull,
            true,
            5,
            "GEOM",
            "NONE"
        ];

        (_hits findIf {[_x, _vehicle] call UF_fnc_isObstacle}) != -1
    };

    _blockedRay != -1
};

// the pose of the vehicle upright on the ground below it: [position (setPosWorld), vectorDir, vectorUp]. Its up is the
// ground's normal below its centre, its heading is kept, its box centre stays where it is horizontally, its bottom
// ends up UF_var_lift above the highest ground below it, and higher while the box would still intersect something.
UF_fnc_uprightPose = {
    params ["_vehicle"];

    ([_vehicle] call UF_fnc_box) params ["_min", "_max"];

    private _center = (_min vectorAdd _max) vectorMultiply 0.5;
    ((_max vectorDiff _min) vectorMultiply 0.5) params ["_halfX", "_halfY", "_halfZ"];
    private _centerASL = _vehicle modelToWorldWorld _center;

    // up: the ground's normal below the centre; vertical where steeper than 60 deg (a wall's side, a cliff)
    private _up = ([_centerASL, _vehicle] call UF_fnc_groundBelow) select 1;

    if ((_up select 2) < 0.5) then {
        _up = [0, 0, 1];
    };

    _up = vectorNormalized _up;

    // the current forward direction; on its nose / tail that is (nearly) vertical, then the roof shows the heading:
    // for a pure roll or pitch [dir x - dir z * up x, dir y - dir z * up y] is the heading before the flip
    (vectorDir _vehicle) params ["_dirX", "_dirY", "_dirZ"];
    (vectorUp _vehicle) params ["_upX", "_upY"];
    private _heading = [_dirX - (_dirZ * _upX), _dirY - (_dirZ * _upY), 0];

    if ((vectorMagnitude _heading) < 0.01) then {
        _heading = [0, 1, 0];
    };

    private _right = vectorNormalized (_heading vectorCrossProduct _up);
    private _axes = [_right, _up vectorCrossProduct _right, _up];

    // the box corners relative to its centre in the new pose
    private _corners = [];

    {
        private _sideZ = _x;

        {
            private _offset = [(_x select 0) * _halfX, (_x select 1) * _halfY, _sideZ * _halfZ];

            _corners pushBack ([_offset, _axes] call UF_fnc_rotate);
        } forEach [[-1, -1], [1, -1], [1, 1], [-1, 1]];
    } forEach [-1, 1];

    // the centre height at which the bottom (corners and middle) clears the ground below each of its points; the rays
    // start at the current centre's height
    private _height = -10000;

    {
        private _point = (_centerASL vectorAdd _x) vectorAdd [0, 0, -(_x select 2)];
        private _ground = ([_point, _vehicle] call UF_fnc_groundBelow) select 0;

        _height = _height max (_ground - (_x select 2));
    } forEach ((_corners select [0, 4]) + [_up vectorMultiply -_halfZ]);

    _height = _height + UF_var_lift;

    for "_step" from 1 to UF_var_maxLiftSteps do {
        private _newCenter = [_centerASL select 0, _centerASL select 1, _height];

        if !([_corners apply {_newCenter vectorAdd _x}, _vehicle] call UF_fnc_boxBlocked) exitWith {};

        _height = _height + UF_var_liftStep;
    };

    private _newCenter = [_centerASL select 0, _centerASL select 1, _height];

    [_newCenter vectorDiff ([_center, _axes] call UF_fnc_rotate), _axes select 1, _up]
};

// ---- unflip ----

// no damage for _duration seconds where the vehicle is local (allowDamage acts there), then the state from before
// (_damageAllowed: a mission's invulnerable vehicle stays invulnerable). A protection that is still running is only
// extended (its "before" is the first one's); one whose vehicle moves to another machine is handed over with its
// remaining time. Called where the vehicle is local (also remoteExecCall'd to it).
UF_fnc_protect = {
    params ["_vehicle", "_duration", "_damageAllowed", ["_forwards", 0]];

    if (isNull _vehicle) exitWith {};

    if (!local _vehicle) exitWith {
        if (_forwards < UF_var_maxForwards) then {
            [_vehicle, _duration, _damageAllowed, _forwards + 1] remoteExecCall ["UF_fnc_protect", _vehicle];
        };
    };

    private _running = _vehicle getVariable ["UF_var_protection", []];   // [end time, damage allowed before]

    if (_running isNotEqualTo []) exitWith {
        _running set [0, (_running select 0) max (time + _duration)];
    };

    private _protection = [time + _duration, _damageAllowed];
    _vehicle setVariable ["UF_var_protection", _protection];
    _vehicle allowDamage false;

    [_vehicle, _protection] spawn {
        params ["_vehicle", "_protection"];

        waitUntil {
            sleep 0.1;
            isNull _vehicle || {time >= (_protection select 0)} || {!local _vehicle}
        };

        if (isNull _vehicle) exitWith {};

        _vehicle setVariable ["UF_var_protection", nil];
        _protection params ["_endTime", "_damageAllowed"];

        // the vehicle went to another machine (someone got in, the server moved it): the rest runs there
        if (!local _vehicle && {time < _endTime}) then {
            [_vehicle, _endTime - time, _damageAllowed] remoteExecCall ["UF_fnc_protect", _vehicle];
        };

        // also when the vehicle is remote now: resets this machine's own flag, does nothing else then
        _vehicle allowDamage _damageAllowed;
    };
};

// puts a flipped vehicle back on its wheels (UF_fnc_uprightPose), stops it and protects it from damage for
// UF_var_damageProtection seconds. remoteExecCall'd to the vehicle; one that changed its owner meanwhile is followed.
// _allowAiCrew: the AI unflip also turns vehicles that still hold AI.
UF_fnc_unflip = {
    params ["_vehicle", ["_allowAiCrew", false], ["_forwards", 0]];

    if (isNull _vehicle) exitWith {};

    if (!local _vehicle) exitWith {
        if (_forwards < UF_var_maxForwards) then {
            [_vehicle, _allowAiCrew, _forwards + 1] remoteExecCall ["UF_fnc_unflip", _vehicle];
        };
    };

    // checked again here: the vehicle may have been unflipped, entered or destroyed meanwhile
    if !([_vehicle, _allowAiCrew] call UF_fnc_canUnflip) exitWith {};

    ([_vehicle] call UF_fnc_uprightPose) params ["_posWorld", "_dir", "_up"];

    if (UF_var_damageProtection > 0) then {
        [_vehicle, UF_var_damageProtection, isDamageAllowed _vehicle] call UF_fnc_protect;
    };

    _vehicle setVectorDirAndUp [_dir, _up];
    _vehicle setPosWorld _posWorld;
    _vehicle setVelocity [0, 0, 0];
};

UF_var_clientServerInitDone = true;
