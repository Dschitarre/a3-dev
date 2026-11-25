// Dynamic weather (server): weather transitions (overcast, rain, fog, wind) over time.
// Included by fnc_server.sqf.

// ---- weather ----

DW_var_weatherTolerance = 0.02;   // deviation of the engine's overcast / rain from the target that is corrected

DW_fnc_executeWeather = {
    params ["_time"];

    (_time * timeMultiplier) setOvercast DW_var_currentOvercast;
    _time setRain DW_var_currentRain;
    (_time * timeMultiplier) setFog DW_var_currentFog;
    setWind ((DW_var_currentWind select [0, 2]) + [true]);
};

// applies the target weather when it changed or the engine's weather has not reached it (yet)
DW_fnc_executeWeatherLoop = {
    private _applied = [];

    waitUntil {
        private _weather = [DW_var_currentOvercast, DW_var_currentRain, DW_var_currentFog, DW_var_currentWind];

        if (
            _weather isNotEqualTo _applied ||
            {abs (overcast - DW_var_currentOvercast) > DW_var_weatherTolerance} ||
            {abs (rain - DW_var_currentRain) > DW_var_weatherTolerance}
        ) then {
            [1] call DW_fnc_executeWeather;
            _applied = _weather;
        };

        sleep 1;
        false
    };
};

DW_fnc_windFactor = {
    params ["_wind"];

    vectorMagnitude _wind / vectorMagnitude [10, 10, 0]
};

// a random factor in the other half of [0, 1] than the old one, so the weather changes noticeably
DW_fnc_randomDifferentFactor = {
    params ["_oldFactor"];

    random 0.5 + ([0, 0.5] select (_oldFactor <= 0.5))
};

DW_fnc_restrictedRandomDifferentFactor = {
    params ["_oldFactor", "_min", "_max"];

    private _diff = _max - _min;

    if (_diff <= 0) exitWith {_min};

    _min + _diff * ([(_oldFactor - _min) / _diff] call DW_fnc_randomDifferentFactor)
};

DW_fnc_ratioInRange = {
    params ["_value", "_rangeMin", "_rangeMax"];

    if (_rangeMax - _rangeMin <= 0) exitWith {0};

    (_value - _rangeMin) / (_rangeMax - _rangeMin)
};

DW_fnc_ratioIntoRange = {
    params ["_ratio", "_rangeMin", "_rangeMax"];

    if (_rangeMax - _rangeMin <= 0) exitWith {_rangeMin};

    _rangeMin + _ratio * (_rangeMax - _rangeMin)
};

DW_fnc_randomInRange = {
    params ["_min", "_max"];

    _min + random (_max - _min)
};

// a new value (fog or wind) in the sunny or the stormy range of the new overcast, clearly different from the last one
DW_fnc_randomForOvercast = {
    params ["_lastOvercast", "_newOvercast", "_lastValue", "_sunnyRange", "_stormyRange"];

    private _lastRange = [_stormyRange, _sunnyRange] select (_lastOvercast < DW_var_minOvercastForRain);
    private _newRange = [_stormyRange, _sunnyRange] select (_newOvercast < DW_var_minOvercastForRain);
    private _newFactor = [([_lastValue] + _lastRange) call DW_fnc_ratioInRange] call DW_fnc_randomDifferentFactor;

    ([_newFactor] + _newRange) call DW_fnc_ratioIntoRange
};

DW_fnc_fogRanges = {
    [[DW_var_minFogSunny, DW_var_maxFogSunny], [DW_var_minFogStormy, DW_var_maxFogStormy]]
};

DW_fnc_windRanges = {
    [[DW_var_minWindSunny, DW_var_maxWindSunny], [DW_var_minWindStormy, DW_var_maxWindStormy]]
};

DW_fnc_staticPhaseDuration = {
    params ["_diffOvercast"];

    private _multiplier =[DW_var_timeBetweenWeatherChangesMultiplierStormy,
        DW_var_timeBetweenWeatherChangesMultiplierSunny] select (overcast < DW_var_minOvercastForRain);

    (_multiplier * 1000 * abs _diffOvercast) max 1
};

DW_fnc_weatherChangeDuration = {
    params ["_diffOvercast"];

    (20000 * abs _diffOvercast / timeMultiplier) max 1
};

DW_fnc_setWeather = {
    params ["_overcast", "_rain", "_fog", "_wind"];

    DW_var_currentOvercast = _overcast;
    DW_var_currentRain = _rain;
    DW_var_currentFog = _fog;
    DW_var_currentWind = _wind;
};

