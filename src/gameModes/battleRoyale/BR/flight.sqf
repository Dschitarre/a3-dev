// Battle Royale flight (server and client): an aircraft crosses the play area on a mostly straight, slightly curved
// route past interesting places (drop spots), the combatants ride along parked and jump when they want (players:
// space, AI teams: at their drop spot - a town, village or other place with loot, spread over the area -, AI team mates
// with their player); everyone still aboard jumps before the route leaves the play area. Free fall, then the parachute
// opens by itself at a safe height (AI glides to its drop spot).

// route positions are metres along the route (BR_var_flightRoute, BR_var_flightRouteLengths) from its start

// the aircraft: the first type of the world pool's list the loaded game has (BR_worldPool "aircraft" of
// BR\loot\lootPool<mapGroup>.hpp; 2035: V-44X Blackfish, Y-32 Xi'an, else a vanilla plane), else a vanilla helicopter.
// It flies the route by script (BR_fnc_flightStep) at a speed fitting the area: BR_var_flightInsideTime over a big area
// (whole Altis about 2.5 min), within BR_var_flightSpeedRange - smaller areas fly slower
BR_var_aircraftTypes = getArray (missionConfigFile >> "BR_worldPool" >> "aircraft");
BR_var_aircraftFallbackType = "I_Heli_Transport_02_F";
BR_var_flightInsideTime = 150; // s from entering the play area to the forced jump ...
BR_var_flightSpeedRange = [60, 200]; // ... at a speed (m/s) in this range
BR_var_flightLookAhead = 1.5; // s: the route points this far behind and ahead give position and heading
BR_var_flightAltitudeStep = 100; // m: steps along the route for its highest ground (the flight stays level)
BR_var_jumpMaxSpeed = 40; // m/s: a jumper keeps at most this much of the aircraft's speed
BR_var_jumpTailGap = 10; // m behind the aircraft's tail a jumper starts
BR_var_flightLeadIn = 1200; // the route starts and ends this far outside of the play area ...
BR_var_flightWorldMargin = 100; // ... but this far inside of the world's edges at most (BR_fnc_clipToWorld)
BR_var_flightLineOffset = 0.8; // the straight line passes the play area's center at most this share of its
// radius away, any direction and offset equally likely (no part favoured); no zone steers it
BR_var_flightLineTries = 64; // bounded search; choose randomly among land-dominated routes
BR_var_flightMinLandShare = 0.75;
BR_var_flightRouteProbeStep = 250; // cheap first pass; final route is checked at 100 m
BR_var_flightViaCorridor = 0.15; // via points: drop spots this close (share of the radius) to the straight line ...
BR_var_flightViaMinCorridor = 500; // ... but at least this close (m) ...
BR_var_flightViaMax = 4; // ... at most this many, one per place (a big town has many spots: it would be
// picked most of the time) ...
BR_var_flightViaSpacing = 0.35; // ... at least this far apart along it (share of the radius)
BR_var_flightWaypointRadius = 300;
BR_var_routeSampleStep = 50; // m: steps when the route is searched for the play area's edge
BR_var_forcedJumpMargin = 300; // everyone still aboard jumps this far before the route leaves the play area
BR_var_aiJumpMargin = 200; // AI teams jump at least this far inside the play area
BR_var_aiJumpTries = 10; // random jump points tried for one above land (no drop spot in reach)
BR_var_aiDropLocationTypes = ["NameCityCapital", "NameCity", "NameVillage", "NameLocal", "Airport"]; // spot names
BR_var_aiDropBuildingRadius = 150; // houses with loot spots this close to a drop spot count for it ...
BR_var_aiDropMinBuildings = 6; // ... a drop spot needs at least this many ...
BR_var_aiDropLeftOut = ["castle_wall", "castle_stairs", "castle_gate"]; // class parts that count as no building here
BR_var_aiDropBuildingsPerAi = 8; // ... and takes one AI per this many
BR_var_aiDropSpacing = 350; // drop spots are at least this far apart (a big town has several)
BR_var_aiDropEdgeMargin = 150; // drop spots lie at least this far inside the play area
BR_var_aiDropReachShare = 0.85; // an AI's drop spot lies at most this share of its gliding reach from the jump
// point (reach: the flight height glided at BR_var_aiGlideSpeed / BR_var_aiSinkRate)
BR_var_aiDropLandSpread = 25; // the landing spot lies this close to a house of the drop spot, under open sky
BR_var_aiJumpSpacing = 80; // m along the route at least between the jumps of two AI teams: leaving at one point they
// collided in free fall and when their canopies opened; at 40 m four canopies still collided right after opening ...
BR_var_aiJumpSpread = 400; // ... at most this far before or after its jump point (gliding reach keeps some slack)
BR_var_aiDropMateSpread = 6; // team mates land this far apart
// An AI flies its parachute like a player (BR_fnc_aiGlide, every frame): no steering in free fall, the canopy turns at a
// player's rate and flies forward at a player's speed, the engine does the sinking.
BR_var_aiOpenHeight = 160; // an AI's parachute opens at this height, or earlier to glide to its drop spot:
BR_var_aiSinkRate = 3.3; // ... m/s the canopy sinks by itself (measured; used for planning only) ...
BR_var_aiGlideSpeed = 12; // ... and m/s forward, as a player holding forward
BR_var_aiTurnRate = 30; // degrees per second the canopy turns at most ...
BR_var_aiTurnDeadband = 3; // ... and not at all while the drop spot lies within this many degrees of its heading
BR_var_aiBrakeShare = 0.5; // a canopy that would overshoot slows down to this share of the speed at most
BR_var_aiGlideLandHeight = 6; // m: below this the parachute lands by itself
BR_var_aiSteerInterval = 0.5;
BR_var_aiChuteSeparation = 50; // m: an AI canopy steers away from other canopies this close (BR_fnc_aiGlideFrame) ...
BR_var_aiChuteAvoidWeight = 3; // ... the closer, the more: up to this many times the pull to its drop spot ...
BR_var_aiChuteAvoidInterval = 0.25; // ... neighbours looked up this often (s)
BR_var_aiFlareHeight = 25; // m: below this an AI canopy flies at most ...
BR_var_aiFlareSpeed = 3; // ... this fast (m/s)
BR_var_flightTimeoutShare = 1.5; // forced jump at the latest after this share of the planned flight time
BR_var_jumpCheckInterval = 0.25;
BR_var_forcedJumpResend = 3; // seconds between two forced jump requests to the same player
BR_var_aircraftCleanupDelay = 60;
BR_var_rideAlongOffset = [0, 0, -6]; // with all passenger seats taken the hidden player rides along attached here (BR_fnc_boardAircraft)
BR_var_jumpVelocityShare = 0.4; // share of the aircraft's velocity a jumper keeps
BR_var_freefallOpenHeight = 150; // a player's parachute opens by itself below this height (earlier: space)
BR_var_freefallMinHeight = 20; // a unit higher than this above the ground counts as falling
BR_var_freefallAnimation = "AfalPpneMstpSnonWnonDnon";
BR_var_parachuteType = "Steerable_Parachute_F";
BR_var_parachuteCheckDelay = 1; // s: a unit still in free fall this long after opening gets a parachute directly

// ---- aircraft and route (server) ----

// the first aircraft type the loaded game has
BR_fnc_aircraftType = {
    BR_var_aircraftTypes param [BR_var_aircraftTypes findIf {isClass (configFile >> "CfgVehicles" >> _x)}, BR_var_aircraftFallbackType]
};

