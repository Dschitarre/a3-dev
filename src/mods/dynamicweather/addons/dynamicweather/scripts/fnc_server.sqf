DW_var_minOvercastForRain = 0.6;
DW_var_playersWeathers = [];
DW_var_lastWeatherChange = nil;
DW_var_currentWeatherChange = nil;
DW_var_weatherScript = scriptNull;
DW_var_weatherChangeScript = scriptNull;
DW_var_weatherChangeInnerScript = scriptNull;
DW_fnc_skipNightScript = scriptNull;
DW_fnc_executeWeatherScript = scriptNull;
DW_var_weatherScript = scriptNull;

DW_fnc_setDefaultSettings = {
    DW_var_minOvercast = 0;
    DW_var_maxOvercast = 1;
    DW_var_minFogSunny = 0;
    DW_var_maxFogSunny = 0;
    DW_var_minFogStormy = 0;
    DW_var_maxFogStormy = 0.1;
    DW_var_minRain = 0;
    DW_var_maxRain = 0.7;
    DW_var_minWindSunny = 0;
    DW_var_maxWindSunny = 0.3;
    DW_var_minWindStormy = 0.0;
    DW_var_maxWindStormy = 0.6;
    DW_var_changeTimeMultiplierDay = 15;
    DW_var_changeTimeMultiplierNight = 15;
    DW_var_staticTimeMultiplierDay = 1;
    DW_var_staticTimeMultiplierNight = 1;
    DW_var_isWeatherChanging = false;
    DW_var_timeBetweenWeatherChangesMultiplierSunny = 1;
    DW_var_timeBetweenWeatherChangesMultiplierStormy = 1;
    DW_var_date = [2035, 06, 30, 06, 00];
    DW_var_skipNight = true;
    DW_var_skipNightTime = [18, 00];
};

call DW_fnc_setDefaultSettings;

DW_fnc_isNight = {
    (dayTime < 3.75) || {dayTime > 20.25}
};

DW_fnc_updateTimeMultiplier = {
    setTimeMultiplier (if (call DW_fnc_isNight) then {
        if DW_var_isWeatherChanging then {
            DW_var_changeTimeMultiplierNight
        } else {
            DW_var_staticTimeMultiplierNight
        }
    } else {
         if DW_var_isWeatherChanging then {
            DW_var_changeTimeMultiplierDay
        } else {
            DW_var_staticTimeMultiplierDay
        }
    });
};

DW_fnc_timeArrToDayTime = {
    params ["_timeArr"];
    (_timeArr select 0) + (_timeArr select 1) / 60
};

DW_fnc_dayTimeToTimeArr = {
    params ["_dayTime"];
    _hour = floor _dayTime;
    [_hour, 60 * (_dayTime - _hour)]
};

DW_fnc_setPlayersWeather = {
    params ["_uid", "_weather"];

    _pos = DW_var_playersWeathers findIf {(_x select 0) == _uid};

    if (_pos == -1) then {
        DW_var_playersWeathers pushBack [_uid, _weather];
    } else {
        DW_var_playersWeathers set [_pos, [_uid, _weather]];
    };
};

DW_fnc_PlayerDisconnected = {
    params ["", "_uid"];

    _pos = DW_var_playersWeathers findIf {(_x select 0) == _uid};

    if (_pos != -1) then {
        DW_var_playersWeathers deleteAt _pos;
    };
};

DW_fnc_averageCleintsWeather = {
    params ["_type"];

    if (DW_var_playersWeathers isEqualTo []) then {-1} else {
        _type = (_type == "RAIN");
        _reference = [overcast, rain] select _type;
        _n = 0;
        _sum = 0;

        {
            _value = (_x select 1) select _type;
            
            if ((abs (_value - _reference)) <= 0.15) then {
                _sum = _sum + _value;
                _n = _n + 1;
            };
        } forEach DW_var_playersWeathers;

        if (_n > 0) then {
            _sum / _n
        } else {
            -1
        }
    }
};

DW_fnc_executeWeather = {
    params ["_time"];

    (_time * timeMultiplier) setOvercast DW_var_currentOvercast;
    _time setRain DW_var_currentRain;
    (_time * timeMultiplier) setFog DW_var_currentFog;
    setWind ((DW_var_currentWind select [0, 2]) + [true]);
};

DW_fnc_executeWeatherLoop = {
    waitUntil {
        [1] call DW_fnc_executeWeather;
        sleep 1;
        false
    };
};

DW_fnc_currentRainFactor = {
    (rain * (1 - DW_var_minOvercastForRain)) / (overcast - DW_var_minOvercastForRain)
};

DW_fnc_windFactor = {
    params ["_wind"];
    
    (vectorMagnitude _wind) / (vectorMagnitude [10, 10, 0])
};

