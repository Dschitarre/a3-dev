// HC-only, direction-independent visibility prediction. Rendering clients perform arithmetic, never rays.

if (!isNil "CU_var_compiled") exitWith {};

CU_var_compiled = true;
CU_var_worker = missionNamespace getVariable ["CU_var_worker", -1];
CU_var_hidden = createHashMap;
CU_var_views = createHashMap;
CU_var_jobs = createHashMap;
CU_var_indices = createHashMap;
CU_var_versions = createHashMap;
CU_var_entities = [];
CU_var_stats = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
CU_var_budgetMs = 3;
CU_var_serverFps = 50;
CU_var_tolerance = 0.15;
CU_var_lease = 0.25;
CU_var_pathSeconds = 2; // motion covered by a path certificate (see CU_fnc_beginJob)
CU_var_enabled = true;
CU_var_pathSpacing = 4; // maximum sample spacing in metres along a path certificate's long axes
CU_var_refresh = 0;
CU_var_cursor = -1;
CU_var_budgetAt = 0;
CU_var_statAt = diag_tickTime;
CU_var_checked = 0;
CU_var_rays = 0;
CU_var_cycles = createHashMap;
CU_var_contexts = createHashMap;
CU_var_shapes = createHashMap;
CU_var_blockerTypes = createHashMap;
CU_var_batchSize = 16;
CU_var_rayMs = 0.01;
CU_var_heartbeat = diag_tickTime;
CU_var_geometryRevision = 0;
CU_var_reuses = 0;
CU_var_distanceChecks = 0;
CU_var_workMs = 0;
CU_var_totalRays = 0;
CU_var_totalReuses = 0;
CU_var_totalWorkMs = 0;
CU_var_pendingAck = [];
CU_var_clientWorker = -1;
CU_var_totalRenderChanges = 0;
CU_var_frameRenderTotal = 0;
CU_var_worstRenderFrame = [];
CU_var_occluderFrames = createHashMap;
CU_var_animationNames = createHashMap;
CU_var_occluderRefs = createHashMap;
CU_var_resolvedRefs = createHashMap;
CU_var_nextKey = 0;
CU_var_catalogueVersion = 0;
CU_var_policies = createHashMap;
CU_var_visualClasses = createHashMap;
CU_var_catalogueAudit = [0, 0, 0]; // engine objects, renderable candidates, non-rendering helpers
CU_var_logCounts = createHashMap;
CU_var_logRejects = [];
CU_var_logInvalids = [];
CU_var_logViewGap = 0;
CU_fnc_renderable = {
    private _class = typeOf _this;
    private _eligible = CU_var_visualClasses getOrDefault [_class, -1];

    if (_eligible isEqualType 0) then {
        private _ammo = configFile >> "CfgAmmo" >> _class;
        private _projectile = isClass _ammo && {!((toLowerANSI getText (_ammo >> "simulation")) in ["shotmine", "shottimebomb"])};

        // Weapon holders are culled by every client itself by distance (CU_fnc_lootCullLoop), not by the HC.
        _eligible = !isNull _this && {!_projectile} && {_class select [0, 1] != "#"} &&
            {!(_this isKindOf "Logic")} && {!(_this isKindOf "HeadlessClient_F")} &&
            {!(_this isKindOf "WeaponHolder")} && {!(_this isKindOf "WeaponHolderSimulated")} &&
            {((getModelInfo _this) param [0, ""]) != ""};
        if (_class != "") then {CU_var_visualClasses set [_class, _eligible]};
    };

    _eligible
};

CU_fnc_policy = {
    params ["_entity"];

    private _class = typeOf _entity;
    private _policy = CU_var_policies getOrDefault [_class, []];

    if (_policy isEqualTo []) then {
        private _simulation = toLowerANSI getText (configFile >> "CfgVehicles" >> _class >> "simulation");

        _policy = switch true do {
            case (_entity isKindOf "CAManBase"): {["unit", 10, 0.25, false]};
            case (_entity isKindOf "WeaponHolderSimulated"): {["looseLoot", 10, 0.5, false]};
            case (_entity isKindOf "WeaponHolder"): {["groundLoot", 0, 1, true]};
            case (_entity isKindOf "Air"): {["aircraft", 20, 0.25, false]};
            case (_entity isKindOf "AllVehicles"): {["vehicle", 10, 0.5, false]};
            case (_simulation in ["thingx", "shotmine", "shotsubmunitions"]): {["physics", 10, 0.5, false]};
            default {["static", 0, 2, true]};
        };

        CU_var_policies set [_class, _policy];
    };

    if ((_policy select 3) && {!isNull attachedTo _entity}) then {["attached", 20, 0.25, false]} else {_policy}
};

CU_fnc_targetPose = {
    params ["_entity", "_static"];

    if (!_static) exitWith {getPosWorld _entity};

    private _pose = _entity getVariable ["CU_var_targetPose", []];

    if (_pose isEqualTo [] || {diag_tickTime >= (_pose select 0)}) then {
        _pose = [diag_tickTime + 1, getPosWorld _entity];
        _entity setVariable ["CU_var_targetPose", _pose]
    };

    _pose select 1
};

CU_fnc_key = {
    params ["_object"];

    private _key = _object getVariable ["CU_var_cacheKey", ""];

    if (_key == "") then {
        CU_var_nextKey = CU_var_nextKey + 1;
        _key = str CU_var_nextKey;
        _object setVariable ["CU_var_cacheKey", _key]
    };

    _key
};

// Terrain objects often have no network ID. Send Visitor IDs, never assume a HC object reference survives an RPC.
CU_fnc_occluderRef = {
    params ["_object"];

    private _ref = _object getVariable ["CU_var_occluderRef", []];

    if (_ref isEqualTo []) then {
        private _net = netId _object;

        _ref = if !(_net in ["", "0:0"]) then {["net", _net]} else {
            if ((getObjectType _object) in [1, 2]) then {["map", getObjectID _object, getPosWorld _object]} else {["local", _object]}
        };

        _object setVariable ["CU_var_occluderRef", _ref];
    };

    _ref
};

CU_fnc_resolveOccluder = {
    params ["_ref"];

    _ref params ["_kind", "_id"];

    if (_kind == "local") exitWith {_id};

    private _key = _kind + _id;
    private _object = CU_var_resolvedRefs getOrDefault [_key, objNull];

    if (isNull _object) then {
        _object = if (_kind == "net") then {objectFromNetId _id} else {(_ref select 2) nearestObject _id};
        if (!isNull _object) then {CU_var_resolvedRefs set [_key, _object]};
    };

    _object
};

