// Play zone: units outside the zone and in enemy bases get a time-out (server).

// ---- play zone ----

SC_fnc_zoneLoop = {
    waitUntil {
        {
            private _side = _x;

            private _sleepTime = 1 /(1 max (SC_var_numUnitsWest + SC_var_numUnitsEast + SC_var_numUnitsGuer +
                SC_var_numUavAiUnitsWest + SC_var_numUavAiUnitsEast + SC_var_numUavAiUnitsGuer));

            {
                private _startTime = time;
                private _unit = if (!([_x] call SC_fnc_isUavAi) || {_x isEqualTo (driver (objectParent _x))}) then {_x} else {objNull};

                if !(isNull _unit) then {
                    if ((alive _x) && {!(_x getVariable ["SC_var_isWatched", false])}) then {
                        private _otherSides = SC_var_sides - [_side];
                        private _posWorldUnit = getPosWorld _unit;

                        {
                            private _base = "SC_var_" + (str _x) + "Base";

                            if (_posWorldUnit inArea _base) then {
                                [_unit, _base, true, 15] spawn SC_fnc_zoneTimeOut;
                            };
                        } forEach _otherSides;

                        if (!SC_var_wholeMap && {!(_posWorldUnit inArea "SC_var_playZone")}) then {
                            [_unit, "SC_var_playZone", false, 30] spawn SC_fnc_zoneTimeOut;
                        };
                    };
                };

                private _finalSleepTime = _sleepTime - (time - _startTime);

                if (_finalSleepTime > 0) then {
                    sleep _finalSleepTime;
                };
            } forEach (([_side] call SC_fnc_getSidesUnits) + ([_side] call SC_fnc_getSidesUavAiUnits));
        } forEach SC_var_sides;

        false
    };
};

SC_fnc_zoneTimeOut = {
    params ["_unit", "_marker", "_insideForbidden", "_tMax"];

    private _t = 0;
    private _running = true;
    _unit setVariable ["SC_var_isWatched", true];

    private _unitToNotify = if (isPlayer _unit) then {
        _unit
    } else {
        private _uavControl = [(objectParent _unit), "DRIVER", "GUNNER"] call SC_fnc_uavControl;

        if (isPlayer _uavControl) then {
            _uavControl
        } else {
            objNull
        }
    };

    if !(isNull _unitToNotify) then {
        private _text = if _insideForbidden then {"inEnemyBase"} else {"outsidePlayzone"};
        [_text] remoteExec ["BIS_fnc_showNotification", _unitToNotify];
    };

    while {_running && (alive _unit)} do {
        if (((getPosWorld _unit) inArea _marker) isEqualTo _insideForBidden) then {
            if (_t < _tMax) then {
                _t = _t + 1;
                sleep 1;
            } else {
                [_unit] call KF_fnc_tagZoneDamage;
                if ([_unit] call SC_fnc_isUavAi) then {
                    [objectParent _unit] call KF_fnc_tagZoneDamage;
                    (objectParent _unit) setDamage 1;
                } else {
                    _unit setDamage 1;
                };
                _running = false;
            };
        } else {
            if !(isNull _unitToNotify) then {
                ["backInPlayzone"] remoteExec ["BIS_fnc_showNotification", _unitToNotify];
            };

            _running = false;
        };
    };

    _unit setVariable ["SC_var_isWatched", false];
};
