// Entity culling (client): stops rendering the units and vehicles this client's camera cannot see (hideObject is
// local). A per-frame worker with a time budget tests occlusion by terrain and buildings from the camera; it only
// saves rendering - hidden entities keep their simulation and their sounds (hideObject does not mute them).

// ---- tuning ----

EC_var_entityTypes = [ // what is culled (units on foot, vehicles incl. static weapons, boxes, weapon holders)
"CAManBase",
"LandVehicle",
"Air",
"Ship",
"ReammoBox_F",
"WeaponHolder",
"WeaponHolderSimulated"
];
EC_var_vegetationPaths = ["\plants", "vegetation", "\tree\", "\bush\", "\t_", "\b_"]; // parts of model paths
EC_var_peekOffset = 0.6; // metres the camera may lean / rise around its position, first person on foot
EC_var_vehiclePeekOffset = 1; // ... in a vehicle (turning out) and for a free camera (spectator, Zeus)
EC_var_orbitMargin = 0.2; // third person: share of the orbit radius the camera may leave its orbit by
EC_var_speedMargin = 0.02; // extra peek offset in metres per m/s of camera speed (fast movers)
EC_var_freeCameraDistance = 50; // metres between camera and cameraOn from which the camera counts as free
EC_var_velocitySmoothing = 0.1; // seconds the camera velocity is averaged over
EC_var_jumpDistance = 5; // metres the camera may move in one frame (at least) before it counts as a jump
EC_var_jumpFactor = 3; // ... or this many times its distance per frame at its current speed
EC_var_zoomStep = 1.25; // zooming in by this factor reveals everything
EC_var_recheckShare = 0.5; // share of a check's camera margin used up from which it is repeated early
EC_var_sampleMargin = 0.3; // metres added around an entity's outline
EC_var_unitHalfWidth = 1; // metres: half width of a unit (weapon, legs when prone)
EC_var_headHeight = 0.2; // metres from the eyes to the top of the head
EC_var_maxHits = 6; // surfaces looked at per ray; that many see-through ones in a row count as clear
EC_var_candidateInterval = 1; // seconds between two rebuilds of the candidate list
EC_var_staticRecheck = 1; // seconds a hidden entity that does not move is kept without new rays
EC_var_staticDistance = 0.1; // metres of movement that count as moving
EC_var_minRayCost = 0.000002; // seconds: bounds of the measured cost of one ray
EC_var_maxRayCost = 0.0005;
EC_var_debugInterval = 0.5; // seconds between two updates of the debug overlay
EC_var_revealWindow = 5; // seconds the overlay counts the reveals of everything over

EC_var_clientRunning = false;
EC_var_eachFrameEhId = -1;
EC_var_missionEhIds = [];
// hidden entities, oldest check first:
// [entity, hidden crew, check time, entity position at the last rays, time of the last rays, camera coverage]
// camera coverage (EC_fnc_coverageRatio): [pivot, orbit radius, margin, path ahead] of the last rays
EC_var_hidden = [];
EC_var_epoch = 0; // counts the reveals of everything; invisible-check counters of older ones are void
EC_var_shapes = createHashMap; // class -> [centre offset, half height, half width]
EC_var_occluders = createHashMap; // class (model path for objects without one) -> blocks the view
EC_var_rayCost = 0.00003; // seconds per ray, measured while running
EC_var_globalReveals = []; // times of the reveals of everything (debug overlay)
EC_var_lastRevealReason = "";
EC_var_lastRevealTime = 0;
EC_var_debugShown = false;
EC_var_debugTime = 0;

// ---- camera ----
// Everything is relative to the camera (positionCameraToWorld), so it works in every view: first / third person,
// vehicles, optics, UAVs, spectator and Zeus. The rays of a check cover a region the camera can move in without a new
// check (its coverage): around the camera in first person and for a free camera (lean / rise, EC_var_reach), the
// whole orbit around the unit in third person (turning never leaves it), and the path ahead over EC_var_lookahead
// seconds. Rotation alone changes nothing. A hidden entity whose coverage the camera leaves is checked again at once
// (EC_fnc_recheckUncovered). Only discrete changes reveal everything: another view, unit, vehicle or Zeus camera,
// zooming in, and a jump of the camera (teleport).

EC_fnc_cameraKey = {
    [cameraOn, player, cameraView in ["EXTERNAL", "GROUP"], curatorCamera]
};

// the screen width of one metre at 100 metres: grows with the zoom
EC_fnc_zoom = {
    private _center = worldToScreen positionCameraToWorld [0, 0, 100];
    private _side = worldToScreen positionCameraToWorld [1, 0, 100];

    if (_center isEqualTo [] || {_side isEqualTo []}) exitWith {EC_var_zoomRef};

    (_side select 0) - (_center select 0)
};

EC_fnc_updateCamera = {
    params ["_dt", "_lookahead"];

    private _camPos = AGLToASL positionCameraToWorld [0, 0, 0];
    private _focus = cameraOn;
    private _isMan = _focus isKindOf "CAManBase";
    private _focusPos = if (_isMan) then {eyePos _focus} else {getPosASLVisual _focus};
    private _focusDistance = _camPos vectorDistance _focusPos;
    private _isFree = _focusDistance > EC_var_freeCameraDistance;
    private _isThirdPerson = !_isFree && {cameraView in ["EXTERNAL", "GROUP"]};
    // the point the camera moves with: itself, in third person the unit / vehicle it orbits
    private _pivot = [_camPos, _focusPos] select _isThirdPerson;
    private _key = call EC_fnc_cameraKey;
    private _zoom = call EC_fnc_zoom;
    private _jumpDistance = EC_var_jumpDistance max (EC_var_jumpFactor * _dt * vectorMagnitude EC_var_pivotVelocity);
    private _reasonIndex = [
    _key isNotEqualTo EC_var_camKey,
    _zoom > EC_var_zoomRef * EC_var_zoomStep,
    (_pivot vectorDistance EC_var_camPivot) > _jumpDistance
    ] find true;

    if (_reasonIndex != -1) then {
        if (_reasonIndex == 0) then {
            EC_var_camKey = _key;
            call EC_fnc_updateProtected;
        };

        EC_var_zoomRef = _zoom;
        EC_var_camVelocity = [0, 0, 0];
        [["view", "zoom", "jump"] select _reasonIndex] call EC_fnc_revealAll;
    } else {
        private _velocity = (_camPos vectorDiff EC_var_camPos) vectorMultiply (1 / _dt);
        private _smoothing = (_dt / EC_var_velocitySmoothing) min 1;

        EC_var_camVelocity = EC_var_camVelocity vectorAdd ((_velocity vectorDiff EC_var_camVelocity) vectorMultiply _smoothing);
    };

    EC_var_zoomRef = EC_var_zoomRef min _zoom;
    EC_var_camPos = _camPos;
    EC_var_camPivot = _pivot;
    // in third person the camera's own speed is mostly its swing around the unit: the unit's speed counts
    EC_var_pivotVelocity = if (_isThirdPerson) then {(velocity _focus) vectorMultiply accTime} else {EC_var_camVelocity};

    private _speed = vectorMagnitude EC_var_pivotVelocity;

    EC_var_reach = ([EC_var_vehiclePeekOffset, EC_var_peekOffset] select (_isMan && {!_isFree})) + EC_var_speedMargin * _speed;
    EC_var_camOrbit = [0, _focusDistance] select _isThirdPerson;
    EC_var_camMargin = EC_var_reach + EC_var_orbitMargin * EC_var_camOrbit;
    EC_var_minDistanceNow = EC_var_minDistance + _lookahead * _speed;
    EC_var_viewDistance = getObjectViewDistance select 0;

    // camera points shared by all checks of this frame (EC_fnc_isVisible adds the ones that depend on the entity)
    EC_var_camRaised = _pivot vectorAdd [0, 0, [EC_var_reach, EC_var_camOrbit / 2] select _isThirdPerson];
    EC_var_camAhead = [];
    EC_var_camAheadPath = [0, 0, 0];

    private _ahead = EC_var_pivotVelocity vectorMultiply _lookahead;
    private _aheadDistance = vectorMagnitude _ahead;

    if (_aheadDistance > EC_var_reach) then {
        EC_var_camAheadPath = _ahead;
        EC_var_camAhead pushBack (EC_var_camRaised vectorAdd _ahead);

        // fast movers: also halfway, so a gap passed on the way is not missed
        if (_aheadDistance > 4 * EC_var_reach) then {
            EC_var_camAhead pushBack (EC_var_camRaised vectorAdd (_ahead vectorMultiply 0.5));
        };
    };
};

// how far the camera is out of a coverage [pivot, orbit, margin, path ahead]: 0 on the orbit / path, 1 at its edge
EC_fnc_coverageRatio = {
    params ["_pivot", "_orbit", "_margin", "_ahead"];

    private _toCamera = EC_var_camPos vectorDiff _pivot;
    private _aheadSqr = _ahead vectorDotProduct _ahead;
    private _along = 0;

    if (_aheadSqr > 0) then {
        _along = (((_toCamera vectorDotProduct _ahead) / _aheadSqr) max 0) min 1;
    };

    (((_toCamera vectorDistance (_ahead vectorMultiply _along)) - _orbit) max 0) / _margin
};

// ---- visibility ----
// Rays from the camera points to points around an entity's outline (a billboard facing the camera, widened by
// EC_var_sampleMargin; a moving entity also where it will be). The entity is visible when any ray is clear.
// A ray is blocked by the terrain (terrainIntersectASL, cheap, tested first) or by the view geometry of a static
// object: buildings, walls, rocks. Vegetation never blocks - leaves and bushes are see-through and their view
// geometry is a coarse blob, a trunk is too thin to matter - so forests hide nothing. Units, vehicles and props never
// block either: they move, and a hidden one would have to be checked again whenever its occluder moves.

EC_fnc_isOccluder = {
    params ["_parent", "_object"];

    if (!isNull _parent) then {
        _object = _parent;
    };

    // hidden by the mission, or attached (moves with something, e.g. props on the own vehicle)
    if (isNull _object || {isObjectHidden _object} || {!isNull attachedTo _object}) exitWith {false};

    private _type = typeOf _object;
    private _key = if (_type == "") then {(getModelInfo _object) select 1} else {_type};
    private _isOccluder = EC_var_occluders get _key;

    if (isNil "_isOccluder") then {
        private _model = toLowerANSI ((getModelInfo _object) select 1);

        // terrain objects without a class (rocks, walls, ...) and static classes, except ammo boxes / weapon holders
        _isOccluder = (EC_var_vegetationPaths findIf {(_model find _x) != -1}) == -1 && {
            _type == "" || {_object isKindOf "Static" && {!(_object isKindOf "ReammoBox")}}
        };
        EC_var_occluders set [_key, _isOccluder];
    };

    _isOccluder
};

EC_fnc_isRayClear = {
    params ["_from", "_to", "_entity"];

    EC_var_rays = EC_var_rays + 1;

    if (terrainIntersectASL [_from, _to]) exitWith {false};

    // lineIntersectsSurfaces is limited to 5 km: farther rays only test the terrain
    if ((_from vectorDistance _to) > 5000) exitWith {true};

    private _hits = lineIntersectsSurfaces [_from, _to, _entity, cameraOn, true, EC_var_maxHits, "VIEW", "NONE", true];

    (_hits findIf {[_x select 3, _x select 2] call EC_fnc_isOccluder}) == -1
};

// [centre offset, half height, half width] of a class, from its bounding box
EC_fnc_shape = {
    params ["_entity"];

    private _type = typeOf _entity;
    private _shape = EC_var_shapes get _type;

    if (isNil "_shape") then {
        (boundingBoxReal _entity) params ["_min", "_max"];

        private _halfSize = (_max vectorDiff _min) vectorMultiply 0.5;

        _shape = [
        (_min vectorAdd _max) vectorMultiply 0.5,
        _halfSize select 2,
        vectorMagnitude [_halfSize select 0, _halfSize select 1, 0]
        ];
        EC_var_shapes set [_type, _shape];
    };

    _shape
};

// [centre (ASL), half height, half width]; a unit's outline follows its stance, from the feet to above the eyes
EC_fnc_outline = {
    params ["_entity"];

    if (_entity isKindOf "CAManBase") exitWith {
        private _feet = getPosASLVisual _entity;
        private _aim = aimPos _entity;
        private _halfHeight = ((((eyePos _entity) select 2) + EC_var_headHeight - (_feet select 2)) / 2) max 0.3;

        [[_aim select 0, _aim select 1, (_feet select 2) + _halfHeight], _halfHeight, EC_var_unitHalfWidth]
    };

    ([_entity] call EC_fnc_shape) params ["_centerOffset", "_halfHeight", "_halfWidth"];

    [_entity modelToWorldVisualWorld _centerOffset, _halfHeight, _halfWidth]
};

EC_fnc_isVisible = {
    params ["_entity", "_lookahead"];

    ([_entity] call EC_fnc_outline) params ["_center", "_halfHeight", "_halfWidth"];

    private _direction = vectorNormalized (_center vectorDiff EC_var_camPos);
    private _right = vectorNormalized (_direction vectorCrossProduct [0, 0, 1]);

    if (_right isEqualTo [0, 0, 0]) then {
        _right = [1, 0, 0];
    };

    private _upward = _right vectorCrossProduct _direction;
    // seen from above or below, the outline's height includes part of its depth
    private _sinElevation = abs (_direction select 2);
    private _height = _halfHeight * sqrt (1 - _sinElevation ^ 2) + _halfWidth * _sinElevation + EC_var_sampleMargin;
    private _sideOffset = _right vectorMultiply (_halfWidth + EC_var_sampleMargin);
    private _top = _center vectorAdd (_upward vectorMultiply _height);
    private _samples = [
    _top,
    _center,
    _top vectorAdd _sideOffset,
    _top vectorDiff _sideOffset,
    _center vectorAdd _sideOffset,
    _center vectorDiff _sideOffset,
    _center vectorDiff (_upward vectorMultiply (_height * 0.8))
    ];
    private _shift = (velocity _entity) vectorMultiply (accTime * _lookahead);

    if (vectorMagnitude _shift > 1) then {
        _samples append [_top vectorAdd _shift, _center vectorAdd _shift];
    };

    // the camera now, the edge of its coverage (peeking over / around an edge; in third person beside the unit and
    // between it and the entity, where the orbit sees most) and where it is heading
    private _cameras = [EC_var_camPos];

    if (EC_var_camOrbit > 0) then {
        private _side = _right vectorMultiply EC_var_camOrbit;
        private _towards = (vectorNormalized [_direction select 0, _direction select 1, 0]) vectorMultiply EC_var_camOrbit;

        _cameras append [
        EC_var_camRaised vectorAdd _side,
        EC_var_camRaised vectorDiff _side,
        EC_var_camRaised vectorAdd _towards
        ];
    } else {
        private _side = _right vectorMultiply EC_var_reach;

        _cameras append [EC_var_camRaised vectorAdd _side, EC_var_camRaised vectorDiff _side];
    };

    _cameras append EC_var_camAhead;

    // the ray that saw the entity last time first: a visible entity usually costs one ray
    (_entity getVariable ["EC_var_seenBy", [0, 0]]) params ["_seenCamera", "_seenSample"];

    private _seenFrom = _cameras param [_seenCamera, EC_var_camPos];
    private _seenAt = _samples param [_seenSample, _center];

    if ([_seenFrom, _seenAt, _entity] call EC_fnc_isRayClear) exitWith {true};

    private _visible = false;

    {
        private _camera = _x;
        private _cameraIndex = _forEachIndex;
        private _sampleIndex = _samples findIf {[_camera, _x, _entity] call EC_fnc_isRayClear};

        if (_sampleIndex != -1) exitWith {
            _visible = true;
            _entity setVariable ["EC_var_seenBy", [_cameraIndex, _sampleIndex]];
        };
    } forEach _cameras;

    _visible
};

// ---- hiding ----
// A vehicle is hidden together with its crew (hideObject leaves the crew visible otherwise). Every object hidden here
// carries the local flag EC_var_culled, so other mods (mapmarker, tdicons) can tell culling apart from a real
// hideObject; objects hidden by anyone else are left alone.
// hideObject also takes the entity's collision and hit detection away on this client: the own vehicle drives through
// it, shots simulated here (own, local AI) pass through it. That is why only entities the camera cannot see now nor
// soon are hidden (prediction margins), never within EC_var_minDistance (plus a speed margin) and never what local AI
// attacks. Local vehicles and props are never hidden: a hidden vehicle simulated here stops moving.

// the player's own unit, vehicle and what it hangs on, and what AI simulated on this machine attacks
EC_fnc_updateProtected = {
    private _vehicle = vehicle player;
    private _protected = [
    _vehicle,
    cameraOn,
    vehicle cameraOn,
    attachedTo _vehicle,
    isVehicleCargo _vehicle,
    getSlingLoad _vehicle,
    getConnectedUAV player
    ];

    {
        _protected pushBack vehicle getAttackTarget _x;
        _protected pushBack vehicle assignedTarget _x;
    } forEach (allUnits select {local _x && {!isPlayer _x}});

    EC_var_protected = _protected select {!isNull _x};
};

// may this root entity (not crew) be hidden now?
EC_fnc_canHide = {
    params ["_entity"];

    private _distance = (getPosASLVisual _entity) vectorDistance EC_var_camPos;

    alive _entity &&
    {_distance > EC_var_minDistanceNow} &&
    {_distance < EC_var_viewDistance} &&
    {(_entity distance vehicle player) > EC_var_minDistanceNow} &&
    {isNull objectParent _entity} &&
    {isNull attachedTo _entity} &&
    {isNull isVehicleCargo _entity} &&
    {!(_entity in EC_var_protected)} &&
    {!local _entity || {_entity isKindOf "CAManBase"}}
};

EC_fnc_setCulled = {
    params ["_objects", "_culled"];

    {
        _x hideObject _culled;

        if (_culled) then {
            _x setVariable ["EC_var_culled", true];
        } else {
            _x setVariable ["EC_var_culled", nil];
        };
    } forEach _objects;
};

EC_fnc_crewToHide = {
    params ["_entity"];

    if (_entity isKindOf "CAManBase") exitWith {[]};

    (crew _entity) select {!isObjectHidden _x || {_x getVariable ["EC_var_culled", false]}}
};

// a record for an entity that rays found invisible now, with the coverage of this frame's camera
EC_fnc_newRecord = {
    params ["_entity", "_crew", "_now"];

    [_entity, _crew, _now, getPosASLVisual _entity, _now, EC_var_camPivot, EC_var_camOrbit, EC_var_camMargin, EC_var_camAheadPath]
};

// adds a record to the queue; the camera may move EC_var_scanMargin metres from EC_var_scanPos before any record
// needs an early check
EC_fnc_queueRecord = {
    params ["_record"];

    EC_var_hidden pushBack _record;

    private _margin = (EC_var_recheckShare - ((_record select [5, 4]) call EC_fnc_coverageRatio)) * (_record select 7);

    EC_var_scanMargin = EC_var_scanMargin min (_margin - (EC_var_camPos vectorDistance EC_var_scanPos));
};

EC_fnc_hide = {
    params ["_entity", "_now"];

    private _crew = [_entity] call EC_fnc_crewToHide;

    [[_entity] + _crew, true] call EC_fnc_setCulled;
    _entity setVariable ["EC_var_invisibleChecks", nil];
    [[_entity, _crew, _now] call EC_fnc_newRecord] call EC_fnc_queueRecord;
};

EC_fnc_revealRecord = {
    params ["_record"];
    _record params ["_entity", "_crew"];

    [([_entity] + _crew) select {!isNull _x}, false] call EC_fnc_setCulled;
};

// _reason: what made the camera's view change (debug overlay), "" when the culling stops
EC_fnc_revealAll = {
    params [["_reason", ""]];

    {
        [_x] call EC_fnc_revealRecord;
    } forEach EC_var_hidden;

    EC_var_hidden = [];
    EC_var_epoch = EC_var_epoch + 1;
    EC_var_scanPos = EC_var_camPos;
    EC_var_scanMargin = 1e6;

    if (_reason != "") then {
        EC_var_globalReveals pushBack diag_tickTime;
        EC_var_lastRevealReason = _reason;
        EC_var_lastRevealTime = diag_tickTime;
    };
};

// consecutive invisible checks of a visible entity (hysteresis), reset by a visible check
EC_fnc_countInvisible = {
    params ["_entity", "_visible"];

    if (_visible) exitWith {
        _entity setVariable ["EC_var_invisibleChecks", nil];
        0
    };

    (_entity getVariable ["EC_var_invisibleChecks", [-1, 0]]) params ["_epoch", "_count"];

    _count = [1, _count + 1] select (_epoch == EC_var_epoch);
    _entity setVariable ["EC_var_invisibleChecks", [EC_var_epoch, _count]];
    _count
};

// a visible candidate: hidden after EC_var_hideAfterChecks invisible checks in a row
EC_fnc_checkCandidate = {
    params ["_entity", "_now", "_lookahead"];

    // hidden here: rechecked from EC_var_hidden; hidden by someone else: left alone
    if (isNull _entity || {isObjectHidden _entity}) exitWith {};

    if !([_entity] call EC_fnc_canHide) exitWith {
        _entity setVariable ["EC_var_invisibleChecks", nil];
    };

    private _visible = [_entity, _lookahead] call EC_fnc_isVisible;

    if (([_entity, _visible] call EC_fnc_countInvisible) >= EC_var_hideAfterChecks) then {
        [_entity, _now] call EC_fnc_hide;
    };
};

// A hidden entity: revealed as soon as a check sees it, else [its record for the next check period] with its current
// crew. _moved: the camera is leaving the coverage of the last rays, new rays are needed.
EC_fnc_recheckHidden = {
    params ["_record", "_now", "_lookahead", ["_moved", false]];
    _record params ["_entity", "_crew", "", "_rayPosition", "_rayTime"];

    if (isNull _entity || {!([_entity] call EC_fnc_canHide)}) exitWith {
        [_record] call EC_fnc_revealRecord;
        []
    };

    // neither the entity nor the camera (out of the coverage) moved since the last rays: their result holds; they
    // are repeated after a while anyway (doors, destruction)
    private _position = getPosASLVisual _entity;
    private _unchanged = !_moved &&
    {_now - _rayTime < EC_var_staticRecheck} &&
    {(_position vectorDistance _rayPosition) < EC_var_staticDistance};

    if (!_unchanged) then {
        EC_var_statRechecks = EC_var_statRechecks + 1;
    };

    if (!_unchanged && {[_entity, _lookahead] call EC_fnc_isVisible}) exitWith {
        [_record] call EC_fnc_revealRecord;
        EC_var_statSeen = EC_var_statSeen + 1;
        []
    };

    // units that got in are hidden with the vehicle, units that got out are revealed
    private _newCrew = [_entity] call EC_fnc_crewToHide;

    [(_crew - _newCrew) select {!isNull _x}, false] call EC_fnc_setCulled;
    [_newCrew, true] call EC_fnc_setCulled;

    if (_unchanged) exitWith {
        [[_entity, _newCrew, _now] + (_record select [3, 6])]
    };

    [[_entity, _newCrew, _now] call EC_fnc_newRecord]
};

// Hidden entities whose coverage the camera left are checked again at once; what the budget does not allow is
// revealed. Those near the edge of their coverage are checked while the budget lasts. The queue is only scanned when
// the camera moved farther than the smallest remaining margin.
EC_fnc_recheckUncovered = {
    params ["_now", "_lookahead"];

    if ((EC_var_camPos vectorDistance EC_var_scanPos) < EC_var_scanMargin) exitWith {};

    private _ratios = EC_var_hidden apply {(_x select [5, 4]) call EC_fnc_coverageRatio};
    private _handled = [];
    private _rechecked = [];

    {
        if ((_ratios select _forEachIndex) > 1) then {
            _handled pushBack _forEachIndex;
            EC_var_statMoved = EC_var_statMoved + 1;

            if (EC_var_rays < EC_var_rayCredit) then {
                _rechecked append ([_x, _now, _lookahead, true] call EC_fnc_recheckHidden);
            } else {
                [_x] call EC_fnc_revealRecord;
                EC_var_statUnchecked = EC_var_statUnchecked + 1;
            };
        };
    } forEach EC_var_hidden;

    {
        if (EC_var_rays >= EC_var_rayCredit) exitWith {};

        if ((_ratios select _forEachIndex) > EC_var_recheckShare && {!(_forEachIndex in _handled)}) then {
            _handled pushBack _forEachIndex;
            EC_var_statMoved = EC_var_statMoved + 1;
            _rechecked append ([_x, _now, _lookahead, true] call EC_fnc_recheckHidden);
        };
    } forEach EC_var_hidden;

    private _kept = [];
    private _margin = 1e6;

    {
        if !(_forEachIndex in _handled) then {
            _kept pushBack _x;
            _margin = _margin min ((EC_var_recheckShare - (_ratios select _forEachIndex)) * (_x select 7));
        };
    } forEach EC_var_hidden;

    EC_var_hidden = _kept;
    EC_var_scanPos = EC_var_camPos;
    EC_var_scanMargin = _margin;

    {
        [_x] call EC_fnc_queueRecord;
    } forEach _rechecked;
};

// a hidden entity or crew member that dies is revealed at once (ragdoll / wreck physics need its collision)
EC_fnc_entityKilled = {
    params ["_entity"];

    if !(_entity getVariable ["EC_var_culled", false]) exitWith {};

    private _index = EC_var_hidden findIf {(_x select 0) isEqualTo _entity || {_entity in (_x select 1)}};

    if (_index == -1) exitWith {
        [[_entity], false] call EC_fnc_setCulled;
    };

    [EC_var_hidden deleteAt _index] call EC_fnc_revealRecord;
};

// ---- worker ----
// One unscheduled EachFrame worker. The candidates (living units on foot, vehicles, static weapons, ammo boxes and
// weapon holders within the object view distance - entities beyond it are not rendered anyway) are checked
// round-robin, nearest / largest first, each at most every EC_var_checkInterval seconds. Hidden entities come first:
// those whose coverage the camera left, then each after half of EC_var_lookahead (the prediction of moving entities);
// one not checked for a full EC_var_lookahead is revealed unchecked.
// diag_tickTime is too coarse to stop after a fraction of a millisecond, so the budget is counted in rays at the
// cost per ray measured over the last second.

EC_fnc_buildCandidates = {
    private _range = EC_var_viewDistance;
    private _entities = (entities [EC_var_entityTypes, [], false, true]) inAreaArray [EC_var_camPos, _range, _range, 0, false];
    private _order = [];

    {
        ([_x] call EC_fnc_shape) params ["", "_halfHeight", "_halfWidth"];

        private _distance = (getPosASLVisual _x) vectorDistance EC_var_camPos;

        _order pushBack [_distance / ((_halfHeight max _halfWidth) max 0.5), _forEachIndex];
    } forEach _entities;

    _order sort true;
    EC_var_candidates = _order apply {_entities select (_x select 1)};
    EC_var_candidatesTime = diag_tickTime;

    call EC_fnc_updateProtected;
};

EC_fnc_work = {
    params ["_now"];

    private _lookahead = EC_var_lookahead max 0.1;

    [diag_deltaTime max 0.001, _lookahead] call EC_fnc_updateCamera;

    private _allowance = EC_var_frameBudget / EC_var_rayCost;

    EC_var_rayCredit = (EC_var_rayCredit + _allowance) min (2 * _allowance);

    while {EC_var_hidden isNotEqualTo [] && {((EC_var_hidden select 0) select 2) + _lookahead < _now}} do {
        [EC_var_hidden deleteAt 0] call EC_fnc_revealRecord;
        EC_var_statUnchecked = EC_var_statUnchecked + 1;
    };

    [_now, _lookahead] call EC_fnc_recheckUncovered;

    while {
        EC_var_rays < EC_var_rayCredit &&
        {EC_var_hidden isNotEqualTo []} &&
        {((EC_var_hidden select 0) select 2) + _lookahead / 2 <= _now}
    } do {
        {
            [_x] call EC_fnc_queueRecord;
        } forEach ([EC_var_hidden deleteAt 0, _now, _lookahead] call EC_fnc_recheckHidden);
    };

    if (EC_var_candidateIndex >= count EC_var_candidates && {_now - EC_var_sweepTime >= EC_var_checkInterval}) then {
        if (_now - EC_var_candidatesTime >= EC_var_candidateInterval) then {
            call EC_fnc_buildCandidates;
        };

        EC_var_candidateIndex = 0;
        EC_var_sweepTime = _now;
    };

    while {EC_var_rays < EC_var_rayCredit && {EC_var_candidateIndex < count EC_var_candidates}} do {
        private _entity = EC_var_candidates select EC_var_candidateIndex;

        EC_var_candidateIndex = EC_var_candidateIndex + 1;
        [_entity, _now, _lookahead] call EC_fnc_checkCandidate;
    };

    EC_var_rayCredit = EC_var_rayCredit - EC_var_rays;
};

EC_fnc_eachFrame = {
    private _now = diag_tickTime;

    EC_var_rays = 0;

    if (EC_var_enabled) then {
        [_now] call EC_fnc_work;
    } else {
        if (EC_var_hidden isNotEqualTo []) then {
            ["disabled"] call EC_fnc_revealAll;
        };
    };

    [_now, diag_tickTime - _now] call EC_fnc_updateStats;
};

// ---- statistics / debug overlay ----
// The overlay (EC_var_debug) shows what is hidden, the reveals of everything with their last reason, the rechecks and
// reveals of single entities per second, the worker's time per frame and the frame rate. Compare the frame rate with
// EC_var_enabled true and false at the same spot to measure the gain.

EC_fnc_resetStats = {
    params ["_now"];

    EC_var_statStart = _now;
    EC_var_statFrames = 0;
    EC_var_statTime = 0;
    EC_var_statRays = 0;
    EC_var_statRechecks = 0;
    EC_var_statMoved = 0;
    EC_var_statSeen = 0;
    EC_var_statUnchecked = 0;
};

EC_fnc_updateStats = {
    params ["_now", "_elapsed"];

    EC_var_statFrames = EC_var_statFrames + 1;
    EC_var_statTime = EC_var_statTime + _elapsed;
    EC_var_statRays = EC_var_statRays + EC_var_rays;

    private _window = _now - EC_var_statStart;

    if (_window >= 1) then {
        if (EC_var_statRays >= 20) then {
            private _measured = (EC_var_rayCost + EC_var_statTime / EC_var_statRays) / 2;

            EC_var_rayCost = (_measured max EC_var_minRayCost) min EC_var_maxRayCost;
        };

        EC_var_rates = [
        1000 * EC_var_statTime / EC_var_statFrames,
        EC_var_statRays / _window,
        EC_var_statRechecks / _window,
        EC_var_statMoved / _window,
        EC_var_statSeen / _window,
        EC_var_statUnchecked / _window
        ];
        [_now] call EC_fnc_resetStats;
    };

    if (!EC_var_debug) exitWith {
        if (EC_var_debugShown) then {
            EC_var_debugShown = false;
            hintSilent "";
        };
    };

    if (_now < EC_var_debugTime) exitWith {};

    EC_var_debugTime = _now + EC_var_debugInterval;
    EC_var_debugShown = true;
    EC_var_globalReveals = EC_var_globalReveals select {_x > _now - EC_var_revealWindow};
    EC_var_rates params ["_workerMs", "_rays", "_rechecks", "_moved", "_seen", "_unchecked"];

    private _crew = 0;

    {
        _crew = _crew + count (_x select 1);
    } forEach EC_var_hidden;

    private _lastReveal = if (EC_var_lastRevealReason == "") then {"-"} else {
        format ["%1, %2 s ago", EC_var_lastRevealReason, (_now - EC_var_lastRevealTime) toFixed 1]
    };

    hintSilent format [
    "Entity culling%1\nhidden: %2 (+%3 crew), candidates: %4\nall revealed (%5 s): %6, last: %7\nper s: %8 rechecks (%9 camera moved)\nper s shown: %10 seen, %11 unchecked\nworker: %12 ms/frame (budget %13)\nrays: %14/s at %15 ms\nfps: %16",
    ["", " (disabled)"] select !EC_var_enabled,
    count EC_var_hidden,
    _crew,
    count EC_var_candidates,
    EC_var_revealWindow,
    count EC_var_globalReveals,
    _lastReveal,
    round _rechecks,
    round _moved,
    round _seen,
    round _unchecked,
    _workerMs toFixed 2,
    (EC_var_frameBudget * 1000) toFixed 2,
    round _rays,
    (EC_var_rayCost * 1000) toFixed 3,
    round diag_fps
    ];
};

// ---- start / stop ----

EC_fnc_resetState = {
    EC_var_camPos = AGLToASL positionCameraToWorld [0, 0, 0];
    call EC_fnc_revealAll;

    EC_var_candidates = [];
    EC_var_candidateIndex = 0;
    EC_var_candidatesTime = -1e6;
    EC_var_sweepTime = -1e6;
    EC_var_protected = [];
    EC_var_camPivot = EC_var_camPos;
    EC_var_camVelocity = [0, 0, 0];
    EC_var_pivotVelocity = [0, 0, 0];
    EC_var_camKey = call EC_fnc_cameraKey;
    EC_var_zoomRef = 0;
    EC_var_zoomRef = call EC_fnc_zoom;
    EC_var_reach = EC_var_peekOffset;
    EC_var_camOrbit = 0;
    EC_var_camMargin = EC_var_reach;
    EC_var_camRaised = EC_var_camPos;
    EC_var_camAhead = [];
    EC_var_camAheadPath = [0, 0, 0];
    EC_var_minDistanceNow = EC_var_minDistance;
    EC_var_viewDistance = 0;
    EC_var_rayCredit = 0;
    EC_var_rays = 0;
    EC_var_rates = [0, 0, 0, 0, 0, 0];
    [diag_tickTime] call EC_fnc_resetStats;
};

EC_fnc_startEntityCullingClient = {
    if (EC_var_clientRunning) exitWith {};

    EC_var_clientRunning = true;
    call EC_fnc_resetState;

    EC_var_eachFrameEhId = addMissionEventHandler ["EachFrame", {call EC_fnc_eachFrame}];
    EC_var_missionEhIds = [
    ["EntityKilled", addMissionEventHandler ["EntityKilled", {_this call EC_fnc_entityKilled}]],
    // a savegame may come from another game session (diag_tickTime): the check times are void
    ["Loaded", addMissionEventHandler ["Loaded", {call EC_fnc_resetState}]],
    ["Ended", addMissionEventHandler ["Ended", {call EC_fnc_stopEntityCullingClient}]],
    ["MPEnded", addMissionEventHandler ["MPEnded", {call EC_fnc_stopEntityCullingClient}]]
    ];
};

// reveals everything this client hid (module deactivated, mission end)
EC_fnc_stopEntityCullingClient = {
    if (!EC_var_clientRunning) exitWith {};

    EC_var_clientRunning = false;
    removeMissionEventHandler ["EachFrame", EC_var_eachFrameEhId];
    EC_var_eachFrameEhId = -1;

    {
        removeMissionEventHandler _x;
    } forEach EC_var_missionEhIds;

    EC_var_missionEhIds = [];
    call EC_fnc_revealAll;

    if (EC_var_debugShown) then {
        EC_var_debugShown = false;
        hintSilent "";
    };
};

EC_var_clientInitDone = true;