// Transform/animation reads are memoized for CU_var_occluderCheckInterval and shared across every certificate using
// a wall. A spatial proof remains useful while its actual occluders stay unchanged; no blind two-second hide expiry.
// Only animations that open a passage (doors, gates, hatches, shutters, ramps) can change what a wall hides; reading
// every animation of every house (glass, hit zones, lights; dozens per building) on the client in each sweep took the
// scheduler's whole per-frame budget and cost client FPS. A passage opens over about a second, the 0.2 s cache is far
// shorter than that.
CU_var_occluderCheckInterval = 0.2;
CU_fnc_occluderSignature = {
    params ["_object"];

    if (isNull _object) exitWith {[]};

    private _cached = _object getVariable ["CU_var_occluderFrame", []];
    if (_cached isNotEqualTo [] && {diag_tickTime - (_cached select 0) < CU_var_occluderCheckInterval}) exitWith {_cached select 1};

    private _class = typeOf _object;
    private _names = CU_var_animationNames getOrDefault [_class, []];

    if (isNil {CU_var_animationNames get _class}) then {
        _names = (animationNames _object) select {
            private _n = toLowerANSI _x;
            ["door", "gate", "hatch", "shutter", "ramp"] findIf {_x in _n} >= 0
        };

        CU_var_animationNames set [_class, _names];
    };

    private _transform = if ((getObjectType _object) in [1, 2]) then {
        private _fixed = _object getVariable ["CU_var_fixedTransform", []];

        if (_fixed isEqualTo []) then {
            _fixed = [getPosWorld _object, vectorDir _object, vectorUp _object];
            _object setVariable ["CU_var_fixedTransform", _fixed]
        };

        _fixed
    } else {[getPosWorld _object, vectorDir _object, vectorUp _object]};

    private _signature = _transform+[damage _object, _names apply {_object animationPhase _x}];
    _object setVariable ["CU_var_occluderFrame", [diag_tickTime, _signature]];
    _signature
};

CU_fnc_occludersValid = {
    params ["_record"];

    ((_record param [12, []]) findIf {
        private _object = [_x select 0] call CU_fnc_resolveOccluder;
        isNull _object || {!(([_object] call CU_fnc_occluderSignature) isEqualTo (_x select 1))}

    }) < 0
};

CU_fnc_register = {
    params ["_slot", "_owner"];

    if(!isServer || {_owner <= 2} || {isNull _slot} || {!(_slot isKindOf "HeadlessClient_F")} ||
        {owner _slot != _owner} || {!(remoteExecutedOwner in [0, _owner])}) exitWith {};

    if (CU_var_worker > 2 && {CU_var_worker != _owner} && {(allMissionObjects "HeadlessClient_F") findIf {owner _x == CU_var_worker} >= 0}) exitWith {};

    if (CU_var_worker != _owner) then {diag_log format ["CULLING|REGISTER|owner=%1", _owner]};
    CU_var_worker = _owner;
    publicVariable "CU_var_worker";
};

// `owner object` only returns an owner ID on the server, never on the HC.
// Authenticate there and forward the original timestamp and explicit destination owner to the worker.
CU_fnc_submitView = {
    if (!isServer || {!isRemoteExecuted} || {CU_var_worker <= 2} || {count _this != 10}) exitWith {};

    private _unit = _this param [0, objNull];
    private _sender = remoteExecutedOwner;
    if (isNull _unit || {!isPlayer _unit} || {_sender <= 2} || {owner _unit != _sender} || {_unit isKindOf "HeadlessClient_F"}) exitWith {};

    CU_var_logCounts set ["viewsForwarded", 1 + (CU_var_logCounts getOrDefault ["viewsForwarded", 0])];
    (_this+[_sender]) remoteExecCall ["CU_fnc_view", CU_var_worker];
};

CU_fnc_view = {
    params ["_unit", "_camera", "_velocity", "_range", "_sequence", "_sent", "_epoch", "_orbit", "_transit", ["_ignore", objNull]];

    if (hasInterface || {isServer} || {!isRemoteExecuted} || {remoteExecutedOwner != 2} || {count _this != 11}) exitWith {};

    private _sender = _this param [10, -1];
    if (_sender <= 2 || {isNull _unit} || {!isPlayer _unit}) exitWith {};

    if (count _camera != 3 || {count _velocity != 3}) exitWith {};

    private _pivot = _camera;

    if (_orbit isEqualType []) then {
        _pivot = _orbit param [1, _camera];
        _orbit = _orbit param [0, 0]
    };

    if (count _pivot != 3) exitWith {};

    private _key = str _sender;
    private _old = CU_var_views getOrDefault [_key, []];
    if (_old isNotEqualTo [] && {_sequence <= (_old select 4)}) exitWith {};

    CU_var_views set [_key,
        [_unit, _camera, _velocity, 0 max (12000 min _range), _sequence, _sent, _epoch,
        0 max (50 min _orbit), 0.01 max (2 min _transit), _ignore, diag_tickTime, _pivot]];
    CU_var_logCounts set ["viewsReceived", 1 + (CU_var_logCounts getOrDefault ["viewsReceived", 0])];

    // Immediate acknowledgement measures transport/dispatch, never the geometry queue's execution time.
    if (_sequence mod 10 == 0) then {[clientOwner, _sent] remoteExecCall ["CU_fnc_viewAck", _sender]};
};

CU_fnc_viewAck = {
    params ["_worker", "_sent"];

    if (!hasInterface || {_worker != CU_var_worker} || {!(remoteExecutedOwner in [0, _worker])}) exitWith {};

    private _sample = 0.01 max (2 min (serverTime - _sent));
    CU_var_transit = 0.8 * CU_var_transit + 0.2 * _sample;
    CU_var_heartbeat = diag_tickTime;
};

CU_fnc_submitAck = {
    params ["_unit", "_acks"];

    if (!isServer || {!isRemoteExecuted} || {CU_var_worker <= 2}) exitWith {};

    private _sender = remoteExecutedOwner;
    if (isNull _unit || {_sender <= 2} || {!isPlayer _unit} || {owner _unit != _sender} || {_unit isKindOf "HeadlessClient_F"}) exitWith {};

    CU_var_logCounts set ["acksForwarded", count _acks + (CU_var_logCounts getOrDefault ["acksForwarded", 0])];
    [_sender, _acks] remoteExecCall ["CU_fnc_ack", CU_var_worker];
};

CU_fnc_ack = {
    params ["_sender", "_acks"];

    if (hasInterface || {isServer} || {!isRemoteExecuted} || {remoteExecutedOwner != 2}) exitWith {};

    private _context = CU_var_contexts getOrDefault [str _sender, []];
    if (_context isEqualTo []) exitWith {};

    private _states = _context select 0;

    {
        _x params ["_entity", "_version", "_accepted"];

        if (!isNull _entity) then {
            private _state = _states getOrDefault [[_entity] call CU_fnc_key, []];

            if (_state isNotEqualTo []) then {
                private _record = _state select 1;

                if (_record isNotEqualTo [] && {(_record select 9) == _version}) then {
                    _state set [3, _accepted];
                    if (!_accepted) then {_state set [1, []]};
                };
            };
        };
    } forEach _acks;
};