/*
    Random land-dominated crossings of the unchanged first zone. Trim empty sea before/after the usable land span;
    retain a short lead-in/out and optional nearby drop spots only when their bends preserve the land quality.
    The independently sampled final-zone endpoint is never moved to accommodate the flight.
*/
BR_fnc_flightRouteQuality = {
    params ["_route", ["_sampleStep", 100]];

    private _along = 0;
    private _landLength = 0;
    private _first = -1;
    private _last = -1;
    private _water = 0;
    private _maxWater = 0;

    for "_i" from 1 to count _route - 1 do {
        private _from = _route select (_i - 1);
        private _delta = (_route select _i) vectorDiff _from;
        private _length = vectorMagnitude _delta;
        private _steps = ceil (_length / _sampleStep) max 1;
        private _step = _length / _steps;

        for "_j" from 0 to _steps - 1 do {
            private _p = _from vectorAdd (_delta vectorMultiply ((_j + 0.5) / _steps));

            if (_p distance2D BR_var_playAreaCenter <= BR_var_playAreaRadius && {[_p] call BR_fnc_inWorld} && {!surfaceIsWater _p}) then {
                if (_first < 0) then {_first = _along + _step * 0.5};
                _last = _along + _step * 0.5;
                _landLength = _landLength + _step;
                _maxWater = _maxWater max _water;
                _water = 0;
            } else {if (_first >= 0) then {_water = _water + _step}};

            _along = _along + _step;
        };
    };

    private _span = 0 max (_last - _first);
    [(_landLength / (_span max 1)) min 1, _maxWater, _span, _first, _last]
};

// inside the world square: beyond its edges the engine reports no water, so the ground out there would count as land
BR_fnc_inWorld = {
    params ["_p"];

    (_p select 0) >= 0 && {(_p select 1) >= 0} && {(_p select 0) <= worldSize} && {(_p select 1) <= worldSize}
};

// the part of the line _a - _b inside the world square (BR_var_flightWorldMargin in from its edges): Liang-Barsky
BR_fnc_clipToWorld = {
    params ["_a", "_b"];

    _a = [_a select 0, _a select 1, 0];

    private _dx = (_b select 0) - (_a select 0);
    private _dy = (_b select 1) - (_a select 1);
    private _low = BR_var_flightWorldMargin;
    private _high = worldSize - BR_var_flightWorldMargin;
    private _t0 = 0;
    private _t1 = 1;

    {
        _x params ["_p", "_q"];

        if (_p == 0) then {
            if (_q < 0) then {_t0 = 2};
        } else {
            private _r = _q / _p;

            if (_p < 0) then {_t0 = _t0 max _r} else {_t1 = _t1 min _r};
        };
    } forEach [[-_dx, (_a select 0) - _low], [_dx, _high - (_a select 0)], [-_dy, (_a select 1) - _low], [_dy, _high - (_a select 1)]];

    if (_t0 > _t1) exitWith {[_a, [_b select 0, _b select 1, 0]]};

    [_a vectorAdd ([_dx, _dy, 0] vectorMultiply _t0), _a vectorAdd ([_dx, _dy, 0] vectorMultiply _t1)]
};

BR_fnc_planFlightRoute = {
    private _maxOffset = BR_var_flightLineOffset * BR_var_playAreaRadius;
    private _candidates = [];
    private _best = [];
    private _bestScore = -1e9;
    private _maxWater = 400 max (2000 min (BR_var_playAreaRadius * 0.2));
    private _minSpan = 400 max (BR_var_playAreaRadius * 0.8);

    for "_try" from 1 to BR_var_flightLineTries do {
        private _direction = random 360;
        private _offset = (random 2 - 1) * _maxOffset;

        private _crossing = [
            (BR_var_playAreaCenter select 0) + _offset * cos _direction,
            (BR_var_playAreaCenter select 1) - _offset * sin _direction,
            0
        ];
        private _halfLength = sqrt ((BR_var_playAreaRadius ^ 2) - (_offset ^ 2)) + BR_var_flightLeadIn;
        // judged as it will be flown: clipped to the map (BR_fnc_clipToWorld)
        private _clippedLine = [_crossing getPos [_halfLength, _direction + 180], _crossing getPos [_halfLength, _direction]] call BR_fnc_clipToWorld;
        private _start = [_clippedLine select 0] call BR_fnc_groundPos;
        private _end = [_clippedLine select 1] call BR_fnc_groundPos;
        private _quality = [[_start, _end], BR_var_flightRouteProbeStep] call BR_fnc_flightRouteQuality;
        _quality params ["_share", "_gap", "_span", "_first", "_last"];

        if (_first >= 0 && {_span > 100}) then {
            private _axis = [sin _direction, cos _direction, 0];
            private _line = [_start vectorAdd (_axis vectorMultiply (0 max (_first - BR_var_flightLeadIn))),
            _start vectorAdd (_axis vectorMultiply (_last + BR_var_flightLeadIn))];
            private _score = 10 * _share + (_span / _minSpan min 1) - _gap / (_maxWater max 1);

            if (_score > _bestScore) then {
                _bestScore = _score;
                _best = _line
            };

            if (_share >= BR_var_flightMinLandShare && {_gap <= _maxWater} && {_span >= _minSpan}) then {_candidates pushBack _line};
        };
    };

    private _line = if (_candidates isEqualTo []) then {_best} else {selectRandom _candidates};

    // fallback: across the play area's center (never the zone's end point: the route would give it away)
    if (_line isEqualTo []) then {
        private _point = BR_var_playAreaCenter;
        _line = [_point getPos [BR_var_flightLeadIn, 0], _point getPos [BR_var_flightLeadIn, 180]];
    };

    _line params ["_start", "_end"];

    // the line stays over the map: around all land the play area reaches far past the world's edges where the land
    // runs up to them
    private _clipped = [_start, _end] call BR_fnc_clipToWorld;
    _start = _clipped select 0;
    _end = _clipped select 1;

    private _bent = [_start] + ([_start, _end] call BR_fnc_flightViaPoints)+[_end];
    private _quality = [_bent] call BR_fnc_flightRouteQuality;
    if ((_quality select 0) >= BR_var_flightMinLandShare && {(_quality select 1) <= _maxWater}) then {_line = _bent};
    diag_log format ["BR flight route: %1 good candidates, land metrics %2", count _candidates, [_line] call BR_fnc_flightRouteQuality];
    _line
};

/*
    The route (BR_fnc_planFlightRoute) with its lengths, entry and forced jump (the route positions where it enters /
    leaves the play area), speed and altitude - before the aircraft exists, so the AI jump points can be planned on it
    while nothing flies yet (BR_fnc_startMatch).
*/
BR_fnc_planFlight = {
    BR_var_flightRoute = call BR_fnc_planFlightRoute;
    BR_var_flightStartTime = nil;
    BR_var_aiDropSpotAlong = nil;

    BR_var_flightRouteLengths = [0];

    for "_i" from 1 to count BR_var_flightRoute - 1 do {
        BR_var_flightRouteLengths pushBack ((BR_var_flightRouteLengths select (_i - 1)) +((BR_var_flightRoute
            select (_i - 1)) distance2D (BR_var_flightRoute select _i)));
    };

    private _routeLength = BR_var_flightRouteLengths select (count BR_var_flightRouteLengths - 1);
    private _insideAlong = [];

    for "_along" from 0 to _routeLength step BR_var_routeSampleStep do {
        private _point = [_along] call BR_fnc_routePoint;

        if (_point distance2D BR_var_playAreaCenter < BR_var_playAreaRadius && {[_point] call BR_fnc_inWorld} && {!surfaceIsWater _point}) then {
            _insideAlong pushBack _along;
        };
    };

    BR_var_flightEntry = _insideAlong param [0, BR_var_flightLeadIn];
    private _lastLand = _insideAlong param [count _insideAlong - 1, _routeLength - BR_var_flightLeadIn];
    private _safeLastLand = _insideAlong select {_x <= _lastLand - BR_var_forcedJumpMargin};
    BR_var_flightForcedJump = _safeLastLand param [count _safeLastLand - 1, BR_var_flightEntry];

    BR_var_flightSpeedRange params ["_minSpeed", "_maxSpeed"];

    BR_var_flightSpeed = _minSpeed max (((BR_var_flightForcedJump - BR_var_flightEntry) / BR_var_flightInsideTime) min _maxSpeed);
    BR_var_flightDuration = _routeLength / BR_var_flightSpeed;

    // level flight over the highest ground of the route
    private _highestGround = 0;

    for "_along" from 0 to _routeLength step BR_var_flightAltitudeStep do {
        _highestGround = _highestGround max (getTerrainHeightASL ([_along] call BR_fnc_routePoint));
    };

    BR_var_flightAltitude = _highestGround + BR_var_flightHeight;
};

