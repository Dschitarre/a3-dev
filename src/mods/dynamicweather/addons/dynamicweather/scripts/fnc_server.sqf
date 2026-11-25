// Dynamic weather (server): random weather within configurable ranges in alternating change / static phases,
// following the weather the clients actually see; time multiplier per phase and optional night skip.

// ---- settings ----
// Game modes and the module overwrite the DW_var_* settings after this file ran.

DW_var_minOvercastForRain = 0.6;       // from this overcast on it rains and the stormy fog / wind ranges apply
DW_var_lastWeatherChange = nil;
DW_var_currentWeatherChange = nil;

DW_var_weatherScript = scriptNull;
DW_var_weatherChangeScript = scriptNull;
DW_var_weatherChangeInnerScript = scriptNull;
DW_var_executeWeatherScript = scriptNull;
DW_var_monitorNightScript = scriptNull;
DW_var_skipNightScript = scriptNull;

DW_fnc_setDefaultWeatherRanges = {
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
    DW_var_minWindStormy = 0;
    DW_var_maxWindStormy = 0.6;
};

DW_fnc_setDefaultSettings = {
    call DW_fnc_setDefaultWeatherRanges;

    DW_var_changeTimeMultiplierDay = 15;
    DW_var_changeTimeMultiplierNight = 15;
    DW_var_staticTimeMultiplierDay = 1;
    DW_var_staticTimeMultiplierNight = 1;
    DW_var_isWeatherChanging = false;
    DW_var_timeBetweenWeatherChangesMultiplierSunny = 1;
    DW_var_timeBetweenWeatherChangesMultiplierStormy = 1;
    DW_var_date = [2035, 6, 30, 6, 0];
    DW_var_skipNight = true;
    DW_var_skipNightTime = [18, 0];
};

call DW_fnc_setDefaultSettings;

// ---- weather presets ----
// The presets of Sector Control: the default ranges with a few changes. "custom" keeps the DW_var_* ranges as they are
// (module attributes, or set by a game mode). Missions choose one with DW_var_weatherPreset (not case-sensitive)
// before DW_fnc_startDynamicWeather, e.g. DW_var_weatherPreset = "sunny";

if (isNil "DW_var_weatherPreset") then {
    DW_var_weatherPreset = "custom";
};

DW_var_weatherPresets = createHashMapFromArray [
    ["dynamic", []],
    ["dynamicfoggy", [
        ["DW_var_minFogSunny", 0.1],
        ["DW_var_maxFogSunny", 0.2],
        ["DW_var_minFogStormy", 0.2],
        ["DW_var_maxFogStormy", 0.5]
    ]],
    ["sunny", [["DW_var_maxOvercast", 0.35]]],
    ["cloudy", [["DW_var_minOvercast", 0.6], ["DW_var_maxOvercast", 0.7]]],
    ["stormy", [
        ["DW_var_minOvercast", 0.7],
        ["DW_var_minRain", 0.5],
        ["DW_var_maxRain", 1],
        ["DW_var_minWindStormy", 0.6],
        ["DW_var_maxWindStormy", 1]
    ]],
    // overcast always above DW_var_minOvercastForRain: steady rain, moderate wind, light fog, no storm
    ["rainy", [
        ["DW_var_minOvercast", 0.65],
        ["DW_var_maxOvercast", 0.85],
        ["DW_var_minRain", 0.3],
        ["DW_var_maxRain", 0.7],
        ["DW_var_minFogStormy", 0.05],
        ["DW_var_maxFogStormy", 0.2],
        ["DW_var_minWindStormy", 0.2],
        ["DW_var_maxWindStormy", 0.5]
    ]]
];

DW_fnc_applyWeatherPreset = {
    params ["_preset"];

    private _key = toLowerANSI _preset;

    if (_key == "custom") exitWith {};

    private _changes = DW_var_weatherPresets get _key;

    if (isNil "_changes") exitWith {
        diag_log format ["dynamicweather: unknown weather preset '%1', the ranges stay as they are", _preset];
    };

    call DW_fnc_setDefaultWeatherRanges;

    {
        missionNamespace setVariable _x;
    } forEach _changes;
};

// ---- time ----
// Night is between sunset and sunrise of the map and date. DW_var_isNight (public) changes only on the day / night
// switch, for game modes.

DW_var_sunTimes = [[], [6, 18]];       // [date (year, month, day), [sunrise, sunset]]

// [sunrise, sunset] of the current day in hours; [0, -1] polar summer (no sunset), [-1, 0] polar winter (no sunrise)
DW_fnc_sunTimes = {
    private _day = date select [0, 3];

    if ((DW_var_sunTimes select 0) isNotEqualTo _day) then {
        DW_var_sunTimes = [_day, [date] call BIS_fnc_sunriseSunsetTime];
    };

    DW_var_sunTimes select 1
};

DW_fnc_isNight = {
    (call DW_fnc_sunTimes) params ["_sunrise", "_sunset"];

    if (_sunset == -1) exitWith {false};
    if (_sunrise == -1) exitWith {true};

    dayTime < _sunrise || {dayTime >= _sunset}
};

