// Cleanup: despawn times and dropped weapon holders (server).

// ---- cleanup ----

SC_var_despawnTimeRecoveryFactor = 4;

// despawn countdown (seconds) of an object: refilled while a unit (of _side, sideUnknown: any) is closer than
// _minDistance, drained otherwise by the seconds since its last update, faster by the distance beyond _minDistance;
// also the side ownership timer of vehicles. _timerVar: the object variable of the timer, the time of its last update
// is kept next to it.
SC_fnc_getNewDespawnTime = {
    params ["_object", "_timeRemaining", "_maxTime", "_minDistance", "_searchFactor", ["_depletionFactor", 1], ["_side", sideUnknown], ["_timerVar", "SC_var_timeRemaining"]];

    private _updatedVar = _timerVar + "Updated";
    private _elapsed = time - (_object getVariable [_updatedVar, time]);
    _object setVariable [_updatedVar, time];

    private _distanceNearest = [_object, ["CAManBase"], _searchFactor * _minDistance, _side] call SC_fnc_distanceOfNearestObject;

    if (_distanceNearest < _minDistance) then {
        _maxTime min (_timeRemaining + (SC_var_despawnTimeRecoveryFactor * (_minDistance - _distanceNearest)))
    } else {
        0 max (_timeRemaining - (_depletionFactor * ((_distanceNearest - _minDistance) max _elapsed)))
    }
};

// pauses a despawn countdown (SC_fnc_getNewDespawnTime) while it isn't updated, e.g. a vehicle in use: the next update
// drains nothing for the time of the pause
SC_fnc_pauseDespawnTime = {
    params ["_object", ["_timerVar", "SC_var_timeRemaining"]];

    _object setVariable [(_timerVar + "Updated"), nil];
};

SC_fnc_distanceOfNearestObject = {
    params ["_object", "_types", "_distance", ["_side", sideUnknown]];

    private _nearestObjects = nearestObjects [_object, _types, _distance, false];
    private _pos = _nearestObjects findIf {
        (alive _x) &&
        {(_x isNotEqualTo _object)} &&
        {((objectParent _x) isNotEqualTo _object)} &&
        {(_side == sideUnknown) || {(side (group _x)) == _side}}
    };

    (if (_pos == -1) then {_distance} else {(_nearestObjects select _pos) distance _object})
};

SC_fnc_put = {
    params ["", "_container"];

    if ((typeOf _container) isEqualTo "GroundWeaponHolder") then {
        [_container] remoteExecCall ["SC_fnc_addGroundWeaponHolder", 2];
    };
};

SC_fnc_addGroundWeaponHolder = {
    params ["_container"];

    _container setVariable ["SC_var_timeRemaining", SC_var_unitDespawnTime];
    SC_var_groundWeaponHolders pushBack _container;

    _container addEventHandler ["Deleted", {
        params ["_container"];

        private _idx = SC_var_groundWeaponHolders find _container;

        if (_idx != -1) then {
            SC_var_groundWeaponHolders deleteAt _idx;
        };
    }];
};

SC_fnc_weaponHolderLoop = {
    waitUntil {
        // copy: SC_var_GroundWeaponHolders shrinks while iterating (Deleted event handler)
        private _weaponHolders = (entities "WeaponHolderSimulated") + SC_var_groundWeaponHolders;
        private _sleepTime = 10 / (1 max (count _weaponHolders));

        {
            private _startTime = time;

            if !(isNull _x) then {
                private _timeRemaining = [
                    _x,
                    (_x getVariable ["SC_var_timeRemaining", SC_var_unitDespawnTime]),
                    SC_var_unitDespawnTime,
                    SC_var_minDistanceFromUnitToDespawn,
                    3
                ] call SC_fnc_getNewDespawnTime;

                if (_timeRemaining <= 0) then {
                    [_x] remoteExecCall ["deleteVehicle", _x];
                } else {
                    _x setVariable ["SC_var_timeRemaining", _timeRemaining];
                };
            };

            sleep (0.2 max (_sleepTime - (time - _startTime)));
        } forEach _weaponHolders;

        false
    };
};