CU_fnc_serverLoad = {if (isRemoteExecuted && {remoteExecutedOwner == 2}) then {CU_var_serverFps = _this select 0}};

CU_fnc_workerStats = {
    params ["_worker", "_stats"];

    if (!isServer || {_worker != CU_var_worker} || {!(remoteExecutedOwner in [0, _worker])} || {count _stats != 10}) exitWith {};

    CU_var_stats = _stats;
    publicVariable "CU_var_stats";
};

CU_fnc_reveal = {params ["_entity"];
    if (!isNull _entity) then {
        _entity setVariable ["CU_var_culled", false];

        if (!(_entity isKindOf "CAManBase" && {alive _entity} && {!simulationEnabled _entity}) && {isObjectHidden _entity}) then {
            _entity hideObject false;
            CU_var_totalRenderChanges = CU_var_totalRenderChanges + 1;
            CU_var_logCounts set ["actualShows", 1 + (CU_var_logCounts getOrDefault ["actualShows", 0])];
        };

    }};

CU_fnc_restore = {

    // Atomic with respect to incoming unscheduled packets: never lose a newly received hide during a reset.
    isNil {
        CU_var_logCounts set ["resetObjects", count CU_var_hidden + (CU_var_logCounts getOrDefault ["resetObjects", 0])];

        {
            [_y select 0] call CU_fnc_reveal;
            CU_var_pendingAck pushBack [_y select 0, _y select 1, false]
        } forEach CU_var_hidden;

        CU_var_hidden = createHashMap;
    };
};

CU_fnc_inside = {
    params ["_point", "_center", "_extent"];

    private _d = _point vectorDiff _center;
    abs (_d select 0) <= (_extent select 0) && {abs (_d select 1) <= (_extent select 1)} && {abs (_d select 2) <= (_extent select 2)}
};

// The client never validates proofs: the HC decides hide and show, the client only applies them. Protected are the
// player's own unit/vehicle and the camera's focus, and objects a game mode hid itself.
CU_fnc_protected = {
    params ["_entity"];

    _entity == player || {_entity == vehicle player} || {_entity == cameraOn} || {_entity == vehicle cameraOn}
};

CU_fnc_applyRecords = {
    params ["_records", "_show"];

    private _acks = [];
    private _acceptedCount = 0;

    {
        _x params ["_entity", "_version", ["_modeHidden", false]];

        private _key = netId _entity;
        if (_version >= (CU_var_versions getOrDefault [_key, -1])) then {CU_var_versions set [_key, _version];
            if (!isNil {CU_var_hidden get _key}) then {
                if (!_modeHidden) then {[_entity] call CU_fnc_reveal} else {_entity setVariable ["CU_var_culled", false]};
                CU_var_hidden deleteAt _key
            }};
    } forEach _show;

    {
        _x params ["_entity", "_version"];

        private _key = netId _entity;
        private _accepted = false;

        if (!isNull _entity && {_version >= (CU_var_versions getOrDefault [_key, -1])}) then {
            CU_var_versions set [_key, _version];

            if (!([_entity] call CU_fnc_protected) && {!isObjectHidden _entity || {!isNil {CU_var_hidden get _key}}}) then {
                if (!isObjectHidden _entity) then {
                    _entity hideObject true;
                    CU_var_totalRenderChanges = CU_var_totalRenderChanges + 1;
                    CU_var_logCounts set ["actualHides", 1 + (CU_var_logCounts getOrDefault ["actualHides", 0])];
                };

                _entity setVariable ["CU_var_culled", true];
                CU_var_hidden set [_key, [_entity, _version]];
                _accepted = true;
            };
        };

        _acks pushBack [_entity, _version, _accepted];
        if (_accepted) then {_acceptedCount = _acceptedCount + 1};
    } forEach _records;

    CU_var_logCounts set ["hideReceived", count _records + (CU_var_logCounts getOrDefault ["hideReceived", 0])];
    CU_var_logCounts set ["hideAccepted", _acceptedCount + (CU_var_logCounts getOrDefault ["hideAccepted", 0])];
    CU_var_logCounts set ["showReceived", count _show + (CU_var_logCounts getOrDefault ["showReceived", 0])];
    _acks
};

CU_fnc_result = {
    params ["_worker", "_sequence", "_sent", "_epoch", "_records", "_show"];

    if (!hasInterface || {_worker != CU_var_worker} || {!(remoteExecutedOwner in [0, _worker])} || {!CU_var_enabled}) exitWith {};

    CU_var_heartbeat = diag_tickTime;
    private _acks = [_records, _show] call CU_fnc_applyRecords;
    if (_acks isNotEqualTo []) then {[player, _acks] remoteExecCall ["CU_fnc_submitAck", 2]};
};

// Swept bounding volume: present position, velocity prediction, acceleration reserve, and camera orbit.
CU_fnc_volume = {
    params ["_position", "_velocity", "_horizon", "_margin", "_acceleration"];

    private _shift = _velocity vectorMultiply _horizon;
    private _reserve = _margin + 0.5 * _acceleration * _horizon * _horizon;
    [_position vectorAdd (_shift vectorMultiply 0.5),
        [abs (_shift select 0) * 0.5 + _reserve, abs (_shift select 1) * 0.5 + _reserve,
        abs (_shift select 2) * 0.5 + _reserve]]
};

// Grid over an elongated path volume. Sample spacing stays bounded (CU_var_pathSpacing), so a longer certificate
// is tested as densely as a short one instead of stretching 15 samples over a larger region.
CU_fnc_gridSamples = {
    params ["_center", "_extent"];

    private _points = [_center];

    private _axes = [0, 1, 2] apply {
        private _e = _extent select _x;
        private _n = if(_x == 2) then {[2,
            3] select (_e > CU_var_pathSpacing)} else {2 max (12 min (1 + ceil (2 * _e / CU_var_pathSpacing))
            )};
        private _values = [];
        for "_i" from 0 to (_n - 1) do {_values pushBack (-_e + 2 * _e * _i / (_n - 1))};
        _values
    };

    {private _sx = _x;
        {
            private _sy = _x;
            {_points pushBack (_center vectorAdd [_sx, _sy, _x])} forEach (_axes select 2)
        } forEach (_axes select 1)} forEach (_axes select 0);

    _points
};

CU_fnc_samples = {
    params ["_center", "_extent"];

    private _points = [_center];
    {private _sx = _x;
        {
            private _sy = _x;
            {_points pushBack (_center vectorAdd [_sx *(_extent select 0), _sy *(_extent select 1),
                _x *(_extent select 2)])} forEach [-1, 1]
        } forEach [-1, 1]} forEach [-1, 1];

    {_points pushBack (_center vectorAdd _x)} forEach [[_extent select 0, 0, 0],
        [-(_extent select 0), 0, 0],[0, _extent select 1, 0],[0, -(_extent select 1), 0],
        [0, 0, _extent select 2],[0, 0, -(_extent select 2)]];
    _points
};