/*
    The aircraft on the planned route (BR_fnc_planFlight), published with the route for the maps and the GPS. It starts
    flying here, before the AI jump points are planned: that takes up to two minutes on Altis, and every AI whose point
    lay behind the aircraft by then would jump at once.
*/
BR_fnc_createAircraft = {
    private _start = BR_var_flightRoute select 0;
    private _startPos = (_start select [0, 2]) + [BR_var_flightAltitude];
    private _aircraft = createVehicle [call BR_fnc_aircraftType, ASLToAGL _startPos, [], 0, "FLY"];

    _aircraft setDir (_start getDir (BR_var_flightRoute select 1));
    _aircraft setPosASL _startPos;
    _aircraft setVelocityModelSpace [0, BR_var_flightSpeed, 0];
    _aircraft lock true;
    [_aircraft, false] call ADG_fnc_allowDamage;
    createVehicleCrew _aircraft;

    // a careless, captive crew: nobody shoots at it, it shoots at nobody
    {
        _x setCaptive true;
        [_x, false] call ADG_fnc_allowDamage;
    } forEach crew _aircraft;

    private _crewGroup = group driver _aircraft;

    _crewGroup setBehaviour "CARELESS";
    _crewGroup setCombatMode "BLUE";
    _aircraft flyInHeightASL [BR_var_flightAltitude, BR_var_flightAltitude, BR_var_flightAltitude];

    // after the end of the route the pilot flies on by itself
    {
        private _waypoint = _crewGroup addWaypoint [_x, 0];

        _waypoint setWaypointType "MOVE";
        _waypoint setWaypointCompletionRadius BR_var_flightWaypointRadius;
    } forEach (BR_var_flightRoute select [1, count BR_var_flightRoute - 1]);

    // the clients compute the progress from start time and speed; BR_var_flightEndTime (serverTime): the forced jump
    BR_var_flightStartTime = serverTime;
    BR_var_flightEndTime = BR_var_flightStartTime + BR_var_flightForcedJump / BR_var_flightSpeed;
    BR_var_flightJumpEndPos = [BR_var_flightForcedJump] call BR_fnc_routePoint;
    BR_var_aircraft = _aircraft;

    {
        publicVariable _x;
    } forEach [

    "BR_var_flightStartTime", "BR_var_flightSpeed", "BR_var_flightEndTime", "BR_var_flightJumpEndPos",
    "BR_var_flightRoute", "BR_var_flightRouteLengths", "BR_var_flightAltitude", "BR_var_aircraft"
    ];

    call BR_fnc_startFlightStep;
};

/*
    Server and every client: BR_fnc_flightStep each frame until the end of the route. A client only gets network
    updates of the aircraft and simulates the rest itself, so it would jitter; with the schedule known (start time,
    route, speed, altitude) each client puts it where the server does.
*/
BR_fnc_startFlightStep = {
    if (!isNil "BR_var_flightStepEh") exitWith {};

    BR_var_flightHeading = vectorNormalized ((BR_var_flightRoute select 1) vectorDiff (BR_var_flightRoute select 0));
    BR_var_flightStepEh = addMissionEventHandler ["EachFrame", {call BR_fnc_flightStep}];
};

/*
    Server, every frame of the flight: the aircraft is where the schedule says (BR_fnc_flightProgress), level at the
    route's altitude, moving at BR_var_flightSpeed - set with setVelocityTransformation as BIS_fnc_unitPlay does (the
    flight model ignores a plain setVelocity). Position and heading come from the route points BR_var_flightLookAhead
    behind and ahead: straight on the legs, a smooth curve at the bends. Ends at the end of the route.
*/
BR_fnc_flightStep = {
    private _along = call BR_fnc_flightProgress;

    if (isNull BR_var_aircraft || {_along > (BR_var_flightRouteLengths select (count BR_var_flightRouteLengths - 1))}) exitWith {
        removeMissionEventHandler ["EachFrame", BR_var_flightStepEh];
        BR_var_flightStepEh = nil;
    };

    private _reach = BR_var_flightSpeed * BR_var_flightLookAhead;
    private _behind = [_along - _reach] call BR_fnc_routePoint;
    private _ahead = [_along + _reach] call BR_fnc_routePoint;
    private _middle = (_behind vectorAdd _ahead) vectorMultiply 0.5;
    private _position = [_middle select 0, _middle select 1, BR_var_flightAltitude];
    private _course = [(_ahead select 0) - (_behind select 0), (_ahead select 1) - (_behind select 1), 0];

    if (vectorMagnitude _course > 1) then {
        BR_var_flightHeading = vectorNormalized _course;
    };

    private _velocity = BR_var_flightHeading vectorMultiply BR_var_flightSpeed;

    BR_var_aircraft setVelocityTransformation [
    _position, _position, _velocity, _velocity, BR_var_flightHeading, BR_var_flightHeading, [0, 0, 1], [0, 0, 1], 0
    ];
};

/*
    A few drop spots close to the straight line from _start to _end, in their order along it (the route bends through
    them): one random spot per place, the places in random order (each place as likely as any other, whatever its size)
*/
BR_fnc_flightViaPoints = {
    params ["_start", "_end"];

    private _lineLength = _start distance2D _end;
    private _direction = (_end vectorDiff _start) vectorMultiply (1 / (_lineLength max 1));
    private _corridor = (BR_var_flightViaCorridor * BR_var_playAreaRadius) max BR_var_flightViaMinCorridor;
    private _places = createHashMap; // place name ("?": each spot its own) -> [along, position] of its spots

    {
        private _offset = (_x select 0) vectorDiff _start;
        private _along = _offset vectorDotProduct _direction;
        private _lateral = sqrt (0 max ((vectorMagnitudeSqr _offset) - _along ^ 2));

        if (_lateral < _corridor && {_along > BR_var_flightLeadIn} && {_along < _lineLength - BR_var_flightLeadIn}) then {
            private _place = [_x select 1, str _forEachIndex] select ((_x select 1) == "?");

            (_places getOrDefaultCall [_place, {[]}, true]) pushBack [_along, _x select 0];
        };
    } forEach BR_var_aiDropSpots;

    private _candidates = (values _places) apply {selectRandom _x};

    _candidates = _candidates call BIS_fnc_arrayShuffle;

    private _vias = [];

    {
        _x params ["_along"];

        if(count _vias < BR_var_flightViaMax &&
            {(_vias findIf {abs ((_x select 0) - _along) < BR_var_flightViaSpacing * BR_var_playAreaRadius}) ==
            -1}) then {
            _vias pushBack _x;
        };
    } forEach _candidates;

    _vias sort true;
    _vias apply {_x select 1}
};