DW_fnc_randomDifferentFactor = {
    params ["_oldFactor"];

    _rn = random 0.5;

    if (_oldFactor <= 0.5) then {
        _rn = _rn + 0.5;
    };

    _rn
};

DW_fnc_restrictedRandomDifferentFactor = {
    params ["_oldFactor", "_min", "_max"];

    _diff = _max - _min;
    
    if (_diff > 0) then {
        _min + (_diff * ([(_oldFactor - _min) / _diff] call DW_fnc_randomDifferentFactor))
    } else {
        _min
    }
};

DW_fnc_randomWind = {
    params ["_lastOvercast", "_newOvercast", "_lastWind"];

    _newFactor = [
        if (_lastOvercast < DW_var_minOvercastForRain) then {
            [_lastWind, DW_var_minWindSunny, DW_var_maxWindSunny] call DW_fnc_ratioInRange
        } else {
            [_lastWind, DW_var_minWindStormy, DW_var_maxWindStormy] call DW_fnc_ratioInRange
        }
    ] call DW_fnc_randomDifferentFactor;

    if (_newOvercast < DW_var_minOvercastForRain) then {
        [_newFactor, DW_var_minWindSunny, DW_var_maxWindSunny] call DW_fnc_ratioIntoRange
    } else {
        [_newFactor, DW_var_minWindStormy, DW_var_maxWindStormy] call DW_fnc_ratioIntoRange
    }
};

DW_fnc_ratioInRange = {
    params ["_value", "_rangeMin", "_rangeMax"];

    if ((_rangeMax - _rangeMin) > 0) then {
        (_value - _rangeMin) / (_rangeMax - _rangeMin)
    } else {
        0
    }
};

DW_fnc_ratioIntoRange = {
    params ["_ratio", "_rangeMin", "_rangeMax"];

    if ((_rangeMax - _rangeMin) > 0) then {
        _rangeMin + (_ratio * (_rangeMax - _rangeMin))
    } else {
        _rangeMin
    }
};

DW_fnc_randomFog = {
    params ["_lastOvercast", "_newOvercast", "_lastFog"];

    _newFactor = [
        if (_lastOvercast < DW_var_minOvercastForRain) then {
            [_lastFog, DW_var_minFogSunny, DW_var_maxFogSunny] call DW_fnc_ratioInRange
        } else {
            [_lastFog, DW_var_minFogStormy, DW_var_maxFogStormy] call DW_fnc_ratioInRange
        }
    ] call DW_fnc_randomDifferentFactor;

    if (_newOvercast < DW_var_minOvercastForRain) then {
        [_newFactor, DW_var_minFogSunny, DW_var_maxFogSunny] call DW_fnc_ratioIntoRange
    } else {
        [_newFactor, DW_var_minFogStormy, DW_var_maxFogStormy] call DW_fnc_ratioIntoRange
    }
};

DW_fnc_staticPhaseDuration = {
    params ["_diffOvercast"];

    _time = ([DW_var_timeBetweenWeatherChangesMultiplierStormy, DW_var_timeBetweenWeatherChangesMultiplierSunny] select (overcast < 0.5)) * (1000 * (abs _diffOvercast));

    if (_time < 1) then {
        _time = 1;
    };

    _time
};

DW_fnc_weatherChangeDuration = {
    params ["_diffOvercast"];

    _time = (20000 * (abs _diffOvercast)) / timeMultiplier;

    if (_time < 1) then {
        _time = 1;
    };

    _time
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

    _newOvercast = [_lastOvercast, DW_var_minOvercast, DW_var_maxOvercast] call DW_fnc_restrictedRandomDifferentFactor;
    _newRain = if (_newOvercast >= DW_var_minOvercastForRain) then {
        [_lastRain, DW_var_minRain, DW_var_maxRain] call DW_fnc_restrictedRandomDifferentFactor
    } else {
        _lastRain
    };
    
    _newFog = [_lastOvercast, _newOvercast, _lastFog] call DW_fnc_randomFog;
    _newWind = [_lastOvercast, _newOvercast, _lastWind] call DW_fnc_randomWind;

    DW_var_lastWeatherChange = DW_var_currentWeatherChange;
    DW_var_currentWeatherChange = [_newOvercast, _newRain, _newFog, _newWind];
};