CU_fnc_beginJob = {
    params ["_entity", "_view", ["_lease", CU_var_lease]];

    _view params ["_unit", "_camera", "_velocity", "_range", "_sequence", "_sent", "_epoch", "_orbit", "_transit", "_ignore"];

    private _policy = [_entity] call CU_fnc_policy;
    _policy params ["_kind", "_acceleration", "", "_static"];

    private _pos = [_entity, _static] call CU_fnc_targetPose;
    private _objectVelocity = if (_static) then {[0, 0, 0]} else {velocity _entity};
    private _class = typeOf _entity;
    private _shape = CU_var_shapes getOrDefault [_class, []];

    if (_shape isEqualTo []) then {
        private _box = boundingBoxReal _entity;
        private _center = ((_box select 0) vectorAdd (_box select 1)) vectorMultiply 0.5;
        private _half = ((_box select 1) vectorDiff (_box select 0)) vectorMultiply 0.575;

        if (_entity isKindOf "CAManBase") then {
            _center = [0, 0, 0.9];
            _half = [1.5, 1.5, 1.2]
        };

        _shape =[1 + 1.25 *(vectorMagnitude (_box select 0) max vectorMagnitude (_box select 1)),
            _entity isKindOf "WeaponHolder" || {_entity isKindOf "WeaponHolderSimulated"}, _center, _half];
        CU_var_shapes set [_class, _shape];
    };

    _shape params ["_radius", "_loot"];

    private _version = diag_tickTime;
    private _empty =[_entity, serverTime + 5, _epoch, _camera,[0, 0, 0], _pos,[0, 0, 0], "clear",
        _range, _version, _radius, CU_var_geometryRevision,[], netId _entity, _kind];
    if(isNull _entity || {_entity == _unit} || {_entity == vehicle _unit} || {_entity == _ignore} ||
        {_entity isKindOf "HeadlessClient_F"} ||
        {_entity isKindOf "CAManBase" && {alive _entity} && {!simulationEnabled _entity}}) exitWith {[_empty,
        [],[], 0, 0, _ignore, _sequence, _sent, _epoch]};

    if (isObjectHidden _entity && {isNil {CU_var_hidden get(netId _entity)}}) exitWith {
        _empty set [7, "modeHidden"];
        [_empty, [], [], 0, 0, _ignore, _sequence, _sent, _epoch]
    };

    // Broad phase: scalar squared-distance tests BEFORE volume/samples/ray preparation. Far objects cost zero rays.
    CU_var_distanceChecks = CU_var_distanceChecks + 1;
    private _distanceSqr = _camera distanceSqr _pos;
    private _lead = 2 + (vectorMagnitude _velocity + vectorMagnitude _objectVelocity) * (0.5 * _transit + CU_var_tolerance);
    private _limit = if (_loot) then {30} else {_range + _radius};

    if (_distanceSqr > (_limit + _lead)^2) exitWith {
        _empty set [1, 1e12];
        _empty set [7, ["range", "loot"] select _loot];
        [_empty, [], [], 0, 1, _ignore, _sequence, _sent, _epoch]
    };

    if (_loot || {_distanceSqr < (30 + _radius)^2}) exitWith {[_empty, [], [], 0, 0, _ignore, _sequence, _sent, _epoch]};

    // Transit is measured round-trip. Orbit is centred on the actual eye/vehicle pivot, not a
    // double-radius cube around the current camera (which imagined cameras on the far side of walls).
    private _horizon = (0 max (serverTime - _sent)) + 0.5 * _transit + CU_var_tolerance + _lease;
    private _camReserve = 0.35 + _orbit + 4 * _horizon * _horizon;
    private _objReserve = 0.75 + 0.5 * _acceleration * _horizon * _horizon;
    private _cam = [_view param [11, _camera], _velocity, _horizon, _camReserve, 0] call CU_fnc_volume;
    private _obj = [_pos, _objectVelocity, _horizon, _objReserve, 0] call CU_fnc_volume;

    // Transform the model's box, not its bounding sphere: a long vehicle must not acquire an imaginary tall roof.
    private _half = _shape select 3;
    private _forward = vectorDir _entity;
    private _up = vectorUp _entity;
    private _right = _forward vectorCrossProduct _up;
    private _worldHalf = [];
    for "_axis" from 0 to 2 do {_worldHalf pushBack (abs (_right select _axis) *(_half select 0) + abs (_forward
        select _axis) *(_half select 1) + abs (_up select _axis) *(_half select 2) + 0.25)};
    private _extent = (_obj select 1) vectorAdd _worldHalf;
    private _targetCenter = (_obj select 0) vectorAdd ((_entity modelToWorldWorld(_shape select 2)) vectorDiff _pos);
    private _record =[_entity, 1e12, _epoch, _cam select 0, _cam select 1, _obj select 0, _obj select 1,
        "occlusion", _range, _version, _radius, CU_var_geometryRevision,[], netId _entity, _kind];
    private _cameras = _cam call CU_fnc_samples;
    private _targets = [_targetCenter, _extent] call CU_fnc_samples;
    private _tight = [_record, _cameras, _targets, 0, -1, _ignore, _sequence, _sent, _epoch, createHashMap];

    // A short certificate covers only ~0.6 s of motion: every moving target (and, for a moving camera, every
    // certificate at once) became invalid after about one second although nothing had come into view, which
    // forced reveal/re-hide cycles. The path certificate covers CU_var_pathSeconds of the CURRENT motion of
    // camera and target, tested on a grid with the same bounded sample spacing. It is not a longer timeout:
    // the client still checks the real positions every sweep and reveals as soon as either leaves the region.
    private _camMoving = vectorMagnitude _velocity > 0.5;
    private _objMoving = vectorMagnitude _objectVelocity > 0.5;
    if (!_camMoving && {!_objMoving}) exitWith {_tight};

    // With camera or target moving, the short certificate expires after about a second. Such a hide is followed by a
    // reveal almost at once; each pair costs the client more than the second without the object. It is used only if
    // the path certificate fails, and then it does not hide (CU_fnc_processView).
    _tight pushBack [];
    _tight pushBack "short";
    private _pathHorizon = _horizon + CU_var_pathSeconds;
    private _camPath = if(_camMoving) then {[_view param [11, _camera], _velocity, _pathHorizon,
        _camReserve, 0] call CU_fnc_volume} else {_cam};
    private _objPath = if (_objMoving) then {[_pos, _objectVelocity, _pathHorizon, _objReserve, 0] call CU_fnc_volume} else {_obj};
    private _path = +_record;
    _path set [3, _camPath select 0];
    _path set [4, _camPath select 1];
    _path set [5, _objPath select 0];
    _path set [6, _objPath select 1];

    // The first ray equals the short certificate's centre ray, so a clear centre settles both attempts at once.
    private _pathCameras = if (_camMoving) then {[_cameras select 0] + (_camPath call CU_fnc_gridSamples)} else {_cameras};

    private _pathTargets = if (_objMoving) then {
        [_targets select 0] +([(_objPath select 0) vectorAdd (_targetCenter vectorDiff (_obj select 0)),
            (_objPath select 1) vectorAdd _worldHalf] call CU_fnc_gridSamples)
    } else {_targets};

    [_path, _pathCameras, _pathTargets, 0, -1, _ignore, _sequence, _sent, _epoch, createHashMap, _tight]
};