DW_fnc_publishIsNight = {
    DW_var_isNight = call DW_fnc_isNight;
    publicVariable "DW_var_isNight";
};

call DW_fnc_publishIsNight;

// faster time while the weather changes, separately for day and night
DW_fnc_updateTimeMultiplier = {
    setTimeMultiplier (if (call DW_fnc_isNight) then {
        [DW_var_staticTimeMultiplierNight, DW_var_changeTimeMultiplierNight] select DW_var_isWeatherChanging
    } else {
        [DW_var_staticTimeMultiplierDay, DW_var_changeTimeMultiplierDay] select DW_var_isWeatherChanging
    });
};

DW_fnc_timeArrToDayTime = {
    params ["_timeArr"];
    _timeArr params ["_hour", "_minute"];

    _hour + _minute / 60
};

DW_fnc_monitorNight = {
    waitUntil {
        if ((call DW_fnc_isNight) isNotEqualTo DW_var_isNight) then {
            call DW_fnc_publishIsNight;
            call DW_fnc_updateTimeMultiplier;
        };

        sleep 1;
        false
    };
};

// ---- clients' weather ----
// Every client reports the weather it actually sees when it changed (DW_fnc_setClientWeather); the server follows
// their average.

DW_var_clientWeathers = createHashMap;   // client owner -> [overcast, rain]

DW_fnc_setClientWeather = {
    params ["_weather"];

    DW_var_clientWeathers set [remoteExecutedOwner, _weather];
};

// average overcast ("OVERCAST") or rain ("RAIN") of the clients close to the server's value, -1 if none
DW_fnc_averageClientsWeather = {
    params ["_type"];

    if (count DW_var_clientWeathers == 0) exitWith {-1};

    private _isRain = _type == "RAIN";
    private _reference = [overcast, rain] select _isRain;
    private _values = ((values DW_var_clientWeathers) apply {_x select _isRain}) select {abs (_x - _reference) <= 0.15};

    if (_values isEqualTo []) exitWith {-1};

    private _sum = 0;

    {
        _sum = _sum + _x;
    } forEach _values;

    _sum / count _values
};

addMissionEventHandler ["PlayerDisconnected", {
    params ["", "", "", "", "_owner"];

    DW_var_clientWeathers deleteAt _owner;
}];

#include "weather.sqf"

// ---- night skip ----
// From DW_var_skipNightTime until sunrise the server skips to the sunrise, announcing it 30 and 5 seconds before
// (at once when the time is already in this span, e.g. a start at night).

// seconds until the skip, 0 if it is due
DW_fnc_secondsUntilNightSkip = {
    params ["_skipNightTimeNum"];

    if (dayTime >= _skipNightTimeNum || {dayTime < ((call DW_fnc_sunTimes) select 0)}) exitWith {0};

    (_skipNightTimeNum - dayTime) * 3600 / timeMultiplier
};

// sunrise of the start day (DW_var_date), rounded up to the next full minute; every skip returns to the start day
// on purpose (same day, same sun times)
DW_fnc_morningTime = {
    private _day = DW_var_date select [0, 3];
    private _sunrise = (([_day + [12, 0]] call BIS_fnc_sunriseSunsetTime) select 0) max 0;
    private _minutes = ceil (_sunrise * 60) + 1;

    _day + [floor (_minutes / 60), _minutes mod 60]
};

DW_fnc_sendNightMessage = {
    params ["_text"];

    // DW_fnc_skipNightMessage only exists on machines with an interface
    [_text] remoteExecCall ["DW_fnc_skipNightMessage", [0, -2] select isDedicated];
};

DW_fnc_skipNightLoop = {
    private _skipNightTimeNum = [DW_var_skipNightTime] call DW_fnc_timeArrToDayTime;
    private _morningDate = call DW_fnc_morningTime;

    // a skip time before the sunrise would skip over and over again
    if (([_morningDate select [3, 2]] call DW_fnc_timeArrToDayTime) >= _skipNightTimeNum) exitWith {};

    waitUntil {
        private _timeLeft = 0;

        waitUntil {
            _timeLeft = [_skipNightTimeNum] call DW_fnc_secondsUntilNightSkip;

            if (_timeLeft > 31) then {
                sleep 0.8;
            };

            _timeLeft <= 31
        };

        if (_timeLeft > 10) then {
            [format ["in %1 seconds", floor _timeLeft]] call DW_fnc_sendNightMessage;
            sleep (_timeLeft - 5);
            ["in 5 seconds"] call DW_fnc_sendNightMessage;
            sleep 5;
        } else {
            if (_timeLeft > 0) then {
                [format ["in %1 seconds", floor _timeLeft]] call DW_fnc_sendNightMessage;
                sleep _timeLeft;
            } else {
                ["now"] call DW_fnc_sendNightMessage;
            };
        };

        setDate _morningDate;
        false
    };
};

DW_var_serverInitDone = true;