// the position at _along metres of the route
BR_fnc_routePoint = {
    params ["_along"];

    if (_along <= 0) exitWith {BR_var_flightRoute select 0};

    private _segment = BR_var_flightRouteLengths findIf {_x >= _along};

    if (_segment == -1) exitWith {BR_var_flightRoute select (count BR_var_flightRoute - 1)};

    private _segmentStart = BR_var_flightRouteLengths select (_segment - 1);
    private _segmentLength = ((BR_var_flightRouteLengths select _segment) - _segmentStart) max 0.01;
    private _from = BR_var_flightRoute select (_segment - 1);

    _from vectorAdd (((BR_var_flightRoute select _segment) vectorDiff _from) vectorMultiply ((_along - _segmentStart) / _segmentLength))
};

// [route position (m), 2D distance] of the route point closest to _pos
BR_fnc_routeClosest = {
    params ["_pos"];

    private _best = [0, 1e9];

    for "_i" from 1 to count BR_var_flightRoute - 1 do {
        private _from = BR_var_flightRoute select (_i - 1);
        private _segment = (BR_var_flightRoute select _i) vectorDiff _from;
        private _length = vectorMagnitude _segment;

        private _ratio = if (_length > 0) then {
            ((((_pos vectorDiff _from) vectorDotProduct _segment) / (_length ^ 2)) max 0) min 1
        } else {0};

        private _distance = _pos distance2D (_from vectorAdd (_segment vectorMultiply _ratio));

        if (_distance < (_best select 1)) then {
            _best = [(BR_var_flightRouteLengths select (_i - 1)) + _ratio * _length, _distance];
        };
    };

    _best
};

// metres the aircraft has flown along the route (server and client: it keeps to the schedule, BR_fnc_flightStep)
BR_fnc_flightProgress = {
    if (isNil "BR_var_flightStartTime") exitWith {0};
    BR_var_flightSpeed * (serverTime - BR_var_flightStartTime)
};

// the first route position an AI may jump at: inside the play area, not behind the aircraft
BR_fnc_aiJumpStart = {
    (BR_var_flightEntry + BR_var_aiJumpMargin) max (call BR_fnc_flightProgress)
};

// a random route position above land (if one of a few tries is) for an AI without a drop spot in reach
BR_fnc_randomJumpPoint = {
    private _start = call BR_fnc_aiJumpStart;
    private _end = _start max BR_var_flightForcedJump;
    private _jumpAt = _start;

    for "_i" from 1 to BR_var_aiJumpTries do {
        _jumpAt = _start + random (_end - _start);

        if (!surfaceIsWater ([_jumpAt] call BR_fnc_routePoint)) exitWith {};

    };

    _jumpAt
};

/*
    Start of the flight: the places AI teams drop at, BR_var_aiDropSpots [[position, name, capacity, houses], ...] -
    clusters of houses to loot (towns, villages, military sites, other places with buildings), at least
    BR_var_aiDropSpacing apart (a big town has several spots), never empty country. Capacity: AI teams per spot, 1 (2 for
    big clusters); BR_var_aiDropCounts counts the teams sent there. The name is the nearest named place.
*/
BR_fnc_planAiDropSpots = {
    private _houses = ((nearestObjects [BR_var_playAreaCenter, ["House"], BR_var_playAreaRadius - BR_var_aiDropEdgeMargin, true]) +

    (BR_var_lootTents select {_x distance2D BR_var_playAreaCenter <= BR_var_playAreaRadius - BR_var_aiDropEdgeMargin})) select {
        [_x] call BR_fnc_isLootBuilding &&
        // castle walls, stairs and gates are no houses here either (as for the loot site markers): one castle would count
        // as dozens of buildings and draw squads onto its walls, whose loot they never reach
        {private _class = toLowerANSI typeOf _x; (BR_var_aiDropLeftOut findIf {_x in _class}) < 0}
    };

    private _spotGrid = createHashMap; // [cell x, cell y] (BR_var_aiDropSpacing cells) -> spot positions
    private _houseGrid = createHashMap; // [cell x, cell y] (BR_var_aiDropBuildingRadius cells) -> houses

    {
        (_houseGrid getOrDefaultCall [
        [floor ((getPosATL _x select 0) / BR_var_aiDropBuildingRadius), floor ((getPosATL _x select 1) / BR_var_aiDropBuildingRadius)],
        {[]},
        true
        ]) pushBack _x;
    } forEach _houses;

    BR_var_aiDropSpots = [];

    {
        private _pos = [getPosATL _x] call BR_fnc_groundPos;
        private _cellX = floor ((_pos select 0) / BR_var_aiDropSpacing);
        private _cellY = floor ((_pos select 1) / BR_var_aiDropSpacing);
        private _free = true;

        for "_offsetX" from -1 to 1 do {
            for "_offsetY" from -1 to 1 do {
                if (_free) then {
                    _free = ((_spotGrid getOrDefault [[_cellX + _offsetX, _cellY + _offsetY], []]) findIf {
                        (_x distance2D _pos) < BR_var_aiDropSpacing

                    }) == -1;
                };
            };
        };

        if (_free) then {

            // the houses of the 3 x 3 cells around (a whole map has thousands)
            private _houseCellX = floor ((_pos select 0) / BR_var_aiDropBuildingRadius);
            private _houseCellY = floor ((_pos select 1) / BR_var_aiDropBuildingRadius);
            private _nearHouses = [];

            for "_offsetX" from -1 to 1 do {
                for "_offsetY" from -1 to 1 do {
                    _nearHouses append (_houseGrid getOrDefault [[_houseCellX + _offsetX, _houseCellY + _offsetY], []]);
                };
            };

            private _clusterHouses = _nearHouses inAreaArray [_pos, BR_var_aiDropBuildingRadius, BR_var_aiDropBuildingRadius];

            if (count _clusterHouses >= BR_var_aiDropMinBuildings) then {
                private _place = (nearestLocations [_pos, BR_var_aiDropLocationTypes, BR_var_aiDropSpacing * 3]) param [0, locationNull];

                (_spotGrid getOrDefaultCall [[_cellX, _cellY], {[]}, true]) pushBack _pos;
                BR_var_aiDropSpots pushBack [
                _pos,
                [text _place, "?"] select (isNull _place),
                1 max floor (count _clusterHouses / BR_var_aiDropBuildingsPerAi),
                _clusterHouses
                ];
            };
        };
    } forEach (_houses call BIS_fnc_arrayShuffle);

    BR_var_aiDropCounts = BR_var_aiDropSpots apply {0};   // teams sent there
    BR_var_aiDropLoad = BR_var_aiDropSpots apply {0};     // AI sent there (the room counts AI)
    BR_var_aiJumpSlots = [];
    BR_var_aiDropSpotAlong = nil;
};

// AI-only teams get a drop spot each (BR_fnc_aiChooseDrop); AI team mates of players jump with their first player (or
// forced)
BR_fnc_assignJumpPoints = {
    {
        private _units = [_x] call BR_fnc_teamUnits;
        private _aiUnits = _units select {!isPlayer _x};

        if ((_units findIf {isPlayer _x}) == -1) then {
            [_aiUnits] call BR_fnc_aiChooseDrop;
        } else {

            {
                _x setVariable ["BR_var_jumpAt", BR_var_flightForcedJump];
            } forEach _aiUnits;
        };
    } forEach BR_var_matchTeams;
};