// Native parallel batches include terrain as well as VIEW geometry. A clear centre ends the job immediately;
// only an occluded candidate needs its expanded-volume cross product. Chunks bound single-call work.
CU_fnc_stepJob = {
    params ["_job"];

    _job params ["_record", "_cameras", "_targets", "_index", "_verdict", "_ignore"];

    if (hasInterface || {isServer}) exitWith {
        _job set [4, 0];
        true
    };

    if (_verdict >= 0) exitWith {true};

    private _rays = [];
    private _long = [];
    private _remaining = count _cameras * count _targets - _index;
    private _amount = if (_index == 0) then {1} else {CU_var_batchSize min _remaining};

    for "_i" from _index to (_index + _amount - 1) do {
        private _from = _cameras select (floor (_i / count _targets));
        private _to = _targets select (_i mod count _targets);
        if(_from distanceSqr _to > 24990000) then {_long pushBack [_from, _to]} else {_rays pushBack [_from,
            _to, _ignore, _record select 0, true, 8, "VIEW", "NONE"]};
    };

    private _start = diag_tickTime;
    private _intersections = if (_rays isEqualTo []) then {[]} else {lineIntersectsSurfaces[_rays]};
    private _proof = _job param [9, createHashMap];

    private _clear = (_intersections findIf {

        // Prefer an immutable terrain blocker over incidental doors/walls on the same ray.
        // Their animation/destruction must not invalidate a ray already stopped by a mountain.
        if ((_x findIf {isNull (_x select 2) && {isNull (_x select 3)}}) >= 0) then {false} else {(_x findIf {
                private _blocker = _x select 3;
                if (isNull _blocker) then {_blocker = _x select 2};
                if (isNull _blocker) then {true} else { // terrain is returned by the native ray command
                    private _class = typeOf _blocker;
                    private _meta = CU_var_blockerTypes getOrDefault [_class, []];

                    if (_meta isEqualTo []) then {
                        _meta = [!(_blocker isKindOf "AllVehicles"), ([_blocker] call CU_fnc_policy) select 3];
                        CU_var_blockerTypes set [_class, _meta]
                    };

                    private _valid =(_meta select 0) && {isNull attachedTo _blocker} &&
                        {(_meta select 1) || {vectorMagnitudeSqr velocity _blocker < 0.0001}};
                    private _key = [_blocker] call CU_fnc_key;
                    if(_valid &&
                        {isNil {_proof get _key}}) then {_proof set [_key,
                        [[_blocker] call CU_fnc_occluderRef,[_blocker] call CU_fnc_occluderSignature]]};
                    _valid
                }

            }) < 0}

    }) >= 0;

    // The engine's surface command has a hard 5 km limit. Full-length terrain tests retain safe far-mountain culling.
    if (!_clear) then {_clear = (_long findIf {!terrainIntersectASL _x}) >= 0};
    CU_var_rays = CU_var_rays + _amount;
    CU_var_totalRays = CU_var_totalRays + _amount;
    CU_var_rayMs = 0.9 * CU_var_rayMs + 0.1 * ((diag_tickTime - _start) * 1000 / (_amount max 1));

    if (_clear) exitWith {
        private _fallback = _job param [10, []];

        if (_fallback isEqualTo []) then {
            _job set [4, 0];
            true
        } else {

            _job resize 0;
            _job append _fallback;

            if (_index == 0 && {_amount == 1}) then {
                _job set [4, 0];
                true
            } else {false}
        }
    };

    _index = _index + _amount;
    _job set [3, _index];

    if (_index >= count _cameras * count _targets) then {
        _record set [12, values _proof];
        _job set [4, 1];
        true
    } else {false}
};

// One queued entry per object and viewer. Heap operations are O(log N), never a full scan to find the next deadline.
CU_fnc_pushDue = {
    params ["_heap", "_entry"];

    private _i = count _heap;
    _heap pushBack _entry;

    while {_i > 0} do {
        private _p = floor ((_i - 1) / 2);
        if (((_heap select _p) select 0) <= (_entry select 0)) exitWith {};

        _heap set [_i, _heap select _p];
        _i = _p
    };

    _heap set [_i, _entry];
};

CU_fnc_popDue = {
    params ["_heap"];

    private _root = _heap select 0;
    private _last = _heap deleteAt (count _heap - 1);

    if (_heap isNotEqualTo []) then {
        private _i = 0;
        private _n = count _heap;

        while {2 * _i + 1 < _n} do {
            private _child = 2 * _i + 1;
            if (_child + 1 < _n && {((_heap select (_child + 1)) select 0) < ((_heap select _child) select 0)}) then {_child = _child + 1};
            if ((_last select 0) <= ((_heap select _child) select 0)) exitWith {};

            _heap set [_i, _heap select _child];
            _i = _child;
        };

        _heap set [_i, _last];
    };

    _root
};

CU_fnc_covered = {
    params ["_record", "_view", ["_refreshAhead", 0]];

    private _reason = _record select 7;

    if (_reason in ["range", "loot"]) exitWith {
        private _entity = _record select 0;
        if(isNull _entity || {isObjectHidden _entity} || {_entity ==(_view select 0)} ||
            {_entity == vehicle (_view select 0)} || {_entity ==(_view select 9)} ||
            {_entity isKindOf "CAManBase" && {alive _entity} &&
            {!simulationEnabled _entity}}) exitWith {false};

        private _static = (_record param [14, ""]) in ["static", "groundLoot"];
        private _speed = if (_static) then {0} else {vectorMagnitude velocity _entity};
        private _limit = if (_reason == "loot") then {30} else {(_view select 3) + (_record select 10)};
        private _lead = 2 + (vectorMagnitude(_view select 2) + _speed) * (0.5 * (_view select 8) + CU_var_tolerance + _refreshAhead);
        (_view select 1) distanceSqr ([_entity, _static] call CU_fnc_targetPose) > (_limit + _lead)^2
    };

    if (_reason != "occlusion") exitWith {false};

    // _refreshAhead: the proof must still hold that much later (next check, renewal ahead of time).
    private _lead = 0.5 * (_view select 8) + CU_var_tolerance + _refreshAhead;
    private _entity = _record select 0;
    private _static = (_record param [14, ""]) in ["static", "groundLoot"];
    private _pos = [_entity, _static] call CU_fnc_targetPose;
    private _future = if (_static) then {_pos} else {_pos vectorAdd ((velocity _entity) vectorMultiply _lead)};
    (_record select 11) == CU_var_geometryRevision && {serverTime < _record select 1} &&
        {[_view select 1, _record select 3, _record select 4] call CU_fnc_inside} &&
        {[(_view select 1) vectorAdd ((_view select 2) vectorMultiply _lead), _record select 3,
        _record select 4] call CU_fnc_inside} &&
        {[_pos, _record select 5, _record select 6] call CU_fnc_inside} &&
        {[_future, _record select 5, _record select 6] call CU_fnc_inside} &&
        {[_record] call CU_fnc_occludersValid}
};