DW_fnc_newRandomWeather = {
    _lastOvercast = DW_var_minOvercast + (random (DW_var_maxOvercast - DW_var_minOvercast));

    _newOvercast = [_lastOvercast, DW_var_minOvercast, DW_var_maxOvercast] call DW_fnc_restrictedRandomDifferentFactor;
    _newRain = DW_var_minRain + (random (DW_var_maxRain - DW_var_minRain));

    _newFog = [
        _lastOvercast,
        _newOvercast, (
            if (_lastOvercast < DW_var_minOvercastForRain) then {
                DW_var_minFogSunny + (random (DW_var_maxFogSunny - DW_var_minFogSunny))
            } else {
                DW_var_minFogStormy + (random (DW_var_maxFogStormy - DW_var_minFogStormy))
            }
        )
    ] call DW_fnc_randomFog;

    _newWind = [
        _lastOvercast,
        _newOvercast, (
            if (_lastOvercast < DW_var_minOvercastForRain) then {
                DW_var_minWindSunny + (random (DW_var_maxWindSunny - DW_var_minWindSunny))
            } else {
                DW_var_minWindStormy + (random (DW_var_maxWindStormy - DW_var_minWindStormy))
            }
        )
    ] call DW_fnc_randomWind;

    DW_var_currentWeatherChange = [_newOvercast, _newRain, _newFog, _newWind];
    call DW_fnc_nextRandomWeather;
};

DW_fnc_calculateRain = {
    params ["_currentOvercast", "_oldRain", "_targetRain", "_oldOvercast", "_targetOvercast", "_changeWeather", "_forceStart"];

    private "_avgRain";

    if (
        !_changeWeather &&
        {
            _avgRain = ["RAIN"] call DW_fnc_averageCleintsWeather;
            (_avgRain != -1)
        }
    ) then {
        _avgRain
    } else {
        if ((_oldOvercast > 0.5) && (_targetOvercast <= 0.5)) then {
            if (_currentOvercast >= 0.5) then {
                ((_currentOvercast - 0.5) / (_oldOvercast - 0.5)) * _oldRain
            } else {
                0
            }
        } else {
            _avgOvercast = ["OVERCAST"] call DW_fnc_averageCleintsWeather;

            if (_forceStart || (_avgOvercast == -1)) then {
                _avgOvercast = _currentOvercast;
            };

            if (_avgOvercast >= DW_var_minOvercastForRain) then {
                ((_avgOvercast - DW_var_minOvercastForRain) / (1 - DW_var_minOvercastForRain)) * _targetRain
            } else {
                0
            }
        }
    }
};

DW_fnc_changeLoop = {
    params ["_steps", "_targetWeather", "_changeWeather"];
    _targetWeather params ["_targetOvercast", "_targetRain", "_targetFog", "_targetWind"];

    _currentTimeMultiplier = timeMultiplier;

    _oldOvercast = DW_var_currentOvercast;
    _oldRain = DW_var_currentRain;
    _oldFog = DW_var_currentFog;
    _oldWind = DW_var_currentWind;
    _oldWindFactor = [_oldWind] call DW_fnc_windFactor;
    _oldWindAngle = [0, 0, 0] getDir _oldWind;
    _diffOvercast = _targetOvercast - _oldOvercast;
    _diffFog = _targetFog - _oldFog;
    _diffWind = _targetWind - _oldWindFactor;
    _diffWindAngle = if _changeWeather then {(random 360) - 180} else {nil};

    _i = 0;

    waitUntil {
        _i = _i + 1;
        _factor = _i/_steps;

        _overcast = _oldOvercast + (_diffOvercast * _factor);
        _rain = [_overcast, _oldRain, _targetRain, _oldOvercast, _targetOvercast, _changeWeather, (_steps == 1)] call DW_fnc_calculateRain;
        _fog = _oldFog + (_diffFog * _factor);
        _wind = if _changeWeather then {
            ([(([10, 10, 0] vectorMultiply (_oldWindFactor + (_diffWind * _factor))) select [0, 2]), (_oldWindAngle + (_diffWindAngle * _factor))] call BIS_fnc_rotateVector2D) + [0]
        } else {
            _oldWind
        };

        [_overcast, _rain, _fog, _wind] call DW_fnc_setWeather;
        sleep 1;

        if (timeMultiplier != _currentTimeMultiplier) then {
            _steps = ceil (_i + (_currentTimeMultiplier / timeMultiplier) * (_steps - _i));
            _currentTimeMultiplier = timeMultiplier;
        };

        _i >= _steps
    };
};

DW_fnc_monitorNight = {
    _isNight = call DW_fnc_isNight;
    
    waitUntil {
        if ((call DW_fnc_isNight) != _isNight) then {
            _isNight = !_isNight;
            call DW_fnc_updateTimeMultiplier;
        };

        sleep 1;
        false
    };
};