/*
    A drop spot for AI units (a team, or one unit taken over aboard): a random spot in gliding reach of the route that
    has room left, else the reachable one with the fewest teams. They jump at the route point closest to it and land
    next to one of its houses (BR_var_aiDropTarget, BR_fnc_aiDescent). No spot in reach: a random jump point, no gliding.
*/
BR_fnc_aiChooseDrop = {
    params ["_units"];

    private _start = call BR_fnc_aiJumpStart;
    private _end = _start max BR_var_flightForcedJump;
    private _reach = BR_var_aiDropReachShare * BR_var_flightHeight * BR_var_aiGlideSpeed / BR_var_aiSinkRate;
    private _reachable = [];

    // each spot's closest route position, once per flight (150 teams asked it of all spots again: 55-110 s on Altis)
    if (isNil "BR_var_aiDropSpotAlong") then {
        BR_var_aiDropSpotAlong = BR_var_aiDropSpots apply {([_x select 0] call BR_fnc_routeClosest) select 0};
    };

    {
        private _along = ((BR_var_aiDropSpotAlong select _forEachIndex) max _start) min _end;

        if (([_along] call BR_fnc_routePoint) distance2D (_x select 0) <= _reach) then {
            _reachable pushBack [_forEachIndex, _along];
        };
    } forEach BR_var_aiDropSpots;

    if (_reachable isEqualTo []) exitWith {
        private _jumpAt = [] call BR_fnc_randomJumpPoint;

        {
            _x setVariable ["BR_var_jumpAt", _jumpAt];
            _x setVariable ["BR_var_aiDropTarget", nil];
        } forEach _units;
    };

    // Each reachable spot costs its load after this team squared (teams / room, room by its buildings: the loot there;
    // squared, so one big town does not draw a large share of the teams) plus its distance outside of the first zone in
    // walks of the first phase; the cheapest wins (ties at random). Teams spread by the loot of the spots and only go
    // far from the zone when the near spots are much fuller.
    BR_var_firstZone params ["_zoneCenter", "_zoneRadius"];

    private _firstPhase = BR_var_zonePhases select 0;
    private _walk = 1 max (BR_var_aiTravelSpeed * ((_firstPhase select 0) + (_firstPhase select 1)));
    private _costs = _reachable apply {
        (BR_var_aiDropSpots select (_x select 0)) params ["_pos", "", "_room"];
        (((BR_var_aiDropLoad select (_x select 0)) + count _units) / _room) ^ 2 + (0 max ((_pos distance2D _zoneCenter) - _zoneRadius)) / _walk
    };
    private _cheapest = selectMin _costs;
    private _best = [];
    {
        if ((_costs select _forEachIndex) <= _cheapest + 0.001) then {_best pushBack _x};
    } forEach _reachable;
    private _choice = selectRandom _best;

    _choice params ["_spotIndex", "_jumpAt"];

    (BR_var_aiDropSpots select _spotIndex) params ["", "_name", "", "_houses"];

    BR_var_aiDropCounts set [_spotIndex, (BR_var_aiDropCounts select _spotIndex) + 1];
    BR_var_aiDropLoad set [_spotIndex, (BR_var_aiDropLoad select _spotIndex) + count _units];

    private _landing = [getPosATL (selectRandom _houses), BR_var_aiDropLandSpread, true] call BR_fnc_randomLandPos;

    // no two AI teams jump closer than BR_var_aiJumpSpacing along the route (teams of neighbouring spots left at one
    // point, opened their canopies at the same moment and 8 collided at 590 m): the free slot nearest to its jump point,
    // alternately before and after it, within BR_var_aiJumpSpread
    private _base = _jumpAt;
    private _steps = floor (BR_var_aiJumpSpread / BR_var_aiJumpSpacing);
    for "_k" from 0 to 2 * _steps do {
        private _try = ((_base + ([-1, 1] select (_k mod 2 == 0)) * ceil (_k / 2) * BR_var_aiJumpSpacing) max _start) min _end;
        if ((BR_var_aiJumpSlots findIf {abs (_x - _try) < BR_var_aiJumpSpacing}) == -1) exitWith {_jumpAt = _try};
    };
    BR_var_aiJumpSlots pushBack _jumpAt;

    {
        _x setVariable ["BR_var_jumpAt", _jumpAt];
        _x setVariable ["BR_var_aiDropTarget", [_landing getPos [BR_var_aiDropMateSpread * _forEachIndex, random 360]] call BR_fnc_groundPos];
        _x setVariable ["BR_var_aiDropSpot", _name];
    } forEach _units;
};

// AI jumps on its point, everyone still aboard at the forced jump; then the fight starts and the aircraft leaves
BR_fnc_flightLoop = {
    private _startTime = time;
    private _timeout = BR_var_flightDuration * BR_var_flightTimeoutShare;

    waitUntil {
        sleep BR_var_jumpCheckInterval;

        private _progress = call BR_fnc_flightProgress;
        private _forced = _progress >= BR_var_flightForcedJump || {time - _startTime > _timeout};
        private _aboard = BR_var_rosterUnits select {alive _x && {_x getVariable ["BR_var_aboard", false]}};

        {
            if (isPlayer _x) then {
                if (_forced && {time >= (_x getVariable ["BR_var_jumpRequested", 0])}) then {
                    _x setVariable ["BR_var_jumpRequested", time + BR_var_forcedJumpResend];
                    [] remoteExecCall ["BR_fnc_jumpClient", _x];
                };
            } else {

                if (_forced || {_progress >= (_x getVariable ["BR_var_jumpAt", 0])}) then {
                    [_x] call BR_fnc_aiJump;
                };
            };
        } forEach _aboard;

        _aboard isEqualTo [] || {time - _startTime > _timeout + 30}
    };

    ["fight"] call BR_fnc_setState;

    // players whose client did not answer the forced jump (yet) get a last request while the aircraft is still there
    {
        [] remoteExecCall ["BR_fnc_jumpClient", _x];
    } forEach (BR_var_rosterUnits select {alive _x && {isPlayer _x} && {_x getVariable ["BR_var_aboard", false]}});

    sleep BR_var_aircraftCleanupDelay;

    // whoever is still aboard now (client not responding) missed the jump and is out
    {
        _x setDamage 1;
    } forEach (BR_var_rosterUnits select {alive _x && {_x getVariable ["BR_var_aboard", false]}});

    {
        BR_var_aircraft deleteVehicleCrew _x;
    } forEach crew BR_var_aircraft;

    deleteVehicle BR_var_aircraft;
};

// remoteExecCall'd by BR_fnc_jumpClient: the first player of a team who jumps takes the AI team mates along, with
// teamJump also the other players
BR_fnc_unitJumped = {
    params ["_unit"];

    {
        if (isPlayer _x) then {
            if (BR_var_teamJump) then {
                [] remoteExecCall ["BR_fnc_jumpClient", _x];
            };
        } else {

            [_x] call BR_fnc_aiJump;
        };
    } forEach (([_unit getVariable ["BR_var_teamId", -1]] call BR_fnc_teamUnits) select {

        alive _x && {_x getVariable ["BR_var_aboard", false]}

    });
};

BR_fnc_aiJump = {
    params ["_unit"];

    if (isPlayer _unit || {!(_unit getVariable ["BR_var_aboard", false])}) exitWith {};

    _unit setVariable ["BR_var_aboard", false, true];
    _unit setVariable ["BR_var_aiState", "falling"];
    [_unit, [] call BR_fnc_jumpPosition] call BR_fnc_unparkUnit;
    [_unit] call BR_fnc_startFreefall;
    [_unit] spawn BR_fnc_aiDescent;
};

