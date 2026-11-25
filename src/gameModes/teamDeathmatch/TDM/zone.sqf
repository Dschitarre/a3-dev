// Team Deathmatch play zone (server and client): shrinking zone and damage outside of it.

DM_fnc_resetPlayZone = {
    "DM_mrk_playZone" setMarkerSize DM_var_zoneStartSize;
    "DM_mrk_playZone" setMarkerPos DM_var_zoneStartPos;
};

// linear interpolation of the first two components (marker size and position)
DM_fnc_lerp2D = {
    params ["_from", "_to", "_ratio"];

    [
        (_from select 0) + ((_to select 0) - (_from select 0)) * _ratio,
        (_from select 1) + ((_to select 1) - (_from select 1)) * _ratio
    ]
};

// shrinks the zone in steps towards random points; the server sees the marker every frame, clients a few times per second
DM_fnc_zoneShrink = {
    private _totalDuration = ceil (60 * DM_var_zoneSizeFactor * DM_var_zoneShrinkSpeed);

    // with a round time limit the HUD timer shows that instead
    if (DM_var_roundTimeLimit == 0) then {
        DM_var_timerHdl = [_totalDuration] spawn DM_fnc_timer;
    };

    private _remainingDuration = _totalDuration;
    private _lastPos = DM_var_zoneStartPos;
    private _lastSize = DM_var_zoneStartSize;

    while {_remainingDuration > 0} do {
        private _stepDuration = (1 / 48) max (DM_var_zoneShrinkRatio * _remainingDuration);
        _remainingDuration = _remainingDuration - _stepDuration;

        private _targetArea = ((markerSize "DM_mrk_playZone") apply {_x * DM_var_zoneShrinkRatio}) +
            [markerDir "DM_mrk_playZone", markerShape "DM_mrk_playZone" == "RECTANGLE"];
        private _targetPos = ["DM_mrk_playZone", _targetArea] call BIS_fnc_randomPosTrigger;
        private _targetSize = _lastSize apply {_x * (1 - DM_var_zoneShrinkRatio)};

        private _startTime = time;
        private _nextBroadcast = 0;

        waitUntil {
            private _ratio = ((time - _startTime) / _stepDuration) min 1;
            private _size = [_lastSize, _targetSize, _ratio] call DM_fnc_lerp2D;
            private _pos = [_lastPos, _targetPos, _ratio] call DM_fnc_lerp2D;

            if (_ratio >= 1 || {time >= _nextBroadcast}) then {
                "DM_mrk_playZone" setMarkerSize _size;
                "DM_mrk_playZone" setMarkerPos _pos;
                _nextBroadcast = time + DM_var_zoneBroadcastInterval;
            } else {
                "DM_mrk_playZone" setMarkerSizeLocal _size;
                "DM_mrk_playZone" setMarkerPosLocal _pos;
            };

            _ratio >= 1
        };

        _lastPos = _targetPos;
        _lastSize = _targetSize;
    };
};

// damages simulated units outside of the zone while a round is running (DM_var_zoneDamage once per second per unit)
DM_fnc_playZoneLoop = {
    waitUntil {
        if (DM_var_gameRunning) then {
            private _leavers = (entities [["CAManBase"], [], true, true]) select {
                simulationEnabled _x &&
                {!isPlayer _x || {!(_x getVariable ["CMN_var_isLoading", true])}} &&
                {!(getPosWorld _x inArea "DM_mrk_playZone")} &&
                {!(_x in DM_var_watchedUnits)}
            };

            {
                DM_var_watchedUnits pushBack _x;
                [_x] spawn DM_fnc_damageOutsideZone;
            } forEach _leavers;
        };

        sleep DM_var_playZonePollInterval;
        false
    };
};

DM_fnc_damageOutsideZone = {
    params ["_unit"];

    if (isPlayer _unit) then {
        ["outsidePlayzone"] remoteExecCall ["BIS_fnc_showNotification", _unit];
    };

    // stops at the round end and for parked units (pool AI, spectators), which wait outside of the zone
    while {alive _unit && {DM_var_gameRunning} && {simulationEnabled _unit}} do {
        if (getPosWorld _unit inArea "DM_mrk_playZone") exitWith {
            if (isPlayer _unit) then {
                ["backInPlayzone"] remoteExecCall ["BIS_fnc_showNotification", _unit];
            };

            sleep 1;
        };

        [_unit, damage _unit + DM_var_zoneDamage >= 1] call KF_fnc_tagZoneDamage;
        [_unit, DM_var_zoneDamage] call AH_fnc_changeDamage;
        sleep 1;
    };

    DM_var_watchedUnits deleteAt (DM_var_watchedUnits find _unit);
};