DW_fnc_nextRandomWeather = {
    DW_var_currentWeatherChange params ["_lastOvercast", "_lastRain", "_lastFog", "_lastWind"];

    private _newOvercast = [_lastOvercast, DW_var_minOvercast, DW_var_maxOvercast] call DW_fnc_restrictedRandomDifferentFactor;
    private _newRain = if (_newOvercast >= DW_var_minOvercastForRain) then {
        [_lastRain, DW_var_minRain, DW_var_maxRain] call DW_fnc_restrictedRandomDifferentFactor
    } else {
        _lastRain
    };

    private _newFog = ([_lastOvercast, _newOvercast, _lastFog] + call DW_fnc_fogRanges) call DW_fnc_randomForOvercast;
    private _newWind = ([_lastOvercast, _newOvercast, _lastWind] + call DW_fnc_windRanges) call DW_fnc_randomForOvercast;

    DW_var_lastWeatherChange = DW_var_currentWeatherChange;
    DW_var_currentWeatherChange = [_newOvercast, _newRain, _newFog, _newWind];
};

DW_fnc_newRandomWeather = {
    private _lastOvercast = [DW_var_minOvercast, DW_var_maxOvercast] call DW_fnc_randomInRange;
    private _newOvercast = [_lastOvercast, DW_var_minOvercast, DW_var_maxOvercast] call DW_fnc_restrictedRandomDifferentFactor;
    private _newRain = [DW_var_minRain, DW_var_maxRain] call DW_fnc_randomInRange;
    private _isStormy = _lastOvercast >= DW_var_minOvercastForRain;
    private _lastFog = ((call DW_fnc_fogRanges) select _isStormy) call DW_fnc_randomInRange;
    private _lastWind = ((call DW_fnc_windRanges) select _isStormy) call DW_fnc_randomInRange;
    private _newFog = ([_lastOvercast, _newOvercast, _lastFog] + call DW_fnc_fogRanges) call DW_fnc_randomForOvercast;
    private _newWind = ([_lastOvercast, _newOvercast, _lastWind] + call DW_fnc_windRanges) call DW_fnc_randomForOvercast;

    DW_var_currentWeatherChange = [_newOvercast, _newRain, _newFog, _newWind];
    call DW_fnc_nextRandomWeather;
};

DW_fnc_calculateRain = {
    params ["_currentOvercast", "_oldRain", "_targetRain", "_oldOvercast", "_targetOvercast", "_changeWeather", "_forceStart"];

    // static phase: follow the clients' rain
    private _avgRain = if (_changeWeather) then {-1} else {["RAIN"] call DW_fnc_averageClientsWeather};

    if (_avgRain != -1) exitWith {_avgRain};

    // clearing up: the rain fades out together with the overcast
    if (_oldOvercast > DW_var_minOvercastForRain && {_targetOvercast <= DW_var_minOvercastForRain}) exitWith {
        if (_currentOvercast >= DW_var_minOvercastForRain) then {
            ((_currentOvercast - DW_var_minOvercastForRain) / (_oldOvercast - DW_var_minOvercastForRain)) * _oldRain
        } else {
            0
        }
    };

    private _avgOvercast = ["OVERCAST"] call DW_fnc_averageClientsWeather;

    if (_forceStart || {_avgOvercast == -1}) then {
        _avgOvercast = _currentOvercast;
    };

    if (_avgOvercast < DW_var_minOvercastForRain) exitWith {0};

    ((_avgOvercast - DW_var_minOvercastForRain) / (1 - DW_var_minOvercastForRain)) * _targetRain
};

// blends the current weather towards the target weather in _steps steps of one second
DW_fnc_changeLoop = {
    params ["_steps", "_targetWeather", "_changeWeather"];
    _targetWeather params ["_targetOvercast", "_targetRain", "_targetFog", "_targetWind"];

    private _currentTimeMultiplier = timeMultiplier;
    private _oldOvercast = DW_var_currentOvercast;
    private _oldRain = DW_var_currentRain;
    private _oldFog = DW_var_currentFog;
    private _oldWind = DW_var_currentWind;
    private _oldWindFactor = [_oldWind] call DW_fnc_windFactor;
    private _oldWindAngle = [0, 0, 0] getDir _oldWind;
    private _diffOvercast = _targetOvercast - _oldOvercast;
    private _diffFog = _targetFog - _oldFog;
    private _diffWind = _targetWind - _oldWindFactor;
    private _diffWindAngle = if (_changeWeather) then {random 360 - 180} else {0};
    private _i = 0;

    waitUntil {
        _i = _i + 1;

        private _factor = _i / _steps;
        private _overcast = _oldOvercast + _diffOvercast * _factor;
        private _rain =[_overcast, _oldRain, _targetRain, _oldOvercast, _targetOvercast, _changeWeather,
            _steps == 1] call DW_fnc_calculateRain;
        private _fog = _oldFog + _diffFog * _factor;
        private _wind = _oldWind;

        if (_changeWeather) then {
            private _windVector = ([10, 10, 0] vectorMultiply (_oldWindFactor + _diffWind * _factor)) select [0, 2];
            _wind = ([_windVector, _oldWindAngle + _diffWindAngle * _factor] call BIS_fnc_rotateVector2D) + [0];
        };

        [_overcast, _rain, _fog, _wind] call DW_fnc_setWeather;
        sleep 1;

        // the time multiplier changed (day / night): keep the remaining duration in game time
        if (timeMultiplier != _currentTimeMultiplier) then {
            _steps = ceil (_i + (_currentTimeMultiplier / timeMultiplier) * (_steps - _i));
            _currentTimeMultiplier = timeMultiplier;
        };

        _i >= _steps
    };
};