/*
    Scheduled: free fall and parachute of an AI, then state "loot". With a drop spot (BR_var_aiDropTarget) it opens the
    parachute early enough to glide there and flies it like a player (BR_fnc_aiGlide). A player who takes the unit over
    meanwhile falls on his own (BR_fnc_resumeCombatant).
*/
BR_fnc_aiDescent = {
    params ["_unit"];

    private _target = _unit getVariable ["BR_var_aiDropTarget", []];

    waitUntil {
        sleep BR_var_aiSteerInterval;

        private _distance = if (_target isEqualTo []) then {0} else {_unit distance2D _target};

        !alive _unit || {isPlayer _unit} || {!isNull objectParent _unit} ||
            {((getPos _unit) select 2) <=(BR_var_aiOpenHeight max ((_distance / BR_var_aiGlideSpeed) *
            BR_var_aiSinkRate))}
    };

    if (isPlayer _unit) exitWith {
        [_unit, true] call ADG_fnc_allowDamage;
    };

    if (alive _unit && {isNull objectParent _unit}) then {
        [_unit] call BR_fnc_openParachute;
    };

    waitUntil {
        sleep BR_var_aiSteerInterval;

        private _parachute = objectParent _unit;

        // steered every frame (BR_fnc_aiGlideFrame): between steps half a second apart the engine let the canopy drift
        // off (measured: 800 m off a 1 km glide), steered every frame it lands within a few metres of the spot
        if (_target isNotEqualTo [] && {!isNull _parachute} && {!isPlayer _unit} && {!(_parachute getVariable ["BR_var_aiGliding", false])}) then {
            [_parachute, _target] call BR_fnc_aiStartGlide;
        };

        !alive _unit || {isNull _parachute && {((getPos _unit) select 2) < 2}}
    };

    if (backpack _unit == "B_Parachute") then {
        removeBackpack _unit;
    };

    // no damage from the jump on until the landing (the parachute's opening jolt downed or killed some)
    [_unit, true] call ADG_fnc_allowDamage;

    if (alive _unit) then {
        _unit setVariable ["BR_var_aiState", "loot"];
    };
};

/*
    The AI's input on its parachute, like a player's: the canopy turns towards the drop spot at most BR_var_aiTurnRate
    and flies forward at BR_var_aiGlideSpeed (an AI pilot gives no forward input by itself: its canopy only drifts),
    slowing down to BR_var_aiBrakeShare of it when it would overshoot. Sinking, wind and the landing are the engine's;
    nothing is moved by position, the heading is set only while turning. The last metres it lands by itself.
*/
BR_fnc_aiGlide = {
    params ["_parachute", "_target", ["_deltaTime", BR_var_aiSteerInterval], ["_avoid", [0, 0]]];

    if (((getPos _parachute) select 2) <= BR_var_aiGlideLandHeight) exitWith {};

    private _velocity = velocity _parachute;
    private _distance = _parachute distance2D _target;
    private _timeLeft = 1 max (((getPos _parachute) select 2) / (BR_var_aiSinkRate max -(_velocity select 2)));
    private _speed = (BR_var_aiBrakeShare * BR_var_aiGlideSpeed) max (BR_var_aiGlideSpeed min (_distance / _timeLeft));
    // the last metres slowly, as a player flares: at full speed canopies died against houses and slopes, and at 6 m/s
    // pilots circling over their drop spot still died on touching down (Chernarus)
    if (((getPos _parachute) select 2) < BR_var_aiFlareHeight) then {_speed = _speed min BR_var_aiFlareSpeed};
    // the way to the drop spot, bent away from canopies close by (_avoid, BR_fnc_aiGlideFrame)
    private _toTarget = [((_target select 0) - ((getPosATL _parachute) select 0)), ((_target select 1) - ((getPosATL _parachute) select 1)), 0];
    private _steer = (if (_distance > 0.1) then {vectorNormalized _toTarget} else {[0, 0, 0]}) vectorAdd [_avoid select 0, _avoid select 1, 0];
    private _turn = (((((_steer select 0) atan2 (_steer select 1)) + 360) mod 360) - getDir _parachute + 540) mod 360 - 180;
    private _maxTurn = BR_var_aiTurnRate * _deltaTime;
    private _heading = getDir _parachute;

    // the heading only while it really turns: setDir is a transform correction that clients see as a jerk, and the
    // engine never turns the canopy by itself, so on course nothing but the velocity is set. Without
    // setDir it cannot be steered at all: the engine keeps its own flight direction (velocity only: 2 km off).
    if (abs _turn > BR_var_aiTurnDeadband) then {
        _heading = _heading + ((-_maxTurn) max (_turn min _maxTurn));
        _parachute setDir _heading;
    };

    _parachute setVelocity [_speed * sin _heading, _speed * cos _heading, _velocity select 2];
};

// the AI parachutes in the air [parachute, drop spot], steered every frame by one EachFrame handler (server)
BR_var_aiGlideChutes = [];

BR_fnc_aiStartGlide = {
    params ["_parachute", "_target"];

    _parachute setVariable ["BR_var_aiGliding", true];
    BR_var_aiGlideChutes pushBack [_parachute, _target];

    if (isNil "BR_var_aiGlideEh") then {
        BR_var_aiGlideEh = addMissionEventHandler ["EachFrame", {call BR_fnc_aiGlideFrame}];
    };
};

BR_fnc_aiGlideFrame = {
    BR_var_aiGlideChutes = BR_var_aiGlideChutes select {
        private _parachute = _x select 0;

        (alive _parachute) && {!isNull (driver _parachute)} && {!isPlayer (driver _parachute)} &&
            {((getPos _parachute) select 2) > BR_var_aiGlideLandHeight}
    };

    // canopies flying into each other killed both pilots (Stratis, 40 AI: 13 died in the air): teams of one drop
    // spot jump together and the exact steering kept them on parallel paths. Away from every canopy within
    // BR_var_aiChuteSeparation (AI and players), the closer the stronger.
    if (diag_tickTime >= (missionNamespace getVariable ["BR_var_aiNextChuteAvoid", 0])) then {
        BR_var_aiNextChuteAvoid = diag_tickTime + BR_var_aiChuteAvoidInterval;

        {
            private _parachute = _x select 0;
            private _pos = getPosASL _parachute;
            private _avoid = [0, 0, 0];

            {
                private _offset = _pos vectorDiff (getPosASL _x);
                private _distance = vectorMagnitude _offset;

                if (_x isNotEqualTo _parachute && {_distance < BR_var_aiChuteSeparation} && {_distance > 0.01}) then {
                    // right above or below each other there is no side to leave to: the upper one goes right of its
                    // heading, the lower one left (two canopies 5 m apart at 160 m collided)
                    private _side = if ((vectorMagnitude [_offset select 0, _offset select 1, 0]) < 3) then {
                        [sin (getDir _parachute + 90 * ([-1, 1] select ((_offset select 2) > 0))),
                            cos (getDir _parachute + 90 * ([-1, 1] select ((_offset select 2) > 0))), 0]
                    } else {
                        vectorNormalized [_offset select 0, _offset select 1, 0]
                    };
                    _avoid = _avoid vectorAdd (_side vectorMultiply (BR_var_aiChuteAvoidWeight * (1 - _distance / BR_var_aiChuteSeparation)));
                };
            } forEach (_parachute nearEntities [["ParachuteBase"], BR_var_aiChuteSeparation]);

            _parachute setVariable ["BR_var_aiAvoid", [_avoid select 0, _avoid select 1]];
        } forEach BR_var_aiGlideChutes;
    };

    {
        _x params ["_parachute", "_target"];

        [_parachute, _target, diag_deltaTime, _parachute getVariable ["BR_var_aiAvoid", [0, 0]]] call BR_fnc_aiGlide;
    } forEach BR_var_aiGlideChutes;

    if (BR_var_aiGlideChutes isEqualTo []) then {
        removeMissionEventHandler ["EachFrame", BR_var_aiGlideEh];
        BR_var_aiGlideEh = nil;
    };
};

