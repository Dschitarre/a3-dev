// Battle Royale safe zone (server and client). The server runs the phases and the damage outside; per phase it publishes
// BR_var_zone once: [phase, phaseCount, fromCenter, fromRadius, toCenter, toRadius, shrinkStart, shrinkEnd, damage].
// The circle stays at "from" until shrinkStart (serverTime), shrinks to "to" until shrinkEnd; clients interpolate.

// The phases follow from the play area radius (BR_fnc_zonePhases), so every area size gets a fitting number of phases.
BR_var_zoneRadiusShares = [[1000, 0.55], [300, 0.5], [0, 0.45]];   // [radius above, next radius share]
BR_var_zoneLastRadius = 60;             // a zone that would get smaller than this is the last one: it closes completely
// The pace rises with the match: every zone shrinks at one steady edge speed, from the first shrink to the last rising
// from the first to the second value, and the waits get shorter. At Normal: whole Altis ~50 min, Chernarus ~37 min,
// Stratis ~20 min.
BR_var_zoneEdgeSpeedRange = [7, 10];    // m/s of the far edge (with the center's travel): first shrink ... last
BR_var_zoneWaitRange = [120, 45];       // s before a shrink: first shrink ... last
// damage per second outside (share of the health) by the phase's place in the match, not by the radius: the first
// phase min, the last max, in between rising with (phase share) ^ exponent - a small area starts as gently as a big one
BR_var_zoneDamageMax = 0.1;
BR_var_zoneDamageMin = 0.0015;          // (11 min outside in the first phase)
BR_var_zoneDamageExponent = 2.5;
BR_var_zoneCenterTries = 100;          // random nested centers containing the chosen endpoint, then a geometric fallback
BR_var_zoneFirstDelayShare = 0.5;       // the first phase also waits for this share of the flight ...
BR_var_zoneLandingTime = 60;            // ... plus the time to land
BR_var_zoneDamageInterval = 1;
BR_var_zoneSparedHitPoints = ["hitLegs", "hitHands", "hitArms"];   // zone damage leaves the limbs alone
BR_var_zoneEdgeSteps = 10;              // samples along a shrink when the AI asks when the edge reaches a position

// ---- server ----

// [[wait s, shrink s, next radius, edge speed m/s, damage per second outside], ...] from _radius down to a closed zone
BR_fnc_zonePhases = {
    params ["_radius"];

    private _radii = [];
    private _current = _radius;

    while {_current > 0} do {
        private _shareIndex = BR_var_zoneRadiusShares findIf {_current > (_x select 0)};
        private _next = _current * ((BR_var_zoneRadiusShares select (0 max _shareIndex)) select 1);

        if (_next < BR_var_zoneLastRadius) then {
            _next = 0;
        };

        _radii pushBack [_current, _next];
        _current = _next;
    };

    // wait and edge speed by the shrink's place in the match (BR_var_zoneWaitRange, BR_var_zoneEdgeSpeedRange)
    private _lastShrink = (count _radii - 1) max 1;
    private _phases = [];

    {
        _x params ["_from", "_to"];

        private _share = _forEachIndex / _lastShrink;
        private _edgeSpeed = linearConversion [0, 1, _share, BR_var_zoneEdgeSpeedRange select 0, BR_var_zoneEdgeSpeedRange select 1, true];

        _phases pushBack [linearConversion [0, 1, _share, BR_var_zoneWaitRange select 0, BR_var_zoneWaitRange select 1, true],
            (_from - _to) / _edgeSpeed, _to, _edgeSpeed];
    } forEach _radii;

    // zone 1 is the whole play area (all land of the map): it ends when everyone has landed
    // (BR_fnc_zoneLoop: share of the flight + landing time), only then the first smaller circle is marked - nobody
    // (AI drop planning included) knows it during the flight
    _phases = [[0, 0, _radius, 1]] + _phases;

    // the damage of each phase from its place in the match
    private _lastIndex = (count _phases - 1) max 1;

    {
        _x pushBack (BR_var_zoneDamageMin +(BR_var_zoneDamageMax - BR_var_zoneDamageMin) *(_forEachIndex /
            _lastIndex) ^ BR_var_zoneDamageExponent);
    } forEach _phases;

    _phases
};

// Rejection sampling preserves equal probability per square metre of land on the map (the play area encloses all of it).
// Never choose a new endpoint to make a later circle easier to place: doing so would bias the coast again.
BR_fnc_zoneEndPoint = {
    private _point = [];
    while {_point isEqualTo []} do {
        private _candidate = [random worldSize, random worldSize, 0];
        if (!surfaceIsWater _candidate) then {
            _point = _candidate;
        };
    };
    [_point] call BR_fnc_groundPos
};