// Seconds until a hidden record must be checked again. The HC alone decides when it becomes invalid, so it is checked
// often enough that a show arrives before that: distance proofs by their slack at the current approach speed,
// occlusion proofs every quarter second (cheap containment and occluder tests, no rays).
CU_fnc_checkDelay = {
    params ["_record", "_view", "_policy"];

    private _reason = _record select 7;

    if (_reason in ["range", "loot"]) exitWith {
        private _entity = _record select 0;
        private _static = (_record param [14, ""]) in ["static", "groundLoot"];
        private _speed = vectorMagnitude(_view select 2) + (if (_static) then {0} else {vectorMagnitude velocity _entity});
        private _limit = if (_reason == "loot") then {30} else {(_view select 3) + (_record select 10)};
        private _slack = ((_view select 1) distance([_entity, _static] call CU_fnc_targetPose)) - _limit - 2;
        0.25 max (_policy min (0.5 * _slack / (_speed + 1)))
    };

    0.25 min _policy
};

CU_fnc_refreshEntities = {

    // A remote mission-root query can omit units that remain in allUnits/crew registries. Union the engine
    // registries explicitly, with linear hash deduplication; never include internal Supply/backpack proxies.
    private _all = (allMissionObjects "") + allUnits + vehicles + allDead;
    private _seen = createHashMap;
    CU_var_entities = [];

    {
        if (!isNull _x && {_x call CU_fnc_renderable}) then {
            private _key = [_x] call CU_fnc_key;

            if (isNil {_seen get _key}) then {
                _seen set [_key, true];
                CU_var_entities pushBack _x
            };
        };
    } forEach _all;

    CU_var_catalogueAudit = [count _all, count CU_var_entities, count _all - count CU_var_entities];
    CU_var_refresh = diag_tickTime + 2;
    CU_var_catalogueVersion = CU_var_catalogueVersion + 1;
};

CU_fnc_syncContext = {
    params ["_context", ["_limit", 16]];

    _context params ["_states", "_heap"];

    private _scan = _context param [3, [[], 0, -1]];
    _scan params ["_snapshot", "_cursor", "_version"];

    if (_cursor >= count _snapshot && {_version != CU_var_catalogueVersion}) then {
        _snapshot = CU_var_entities;
        _cursor = 0;
        _version = CU_var_catalogueVersion
    };

    private _end = (_cursor + _limit) min count _snapshot;

    // Stable object keys, bounded discovery work. A new catalogue never resets results or discards an unfinished scan.
    for "_i" from _cursor to (_end - 1) do {
        private _entity = _snapshot select _i;
        if (!isNull _entity) then {private _key = [_entity] call CU_fnc_key;
            if (isNil {_states get _key}) then {
                _states set [_key, [_entity, [], 0]];
                [_heap, [diag_tickTime, _entity, _key]] call CU_fnc_pushDue
            }};
    };

    _context set [3, [_snapshot, _end, _version]];
};

CU_fnc_processView = {
    params ["_key", "_view", "_context", "_packets"];

    [_context] call CU_fnc_syncContext;
    _context params ["_states", "_heap", "_job"];

    private _state = [];
    private _progress = false;

    if (_job isEqualTo []) then {
        if (_heap isEqualTo [] || {((_heap select 0) select 0) > diag_tickTime}) exitWith {false};

        private _due = [_heap] call CU_fnc_popDue;
        private _entity = _due select 1;

        if (isNull _entity) exitWith {
            _states deleteAt (_due param [2, ""]);
            _progress = true
        };

        _state = _states get ([_entity] call CU_fnc_key);
        private _old = _state select 1;
        private _reused = false;

        if (_old isNotEqualTo []) then {
            private _delay = [_old, _view, ([_entity] call CU_fnc_policy) select 2] call CU_fnc_checkDelay;

            if ([_old, _view, _delay + CU_var_lease] call CU_fnc_covered) then {
                if !(_state param [3, false]) then {
                    private _packet = _packets getOrDefaultCall [_key,
                        {[clientOwner, _view select 4, _view select 5, _view select 6,[],[]]}, true];
                    (_packet select 4) pushBack [_entity, _old select 9];
                };

                CU_var_reuses = CU_var_reuses + 1;
                CU_var_totalReuses = CU_var_totalReuses + 1;
                [_heap, [diag_tickTime + _delay, _entity, [_entity] call CU_fnc_key]] call CU_fnc_pushDue;
                _reused = true;
            } else {

                // It will not hold until the next check: show it now (the client no longer checks), then try to renew.
                if !([_old, _view, _delay] call CU_fnc_covered) then {
                    private _packet = _packets getOrDefaultCall [_key,
                        {[clientOwner, _view select 4, _view select 5, _view select 6,[],[]]}, true];
                    (_packet select 5) pushBack [_entity, _old select 9, false];
                    _state set [1, []];
                    _state set [3, false];
                    CU_var_logCounts set ["shownExpiring:" + (_old select 7), 1 + (CU_var_logCounts getOrDefault ["shownExpiring:" + (_old select 7), 0])];
                };
            };
        };

        if (_reused) exitWith {_progress = true};

        _job = [_entity, _view] call CU_fnc_beginJob;
        _context set [2, _job];
    };

    // SQF exitWith above exits only its scope: distinguish the no-job reuse/sleep path explicitly.
    if (_job isEqualTo []) exitWith {_progress};

    private _entity = (_job select 0) select 0;

    if (isNull _entity) exitWith {
        _context set [2, []];
        true
    };

    private _entityKey = [_entity] call CU_fnc_key;
    _state = _states getOrDefault [_entityKey, [_entity, [], 0]];

    if ([_job] call CU_fnc_stepJob) then {
        _job params ["_record", "", "", "", "_hide", "", "_sequence", "_sent", "_epoch"];

        if ((_record select 7) == "occlusion" && {!([_record, _view] call CU_fnc_covered)}) then {_hide = 0};

        if (_hide == 1 && {(_job param [11, ""]) == "short"}) then {
            _hide = 0;
            _record = +_record;
            _record set [7, "shortLived"]
        };

        private _old = _state select 1;
        private _keepOld = _hide == 0 && {(_record select 7) != "modeHidden"} && {_old isNotEqualTo []} &&
            {(_old select 7) == "occlusion"} && {[_old, _view] call CU_fnc_covered};

        if (_keepOld) then {
            _hide = 1;
            _record = _old
        };

        // Exact far-distance records need no lease renewals or redundant packets while their reason stays the same.
        private _same = _hide == 1 && {_old isNotEqualTo []} && {(_record select 7) in ["range", "loot"]} && {(_record select 7) == (_old select 7)};
        if (_same) then {_record = _old};
        private _unchanged = (_same || {_keepOld}) && {_state param [3, false]};

        if (!_unchanged && {_hide == 1 || {_old isNotEqualTo []}}) then {
            private _packet = _packets getOrDefaultCall[_key, {[clientOwner, _sequence, _sent, _epoch, [], []]}, true];
            if(_hide == 1) then {(_packet select 4) pushBack [_entity,
                _record select 9]} else {(_packet select 5) pushBack [_entity, _record select 9,
                (_record select 7) == "modeHidden"]};
        };

        _state set [1, if (_hide == 1) then {_record} else {[]}];
        _state set [2, diag_tickTime];
        _state set [4, _record select 7];
        if (!_unchanged) then {_state set [3, false]};
        _states set [_entityKey, _state];
        _context set [2, []];
        private _delay = ([_entity] call CU_fnc_policy) select 2;

        if (_hide == 1) then {
            _delay = [_record, _view, _delay] call CU_fnc_checkDelay;
            if !(_state param [3, false]) then {_delay = _delay min 0.5}
        };

        [_heap, [diag_tickTime + _delay, _entity, _entityKey]] call CU_fnc_pushDue;
        CU_var_checked = CU_var_checked + 1;
    };

    true
};