// ASL position just behind and below the aircraft, a bit apart for every jumper
// behind and below the aircraft's tail: a jumper must not hit it (the Blackfish is 30 m long and flies 200 m/s)
BR_fnc_jumpPosition = {
    private _tail = ((boundingBoxReal BR_var_aircraft) select 0) select 1;

    BR_var_aircraft modelToWorldWorld [random 8 - 4, _tail - BR_var_jumpTailGap - random 8, -8 - random 4]
};

// ---- jumping (where the unit is local) ----

BR_fnc_startFreefall = {
    params ["_unit"];

    removeBackpack _unit;
    _unit addBackpackGlobal "B_Parachute";
    _unit switchMove BR_var_freefallAnimation;
    _unit setDir random 360;

    // a share of the aircraft's speed, at most BR_var_jumpMaxSpeed (a fast aircraft over a whole map)
    private _velocity = (velocity BR_var_aircraft) vectorMultiply BR_var_jumpVelocityShare;

    _unit setVelocity ((vectorNormalized _velocity) vectorMultiply ((vectorMagnitude _velocity) min BR_var_jumpMaxSpeed));
};

// opens the parachute; a unit that still falls free a moment later (the action did not take) gets one directly
BR_fnc_openParachute = {
    params ["_unit"];

    _unit action ["OpenParachute", _unit];

    [_unit] spawn {
        params ["_unit"];

        sleep BR_var_parachuteCheckDelay;

        if (alive _unit && {isNull objectParent _unit} && {((getPos _unit) select 2) > BR_var_freefallMinHeight}) then {
            private _parachute = createVehicle [BR_var_parachuteType, [0, 0, 1000], [], 0, "FLY"];

            _parachute setPosASL (getPosASL _unit);
            _parachute setDir (getDir _unit);
            _unit moveInDriver _parachute;

            if (backpack _unit == "B_Parachute") then {
                removeBackpack _unit;
            };
        };
    };
};

/*
    Scheduled. Opens the parachute below _openHeight unless that happened already, waits for the landing, drops an
    unused parachute and calls _onLanded with [_unit].
*/
BR_fnc_watchFreefall = {
    params ["_unit", "_openHeight", "_onLanded"];

    waitUntil {
        sleep 0.2;
        !alive _unit || {!isNull objectParent _unit} || {((getPos _unit) select 2) <= _openHeight}
    };

    if (alive _unit && {isNull objectParent _unit}) then {
        [_unit] call BR_fnc_openParachute;
    };

    waitUntil {
        sleep 0.5;
        !alive _unit || {isNull objectParent _unit && {((getPos _unit) select 2) < 2}}
    };

    if (backpack _unit == "B_Parachute") then {
        removeBackpack _unit;
    };

    if (alive _unit) then {
        [_unit] call _onLanded;
    };
};

// ---- flight view (client) ----

BR_var_jumpKey = 57; // space (DIK code)
BR_var_unhideRetryTime = 2; // s: a seated player still hidden after this long is shown again
BR_var_seatWaitTime = 1.5; // s: a move into / out of the server's aircraft counts when it took effect this soon
BR_var_boardFadeTime = 1.5; // s: fade to black before the warmup ends, fade in to the aircraft once seated ...
BR_var_boardSettleTime = 0.5; // ... after the camera had this long to settle on the aircraft
BR_var_seatRetryInterval = 5; // s: a player riding along attached tries to get a seat this often
BR_var_flightDiagInterval = 3; // s: the flight view's state goes to the client RPT this often ("BR flight diag")

/*
    Scheduled: the player rides in a passenger seat of the aircraft in its external (3rd person) view - the engine's
    own camera: smooth, the aircraft in the middle, the player's mouse settings for looking around, zoom as always. Map
    and GPS keys work as everywhere; the GPS is kept open in the right panel (BR_fnc_gpsPanelLoop) and shows the route,
    the zone and the last jump point (BR\mapDraw.sqf). Until the player jumps (space) or is made to jump.
*/
BR_fnc_flightClient = {
    // black until the player sits in the aircraft with its camera on it (from the warmup it is black already:
    // BR_fnc_waitForBoarding; a player joining during the flight gets black at once)
    BR_var_flightViewReady = false;

    if !(missionNamespace getVariable ["BR_var_boardBlack", false]) then {
        cutText ["", "BLACK FADED", 0, true];
        0 fadeSound 0;
    };

    waitUntil {!isNil "BR_var_aircraft" && {!isNull BR_var_aircraft} && {!isNil "BR_var_flightStartTime"}};

    [player] call BR_fnc_applyBaseLoadout;
    call CMN_fnc_stopCameraViewLoop; // the view loop would force the 1st person view of the thirdPerson param

    // simulated before boarding (a frozen unit's head - and the camera following it - ignores the mouse); the few
    // seconds until the seat took effect it drops from the park position over the sea (no damage until the landing)
    [player, true] call CMN_fnc_setSimulationGlobal;
    call BR_fnc_boardAircraft;
    [] spawn BR_fnc_rideAlongAircraft;
    [] spawn BR_fnc_flightDiagLoop;
    call BR_fnc_showGpsRight;

    // seated (or riding along attached) with the external view on the aircraft: a moment for the camera to settle on
    // it, then the fade to the aircraft; only then the jump prompt and the jump key
    player switchCamera "EXTERNAL";
    sleep BR_var_boardSettleTime;
    cutText ["", "BLACK IN", BR_var_boardFadeTime, true];
    BR_var_boardFadeTime fadeSound 1;
    BR_var_boardBlack = false;
    sleep BR_var_boardFadeTime;
    BR_var_flightViewReady = true;

    // space jumps; no text of its own: the HUD shows the jump prompt and the time left (BR_var_flightEndTime)
    BR_var_jumpPressed = false;

    private _keyEh = (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["", "_key"];

        if (_key == BR_var_jumpKey && {!visibleMap}) then {
            BR_var_jumpPressed = true;
        };

        false
    }];

    waitUntil {BR_var_jumpPressed || {!(player getVariable ["BR_var_aboard", false])}};
    (findDisplay 46) displayRemoveEventHandler ["KeyDown", _keyEh];

    if (BR_var_jumpPressed) then {
        call BR_fnc_jumpClient;
    };

    call BR_fnc_endFlightView;
};

/*
    Scheduled: while aboard the player sits in the aircraft in its external view; with all passenger seats taken he
    rides along attached below it. Boarded again whenever something moved him out (a park that arrived late:
    BR_fnc_lockRoster). Kept simulated and, when seated, visible: a frozen unit's head - and with it the 3rd person
    camera - does not follow the mouse.
*/
BR_fnc_rideAlongAircraft = {
    BR_var_unhideRequestTime = -1;
    BR_var_seatRetryTime = time + BR_var_seatRetryInterval;

    while {player getVariable ["BR_var_aboard", false] && {!isNull BR_var_aircraft}} do {
        private _seated = (objectParent player) isEqualTo BR_var_aircraft;

        // out (again) or riding along attached: a seat (once in a while, maybe one is free now)
        if (!_seated && {(attachedTo player) isNotEqualTo BR_var_aircraft || {time > BR_var_seatRetryTime}}) then {
            BR_var_seatRetryTime = time + BR_var_seatRetryInterval;
            call BR_fnc_boardAircraft;
        };

        // a seat that took effect late (after the attach fallback)
        if ((objectParent player) isEqualTo BR_var_aircraft && {!isNull attachedTo player}) then {
            detach player;
        };

        if (!simulationEnabled player) then {
            diag_log "BR flight diag: the player's simulation was off - on again";
            [player, true] call CMN_fnc_setSimulationGlobal;
        };

        if((objectParent player) isEqualTo BR_var_aircraft && {isObjectHidden player} &&
            {time > BR_var_unhideRequestTime + BR_var_unhideRetryTime}) then {
            BR_var_unhideRequestTime = time;
            [player, false] remoteExecCall ["hideObjectGlobal", 2];
        };

        // the view only if something changed it (setting it again and again kept the mouse from turning it)
        if (cameraView != "EXTERNAL") then {
            player switchCamera "EXTERNAL";
        };

        sleep 0.5;
    };
};