// The next circle stays inside its parent and contains the endpoint. Randomness hides the final point until late.
BR_fnc_zoneNextCenter = {
    params ["_center", "_radius", "_nextRadius", "_endPoint"];
    if (_nextRadius <= 0) exitWith {+_endPoint};
    private _travel = 0 max (_radius - _nextRadius);
    private _result = [];
    for "_i" from 1 to BR_var_zoneCenterTries do {
        private _candidate = if (_travel < _nextRadius) then {
            [_center, _travel] call BR_fnc_randomPosInCircle
        } else {[_endPoint, _nextRadius] call BR_fnc_randomPosInCircle};
        if (_candidate distance2D _center <= _travel && {_candidate distance2D _endPoint <= _nextRadius}) exitWith {
            _result = _candidate;
        };
    };
    if (_result isEqualTo []) then {
        _result = _center vectorAdd ((_endPoint vectorDiff _center) vectorMultiply (_travel / (_radius max 1)));
        _result = [_result] call BR_fnc_groundPos;
    };
    _result
};

// At flight start select the final land point once, then announce only the first circle for map and drop planning.
BR_fnc_planFirstZone = {
    BR_var_zoneEndPoint = call BR_fnc_zoneEndPoint;
    // the play area encloses all land (BR_fnc_wholeMapArea, sampled): land between its samples may still lie outside
    if (BR_var_zoneEndPoint distance2D BR_var_playAreaCenter > BR_var_playAreaRadius) then {
        BR_var_playAreaRadius = 1 + (BR_var_zoneEndPoint distance2D BR_var_playAreaCenter);
        call BR_fnc_applyAreaScale;
        call BR_fnc_initZoneServer;
    };
    private _nextRadius = (BR_var_zonePhases select 0) select 2;
    BR_var_firstZone =[[BR_var_playAreaCenter, BR_var_playAreaRadius, _nextRadius,
        BR_var_zoneEndPoint] call BR_fnc_zoneNextCenter, _nextRadius];
};

// phase 0: the whole play area, nothing shrinks yet
BR_fnc_initZoneServer = {
    BR_var_zone = [
        0,
        count BR_var_zonePhases,
        BR_var_playAreaCenter,
        BR_var_playAreaRadius,
        BR_var_playAreaCenter,
        BR_var_playAreaRadius,
        1e9,
        1e9,
        0
    ];
    publicVariable "BR_var_zone";
};

// scheduled, from the flight on: one published state per phase, supply drops with some phases (BR\airdrops.sqf)
BR_fnc_zoneLoop = {
    private _center = BR_var_playAreaCenter;
    private _radius = BR_var_playAreaRadius;
    private _waitStart = serverTime + BR_var_flightDuration * BR_var_zoneFirstDelayShare + BR_var_zoneLandingTime;

    {
        _x params ["_waitTime", "_shrinkTime", "_nextRadius", "_edgeSpeed", "_damage"];

        private _phase = _forEachIndex + 1;
        private _nextCenter = if (_phase == 1) then {BR_var_firstZone select 0} else {
            [_center, _radius, _nextRadius, BR_var_zoneEndPoint] call BR_fnc_zoneNextCenter
        };
        private _shrinkStart = _waitStart + _waitTime * BR_var_zoneTimeFactor;
        // the far edge moves at the phase's speed, the center's travel included (coastal endings: no faster wall)
        private _duration = _shrinkTime max ((_radius - _nextRadius + (_center distance2D _nextCenter)) / _edgeSpeed);
        private _shrinkEnd = _shrinkStart + _duration * BR_var_zoneTimeFactor;

        BR_var_zone = [_phase, count BR_var_zonePhases, _center, _radius, _nextCenter, _nextRadius, _shrinkStart, _shrinkEnd, _damage];
        publicVariable "BR_var_zone";

        // the next zone is shown from the first shrink on (BR_fnc_nextZoneShown)
        if (!isNil "BR_var_zoneRevealed") then {
            // phase 1 is the whole play area: the circles count from phase 2 (as on the HUD)
            ["brZone", [format ["Zone %1 marked on the map", _phase - 1]]] call BR_fnc_notifyAll;
        };

        if (BR_var_airdropsEnabled && {[_phase, count BR_var_zonePhases] call BR_fnc_isAirdropPhase}) then {
            [] spawn BR_fnc_airdrop;
        };

        waitUntil {
            sleep 1;
            serverTime >= _shrinkStart || {BR_var_state == "ended"}
        };

        if (_nextRadius < _radius) then {
            if (isNil "BR_var_zoneRevealed") then {
                BR_var_zoneRevealed = true;
                publicVariable "BR_var_zoneRevealed";
            };

            ["brZone", ["Zone shrinking"]] call BR_fnc_notifyAll;
        };

        waitUntil {
            sleep 1;
            serverTime >= _shrinkEnd || {BR_var_state == "ended"}
        };

        if (BR_var_state == "ended") exitWith {};

        _center = _nextCenter;
        _radius = _nextRadius;
        _waitStart = serverTime;
    } forEach BR_var_zonePhases;
};