CU_fnc_workerTick = {
    private _started = diag_tickTime;

    if (_started - CU_var_budgetAt >= 0.5) then {
        CU_var_budgetMs = (0.5 max (CU_var_budgetMs * ([0.85, 1.05] select ((diag_fps min CU_var_serverFps) >= 35)))) min 8;
        CU_var_batchSize = 1 max (32 min floor (0.3 / (CU_var_rayMs max 0.001)));
        CU_var_budgetAt = _started;
    };

    private _refresh = _started >= CU_var_refresh;
    if (_refresh) then {call CU_fnc_refreshEntities};

    // Rebuild owner keys once per frame, not once per ray or cheap object.
    {private _v = CU_var_views get _x;
        if (isNull (_v select 0) || {_started - (_v select 10) > 1}) then {
            diag_log format ["CULLING|VIEW_EXPIRED|owner=%1|age=%2", _x, _started - (_v select 10)];
            CU_var_views deleteAt _x;
            CU_var_contexts deleteAt _x
        }} forEach keys CU_var_views;

    private _owners = keys CU_var_views;
    private _packets = createHashMap;

    {
        private _context = CU_var_contexts getOrDefault [_x, []];

        if (_context isEqualTo []) then {
            _context = [createHashMap, [], []];
            CU_var_contexts set [_x, _context]
        };
    } forEach _owners;

    private _idle = 0;
    private _iterations = 0;

    while {_owners isNotEqualTo [] && {_idle < count _owners} && {_iterations < 2048} &&
        {(diag_tickTime - _started) * 1000 < CU_var_budgetMs}} do {
        _iterations = _iterations + 1;
        CU_var_cursor = (CU_var_cursor + 1) mod count _owners;
        private _key = _owners select CU_var_cursor;
        if([_key, CU_var_views get _key, CU_var_contexts get _key,
            _packets] call CU_fnc_processView) then {_idle = 0} else {_idle = _idle + 1};
    };

    {
        CU_var_logCounts set ["hideSent", count (_y select 4) + (CU_var_logCounts getOrDefault ["hideSent", 0])];
        CU_var_logCounts set ["showSent", count (_y select 5) + (CU_var_logCounts getOrDefault ["showSent", 0])];
        _y remoteExecCall ["CU_fnc_result", parseNumber _x]
    } forEach _packets;

    private _work = (diag_tickTime - _started) * 1000;
    CU_var_workMs = CU_var_workMs + _work;
    CU_var_totalWorkMs = CU_var_totalWorkMs + _work;

    if (diag_tickTime - CU_var_statAt >= 1) then {
        private _dt = diag_tickTime - CU_var_statAt;
        [clientOwner,
            [CU_var_checked / _dt, CU_var_rays / _dt, CU_var_budgetMs, count CU_var_views, count CU_var_contexts,
            CU_var_reuses / _dt, CU_var_distanceChecks / _dt, CU_var_workMs / _dt, CU_var_batchSize,
            count CU_var_entities]] remoteExecCall ["CU_fnc_workerStats", 2];
        CU_var_checked = 0;
        CU_var_rays = 0;
        CU_var_reuses = 0;
        CU_var_distanceChecks = 0;
        CU_var_workMs = 0;
        CU_var_statAt = diag_tickTime;
    };
};

CU_fnc_clientTick = {
    private _camera = AGLToASL positionCameraToWorld [0, 0, 0];
    private _range = (getObjectViewDistance) select 0;
    private _focus = cameraOn;
    private _key = [player, _focus, vehicle _focus, cameraView in ["EXTERNAL", "GROUP"]];
    private _dt = (diag_tickTime - CU_var_cameraAt) max 0.001;
    private _velocity = (_camera vectorDiff CU_var_camera) vectorMultiply (1 / _dt);
    CU_var_logViewGap = CU_var_logViewGap max _dt;
    private _orbit = 0;
    private _pivot = _camera;

    if (cameraView in ["EXTERNAL", "GROUP"] && {_camera distance(getPosWorld _focus) < 50}) then {
        _pivot = eyePos _focus;
        _orbit = _camera distance _pivot;
        _velocity = velocity vehicle _focus
    };

    if (_key isNotEqualTo CU_var_cameraKey || {vectorMagnitude _velocity > 400}) then {
        CU_var_epoch = CU_var_epoch + 1;
        _velocity = [0, 0, 0];
        CU_var_cameraKey = _key
    };

    CU_var_camera = _camera;
    CU_var_cameraAt = diag_tickTime;
    CU_var_cameraRange = _range;
    CU_var_cameraVelocity = _velocity;

    if (CU_var_pendingAck isNotEqualTo [] && {CU_var_worker > 2}) then {
        private _acks = CU_var_pendingAck;
        CU_var_pendingAck = [];
        [player, _acks] remoteExecCall ["CU_fnc_submitAck", 2];
    };

    // Sent when the camera moved, its speed changed or it switched; otherwise every 0.5 s as a keep-alive.
    private _changed = _key isNotEqualTo CU_var_sentKey || {_camera distance CU_var_sentCamera > 0.2} ||
        {(_velocity vectorDistance CU_var_sentVelocity) > 0.5} || {_range != CU_var_sentRange} ||
        {diag_tickTime - CU_var_sentAt > 0.5};

    if (CU_var_worker > 2 && {_changed}) then {
        CU_var_sentKey = _key;
        CU_var_sentCamera = _camera;
        CU_var_sentVelocity = _velocity;
        CU_var_sentRange = _range;
        CU_var_sentAt = diag_tickTime;
        CU_var_sequence = CU_var_sequence + 1;
        private _ignore = vehicle _focus;
        if ((netId _ignore) in ["", "0:0"]) then {_ignore = objNull};
        [player, _camera, _velocity, _range, CU_var_sequence, serverTime, CU_var_epoch,[_orbit, _pivot],
            CU_var_transit, _ignore] remoteExecCall ["CU_fnc_submitView", 2];
    };
};