/*
    Scheduled: waits until the player sits in the aircraft (or, _in false, in no vehicle): a move into or out of the
    server's aircraft takes effect only when the server answered - checked at once, a boarded player was taken for
    seatless and attached outside, the camera on the aircraft (which ignores the mouse). True if it took effect.
*/
BR_fnc_waitSeated = {
    params [["_in", true]];

    private _timeout = diag_tickTime + BR_var_seatWaitTime;
    private _done = [{isNull objectParent player}, {(objectParent player) isEqualTo BR_var_aircraft}] select _in;

    waitUntil {call _done || {diag_tickTime > _timeout}};

    call _done
};

/*
    Scheduled: into the aircraft, a free passenger seat - a plain cargo seat first (its 3rd person camera turns with
    the mouse around the aircraft), then a person turret, then any seat (moveInAny could pick a crew seat like the
    copilot's). With all seats taken attached below the aircraft, the camera on the (hidden) player: it still turns
    with the mouse. Detached first: an attachTo left over holds the unit.
*/
BR_fnc_boardAircraft = {
    private _aircraft = BR_var_aircraft;

    if (!isServer && {!isNil "BR_var_flightRouteLengths"} && {!isNil "BR_var_flightAltitude"}) then {
        call BR_fnc_startFlightStep;
    };

    if (!isNull attachedTo player) then {
        detach player;
    };

    if (!isNull objectParent player && {(objectParent player) isNotEqualTo _aircraft}) then {
        moveOut player;
        [false] call BR_fnc_waitSeated;
    };

    private _freeSeats = (fullCrew [_aircraft, "", true]) select {isNull (_x select 0)};
    private _cargoSeat = _freeSeats findIf {(_x select 1) == "cargo" && {!(_x select 4)}};
    private _turretSeat = _freeSeats findIf {(_x select 4) && {(_x select 3) isNotEqualTo []}};
    private _cargoIndex = if (_cargoSeat >= 0) then {(_freeSeats select _cargoSeat) select 2} else {-1};
    private _turretPath = if (_turretSeat >= 0) then {(_freeSeats select _turretSeat) select 3} else {[]};
    private _boardedBy = "";

    {
        _x params ["_how", "_available"];

        if (_available && {(objectParent player) isNotEqualTo _aircraft}) then {
            switch (_how) do {
                case "cargo": {
                    player moveInCargo [_aircraft, _cargoIndex];
                };
                case "personTurret": {
                    player moveInTurret [_aircraft, _turretPath];
                };
                default {
                    player moveInAny _aircraft;
                };
            };

            if (call BR_fnc_waitSeated) then {
                _boardedBy = format ["%1 (cargo index %2, turret %3)", _how, _cargoIndex, _turretPath];
            };
        };
    } forEach [["cargo", _cargoIndex >= 0], ["personTurret", _turretPath isNotEqualTo []], ["anySeat", true]];

    if ((objectParent player) isEqualTo _aircraft) exitWith {
        player switchCamera "EXTERNAL";
        diag_log format ["BR flight diag: boarded by %1 (%2 free seats), role %3", _boardedBy, count _freeSeats, assignedVehicleRole player];
    };

    player attachTo [_aircraft, BR_var_rideAlongOffset];
    player switchCamera "EXTERNAL";
    diag_log format ["BR flight diag: no seat (%1 free of %2) - attached below the aircraft", count _freeSeats, count fullCrew [_aircraft, "", true]];
};

// the seat lock of the player's crew entry, "-" without one
BR_fnc_flightDiagSeatLock = {
    params ["_vehicle", "_entry"];

    if (_entry isEqualTo []) exitWith {"-"};

    _entry params ["", "", "_cargoIndex", "_turretPath"];

    if (_turretPath isNotEqualTo []) exitWith {_vehicle lockedTurret _turretPath};

    if (_cargoIndex >= 0) exitWith {_vehicle lockedCargo _cargoIndex};

    "-"
};

/*
    Scheduled, while aboard: the flight view's state to the client RPT ("BR flight diag"; why the mouse did not turn
    the camera). The camera's heading relative to the aircraft changes between samples when the mouse turns it.
*/
BR_fnc_flightDiagLoop = {
    while {player getVariable ["BR_var_aboard", false]} do {
        private _vehicle = vehicle player;
        private _entry = ((fullCrew [_vehicle, "", true]) select {(_x select 0) isEqualTo player}) param [0, []];
        private _cameraFrom = positionCameraToWorld [0, 0, 0];
        private _cameraHeading = (_cameraFrom getDir (positionCameraToWorld [0, 0, 1])) - (getDir BR_var_aircraft);

        diag_log format [
        "BR flight diag: t %1 | vehicle %2 %3, is aircraft %4 | role %5 | crew entry %6 | cameraView %7, cameraOn %8 %9, camera heading to aircraft %10, camera distance %11 | simulation %12, hidden %13, attachedTo %14 | userInputDisabled %15, dialog %16, displays %17 | locked %18, seat locked %19 | gps %20, panel left %21, right %22 | anim %23, lifeState %24",
        round time, typeOf _vehicle, _vehicle, _vehicle isEqualTo BR_var_aircraft, assignedVehicleRole player,
            if(_entry isEqualTo []) then {"none"} else {_entry select [1, 6]},
        cameraView, typeOf cameraOn, cameraOn, round ((_cameraHeading + 360) mod 360), round (_cameraFrom distance BR_var_aircraft),
        simulationEnabled player, isObjectHidden player, attachedTo player,
        userInputDisabled, dialog, allDisplays apply {ctrlIDD _x},
        locked _vehicle, [_vehicle, _entry] call BR_fnc_flightDiagSeatLock,
        visibleGPS, infoPanel "left", infoPanel "right",
        animationState player, lifeState player
        ];

        sleep BR_var_flightDiagInterval;
    };
};

// the player's own view again; the GPS stays open in the right panel (from now on the GPS key switches it off and on)
BR_fnc_endFlightView = {
    player switchCamera CMN_var_lastView;
    call BR_fnc_showGpsRight;
};

// space, the team's first jumper (teamJump) or the forced jump: out of the aircraft, behind its tail (BR_fnc_jumpPosition)
BR_fnc_jumpClient = {
    if (!(player getVariable ["BR_var_aboard", false]) || {!alive player}) exitWith {};

    player setVariable ["BR_var_aboard", false, true];
    [] spawn BR_fnc_jumpOut;
};

// scheduled: out of the seat (takes effect when the server answered: a position set before is lost), then the jump
BR_fnc_jumpOut = {
    if (!isNull objectParent player) then {
        unassignVehicle player;
        moveOut player;
        [false] call BR_fnc_waitSeated;
    };

    detach player;
    [player, [] call BR_fnc_jumpPosition] call BR_fnc_unparkUnit;
    call BR_fnc_endFlightView;
    call CMN_fnc_startCameraViewLoop;
    [player] call BR_fnc_startFreefall;
    [player] remoteExecCall ["BR_fnc_unitJumped", 2];

    // no damage until the landing (the parachute's opening jolt downed or killed some)
    [player, BR_var_freefallOpenHeight, {
        call CMN_fnc_restoreNightVision;
        [player, true] call ADG_fnc_allowDamage;

    }] spawn BR_fnc_watchFreefall;
};