DW_fnc_weatherChange = {
    DW_var_lastWeatherChange params ["_oldOvercast"];
    DW_var_currentWeatherChange params ["_targetOvercast", "_targetRain", "_targetFog", "_targetWind"];

    DW_var_isWeatherChanging = true;
    call DW_fnc_updateTimeMultiplier;

    DW_var_weatherChangeInnerScript = [(ceil ([_targetOvercast - _oldOvercast] call DW_fnc_weatherChangeDuration)), DW_var_currentWeatherChange, true] spawn DW_fnc_changeLoop;
    
    waitUntil {
        sleep 1;
        scriptDone DW_var_weatherChangeInnerScript
    };

    _avgOvercast = ["OVERCAST"] call DW_fnc_averageCleintsWeather;
    _finalOvercast = if (_avgOvercast != -1) then {
        _targetOvercast + (0.7 * (_avgOvercast - _targetOvercast))
    } else {
        _targetOvercast
    };

    DW_var_weatherChangeInnerScript = [(ceil ([_finalOvercast - _targetOvercast] call DW_fnc_weatherChangeDuration)), [_finalOvercast, _targetRain, _targetFog, _targetWind], false] spawn DW_fnc_changeLoop;
    
    waitUntil {
        sleep 1;
        scriptDone DW_var_weatherChangeInnerScript
    };

    DW_var_isWeatherChanging = false;
    call DW_fnc_updateTimeMultiplier;
};

DW_fnc_dynamicWeather = {
    params [["_setDate", true]];

    DW_var_currentOvercast = overcast;
    DW_var_currentRain = rain;
    DW_var_currentFog = fog;
    DW_var_currentWind = wind;

    DW_var_isWeatherChanging = false;
    call DW_fnc_updateTimeMultiplier;

    if _setDate then {
        setDate DW_var_date;
    };

    call DW_fnc_newRandomWeather;
    DW_var_weatherChangeInnerScript = [1, DW_var_currentWeatherChange, true] spawn DW_fnc_changeLoop;
    waitUntil {scriptDone DW_var_weatherChangeInnerScript};

    [0] call DW_fnc_executeWeather;
    forceWeatherChange;

    DW_fnc_executeWeatherScript = [] spawn DW_fnc_executeWeatherLoop;
    DW_fnc_monitorNightScript = [] spawn DW_fnc_monitorNight;

    if DW_var_skipNight then {
        DW_fnc_skipNightScript = [] spawn DW_fnc_skipNightLoop;
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
    DW_var_weatherScript = [_setDate] spawn DW_fnc_dynamicWeather;
};

DW_fnc_stopDynamicWeather = {
    call {
        {
            _script = (missionNameSpace getVariable _x);

            if !(isNull _script) then {
                terminate _script;
            };
        } forEach ["DW_fnc_monitorNightScript", "DW_var_weatherScript", "DW_var_weatherChangeScript", "DW_var_weatherChangeInnerScript", "DW_fnc_skipNightScript", "DW_fnc_executeWeatherScript"];
    };
};

DW_fnc_secondsUntilNightSkip = {
    params ["_skipNightTimeNum"];

    (_skipNightTimeNum - dayTime) * (60 ^ 2) / timeMultiplier
};

DW_fnc_sendNightMessage = {
    params ["_timeLeft"];

    [_timeLeft, {if hasInterface then {_this call DW_fnc_skipNightMessage;};}] remoteExecCall ["DW_fnc_skipNightMessage", 0];
};

DW_fnc_skipNightLoop = {
    _skipNightTimeNum = [DW_var_skipNightTime] call DW_fnc_timeArrToDayTime;
    _startTime = [24 - _skipNightTimeNum] call DW_fnc_dayTimeToTimeArr;

    waitUntil {
        _timeLeft = nil;

        waitUntil {
            _timeLeft = [_skipNightTimeNum] call DW_fnc_secondsUntilNightSkip;
            if (([_skipNightTimeNum] call DW_fnc_secondsUntilNightSkip) > 31) then {
                sleep 0.8;
                false
            } else {
                true
            }
        };

        if (_timeLeft > 10) then {
            [format ["in %1 seconds", (floor _timeLeft)]] call DW_fnc_sendNightMessage;
            sleep (_timeLeft - 5);
            ["in 5 seconds"] call DW_fnc_sendNightMessage;
            sleep 5;
        } else {
            if (_timeLeft >= 0) then {
                [format ["in %1 seconds", (floor _timeLeft)]] call DW_fnc_sendNightMessage;
                sleep _timeLeft;
            } else {
                ["now"] call DW_fnc_sendNightMessage;
            };
        };

        setDate ((DW_var_date select [0, 3]) + _startTime);

        false
    };
};

addMissionEventHandler ["PlayerDisconnected", {_this call DW_fnc_PlayerDisconnected;}];

DW_var_serverInitDone = true;
publicVariable "DW_var_serverInitDone";