// Local switch (debug menu of the culling addon): off reveals everything and stops sending the camera, so the HC
// drops this player's context after one second instead of computing results nobody applies. On starts afresh.
CU_fnc_setEnabled = {
    params ["_enabled"];

    if (!hasInterface || {_enabled isEqualTo CU_var_enabled}) exitWith {};

    CU_var_enabled = _enabled;

    if (!_enabled) then {
        call CU_fnc_restore;
        CU_var_pendingAck = []
    } else {

        CU_var_epoch = CU_var_epoch + 1;
        CU_var_sentAt = -100
    };

    diag_log format ["CULLING|CLIENT_TOGGLE|enabled=%1", _enabled];
};

CU_fnc_clientFrame = {
    private _frameMs = 1000 * diag_deltaTime;
    private _changes = CU_var_totalRenderChanges - CU_var_frameRenderTotal;
    CU_var_frameRenderTotal = CU_var_totalRenderChanges;
    if(CU_var_worstRenderFrame isEqualTo [] ||
        {_frameMs >(CU_var_worstRenderFrame select 0)}) then {CU_var_worstRenderFrame =[_frameMs, _changes,
        isGameFocused]};

    // A restarted HC has a fresh diag_tickTime version domain. Reset once on worker identity change,
    // never periodically, so its legitimate new results cannot be rejected as older forever.
    if (CU_var_clientWorker != CU_var_worker) then {
        call CU_fnc_restore;
        CU_var_versions = createHashMap;
        CU_var_pendingAck = [];
        CU_var_clientWorker = CU_var_worker;
        CU_var_epoch = CU_var_epoch + 1;
    };

    // Off while the vanilla spectator is open: it lists only units that are not hidden, so culled units would be missing
    // from its list; on again when it closes. A switch-off by hand (debug menu) stays off.
    private _spectating = !isNull findDisplay 60492;

    if (_spectating && {CU_var_enabled}) then {
        CU_var_spectatorOff = true;
        [false] call CU_fnc_setEnabled;
    };

    if (!_spectating && {missionNamespace getVariable ["CU_var_spectatorOff", false]}) then {
        CU_var_spectatorOff = false;
        [true] call CU_fnc_setEnabled;
    };

    if ((CU_var_worker <= 2 || {!CU_var_enabled}) && {count CU_var_hidden > 0}) then {call CU_fnc_restore};

    // A camera switched onto an object we hid (spectator, vehicle change) shows it at once.
    {private _key = netId _x;
        if (!isNil {CU_var_hidden get _key}) then {
            [_x] call CU_fnc_reveal;
            CU_var_pendingAck pushBack [_x, (CU_var_hidden get _key) select 1, false];
            CU_var_hidden deleteAt _key
        }} forEach [cameraOn, vehicle cameraOn];

    if (CU_var_enabled && {!isNull player} && {diag_tickTime >= CU_var_nextView}) then {
        CU_var_nextView = diag_tickTime + 0.05;
        call CU_fnc_clientTick;
    };
};
/*
    Ground loot culling, on every client without the HC: weapon holders farther than CU_var_lootDistance from the
    camera are hidden, ground holders also stop simulating. Both commands act locally only: the server, the AI and
    other players keep the loot as it is. Simulated holders (dropped weapons, physics) stay simulated, so a falling
    one is not frozen at a stale spot here. The holder list is refreshed every 2 s, distances every 0.5 s, and only
    changes are written; holders hidden by the mission itself (not by this loop) are never touched.
*/
CU_var_lootDistance = 30;
CU_fnc_lootCullLoop = {
    private _holders = [];
    private _refresh = 0;

    while {true} do {
        if (diag_tickTime >= _refresh) then {
            _holders = (allMissionObjects "GroundWeaponHolder") + (allMissionObjects "WeaponHolderSimulated");
            _refresh = diag_tickTime + 2;
        };

        private _camera = AGLToASL positionCameraToWorld [0, 0, 0];
        private _limit = CU_var_lootDistance^2;

        {
            if (!isNull _x) then {
                private _far = (getPosWorld _x) distanceSqr _camera > _limit;
                private _ours = _x getVariable ["CU_var_lootCulled", false];

                if (_far isNotEqualTo _ours && {_ours || {!isObjectHidden _x}}) then {
                    _x hideObject _far;
                    if (!(_x isKindOf "WeaponHolderSimulated")) then {_x enableSimulation !_far};
                    _x setVariable ["CU_var_lootCulled", _far];
                };
            };
        } forEach _holders;

        uiSleep 0.5;
    };
};

CU_fnc_init = {
    if (!isNil "CU_var_started") exitWith {};

    CU_var_started = true;
    if (!isNil "CU_fnc_initDiagnostics") then {call CU_fnc_initDiagnostics};

    if(isServer) exitWith {[] spawn {while {true} do {if(CU_var_worker > 2) then {if((allMissionObjects
        "HeadlessClient_F") findIf {owner _x == CU_var_worker} < 0) then {
                        CU_var_worker = -1;
                        publicVariable "CU_var_worker"
                    } else {[diag_fps] remoteExecCall ["CU_fnc_serverLoad", CU_var_worker]}};

                sleep 2}}};
    if (!hasInterface) exitWith {[] spawn {waitUntil {
                sleep 0.2;
                !isNull player
            };

            while {true} do {
                [player, clientOwner] remoteExecCall ["CU_fnc_register", 2];
                sleep 2
            }};

        addMissionEventHandler ["EachFrame", {if (CU_var_worker == clientOwner) then {call CU_fnc_workerTick}}];
        diag_log "CULLING|ROLE|predictive visibility worker; no AI ownership"};
    CU_var_epoch = 0;
    CU_var_sequence = 0;
    CU_var_transit = 0.15;
    CU_var_camera = [0, 0, 0];
    CU_var_cameraAt = diag_tickTime;
    CU_var_cameraKey = [];
    CU_var_cameraRange = (getObjectViewDistance) select 0;
    CU_var_nextView = 0;
    CU_var_enabled = true;
    CU_var_sentKey = [];
    CU_var_sentCamera = [0, 0, 0];
    CU_var_sentVelocity = [0, 0, 0];
    CU_var_sentRange = -1;
    CU_var_sentAt = -100;
    addMissionEventHandler ["EachFrame", {call CU_fnc_clientFrame}];
    [] spawn CU_fnc_lootCullLoop;
};
call compile preprocessFileLineNumbers "ui\visibilityDiagnostics.sqf";
call CU_fnc_init;