// scheduled: combatants on the ground (or falling) outside of the current circle lose health every second
BR_fnc_zoneDamageLoop = {
    waitUntil {
        sleep BR_var_zoneDamageInterval;

        private _damage = (BR_var_zone select 8) * BR_var_zoneDamageInterval;

        if (_damage > 0) then {
            ([] call BR_fnc_zoneCurrent) params ["_center", "_radius"];

            {
                if (alive _x && {simulationEnabled _x} && {_x distance2D _center > _radius}) then {
                    if (local _x) then {
                        [_x, _damage] call BR_fnc_applyZoneDamage;
                    } else {
                        [_x, _damage] remoteExecCall ["BR_fnc_applyZoneDamage", _x];
                    };
                };
            } forEach BR_var_rosterUnits;
        };

        BR_var_state == "ended"
    };
};

/*
    Where the unit is local (setHitPointDamage needs that). setDamage sets every hit point as well: limbs keep their
    damage, otherwise half the health in the zone would make the unit limp and it could not get out anymore.
*/
BR_fnc_applyZoneDamage = {
    params ["_unit", "_damage"];

    private _newDamage = (damage _unit) + _damage;
    [_unit,
        _newDamage >=(if(!isNil "AIS_var_initDone" &&
        {!(_unit getVariable ["ais_unconscious",
        false])}) then {BR_var_downedDamage} else {1})] call KF_fnc_tagZoneDamage;
    private _knockDown = false;

    // team modes (BR\downed.sqf): a downed unit dies (AIS gives the gear it took back first), a standing one goes down
    if (!isNil "AIS_var_initDone") then {
        if (_unit getVariable ["ais_unconscious", false]) then {
            if (_newDamage >= 1) then {
                [_unit, objNull, objNull] call AIS_Damage_fnc_goToDead;
            };
        } else {
            if (_newDamage >= BR_var_downedDamage) then {
                _newDamage = BR_var_downedDamage;
                _knockDown = true;
            };
        };
    };

    private _limbDamage = BR_var_zoneSparedHitPoints apply {_unit getHitPointDamage _x};

    _unit setDamage _newDamage;

    if (alive _unit) then {
        {
            _unit setHitPointDamage [_x, _limbDamage select _forEachIndex];
        } forEach BR_var_zoneSparedHitPoints;
    };

    if (_knockDown) then {
        [_unit] call BR_fnc_knockDown;
    };
};

// serverTime at which the circle of the current phase stops covering _pos (1e9: never in this phase)
BR_fnc_zoneEdgeTime = {
    params ["_pos"];

    BR_var_zone params ["", "", "_fromCenter", "_fromRadius", "_toCenter", "_toRadius", "_shrinkStart", "_shrinkEnd"];

    if (_pos distance2D _toCenter <= _toRadius) exitWith {1e9};
    if (_pos distance2D _fromCenter > _fromRadius) exitWith {serverTime};

    // the gap between edge and position shrinks steadily, so the first sample outside is the crossing (to a step)
    private _ratio = 1;

    for "_i" from 1 to BR_var_zoneEdgeSteps do {
        private _stepRatio = _i / BR_var_zoneEdgeSteps;
        private _stepCenter = _fromCenter vectorAdd ((_toCenter vectorDiff _fromCenter) vectorMultiply _stepRatio);

        if (_pos distance2D _stepCenter > _fromRadius + (_toRadius - _fromRadius) * _stepRatio) exitWith {
            _ratio = _stepRatio;
        };
    };

    _shrinkStart + (_shrinkEnd - _shrinkStart) * _ratio
};

// ---- server and client ----

// [center, radius] of the circle at _time (serverTime)
/*
    Clients: the next safe zone (white circle, its 3D wall, the distance line) only from the first shrink on - before
    it the whole map is the zone. BR_var_zoneRevealed (server,
    BR_fnc_zoneLoop) is public, so a JIP client gets it too.
*/
BR_fnc_nextZoneShown = {
    !isNil "BR_var_zoneRevealed"
};

BR_fnc_zoneCurrent = {
    params [["_time", serverTime]];

    BR_var_zone params ["", "", "_fromCenter", "_fromRadius", "_toCenter", "_toRadius", "_shrinkStart", "_shrinkEnd"];

    private _ratio = (0 max ((_time - _shrinkStart) / (1 max (_shrinkEnd - _shrinkStart)))) min 1;

    [
        _fromCenter vectorAdd ((_toCenter vectorDiff _fromCenter) vectorMultiply _ratio),
        _fromRadius + (_toRadius - _fromRadius) * _ratio
    ]
};