DW_fnc_runChangeLoop = {
    params ["_steps", "_targetWeather", "_changeWeather"];

    DW_var_weatherChangeInnerScript = _this spawn DW_fnc_changeLoop;

    waitUntil {
        sleep 1;
        scriptDone DW_var_weatherChangeInnerScript
    };
};

// change phase: blend to the new target weather, then towards the clients' overcast
DW_fnc_weatherChange = {
    DW_var_lastWeatherChange params ["_oldOvercast"];
    DW_var_currentWeatherChange params ["_targetOvercast", "_targetRain", "_targetFog", "_targetWind"];

    DW_var_isWeatherChanging = true;
    call DW_fnc_updateTimeMultiplier;

    [ceil ([_targetOvercast - _oldOvercast] call DW_fnc_weatherChangeDuration), DW_var_currentWeatherChange,
        true] call DW_fnc_runChangeLoop;

    private _avgOvercast = ["OVERCAST"] call DW_fnc_averageClientsWeather;
    private _finalOvercast = if (_avgOvercast != -1) then {_targetOvercast + 0.7 * (_avgOvercast - _targetOvercast)} else {_targetOvercast};

    [ceil ([_finalOvercast - _targetOvercast] call DW_fnc_weatherChangeDuration),
        [_finalOvercast, _targetRain, _targetFog, _targetWind], false] call DW_fnc_runChangeLoop;

    DW_var_isWeatherChanging = false;
    call DW_fnc_updateTimeMultiplier;
};

DW_fnc_dynamicWeather = {
    params [["_setDate", true]];

    DW_var_currentOvercast = overcast;
    DW_var_currentRain = rain;
    DW_var_currentFog = fog;
    DW_var_currentWind = wind;

    if (_setDate) then {
        setDate DW_var_date;
    };

    // day or night of the (new) date
    DW_var_isWeatherChanging = false;
    call DW_fnc_publishIsNight;
    call DW_fnc_updateTimeMultiplier;

    // random start weather, applied at once (short freeze)
    call DW_fnc_newRandomWeather;
    DW_var_weatherChangeInnerScript = [1, DW_var_currentWeatherChange, true] spawn DW_fnc_changeLoop;
    waitUntil {scriptDone DW_var_weatherChangeInnerScript};

    [0] call DW_fnc_executeWeather;
    forceWeatherChange;

    DW_var_executeWeatherScript = [] spawn DW_fnc_executeWeatherLoop;
    DW_var_monitorNightScript = [] spawn DW_fnc_monitorNight;

    if (DW_var_skipNight) then {
        DW_var_skipNightScript = [] spawn DW_fnc_skipNightLoop;
    };

    sleep ([0.5] call DW_fnc_staticPhaseDuration);

    waitUntil {
        call DW_fnc_nextRandomWeather;
        DW_var_weatherChangeScript = [] spawn DW_fnc_weatherChange;

        waitUntil {
            sleep 1;
            scriptDone DW_var_weatherChangeScript
        };

        sleep ([DW_var_currentOvercast - (DW_var_lastWeatherChange select 0)] call DW_fnc_staticPhaseDuration);
        false
    };
};

DW_fnc_startDynamicWeather = {
    params ["_setDate"];

    // the module, the global enabler and game modes may all call this; only one weather loop may run
    if (!scriptDone DW_var_weatherScript) exitWith {};

    [DW_var_weatherPreset] call DW_fnc_applyWeatherPreset;

    DW_var_weatherScript = [_setDate] spawn DW_fnc_dynamicWeather;
};

DW_fnc_stopDynamicWeather = {
    {
        private _script = missionNamespace getVariable [_x, scriptNull];

        if (!isNull _script) then {
            terminate _script;
        };

        missionNamespace setVariable [_x, scriptNull];
    } forEach [
        "DW_var_monitorNightScript",
        "DW_var_weatherScript",
        "DW_var_weatherChangeScript",
        "DW_var_weatherChangeInnerScript",
        "DW_var_skipNightScript",
        "DW_var_executeWeatherScript"
    ];

    // a stop during a weather change would leave the faster change time multiplier
    DW_var_isWeatherChanging = false;
    call DW_fnc_updateTimeMultiplier;
};
