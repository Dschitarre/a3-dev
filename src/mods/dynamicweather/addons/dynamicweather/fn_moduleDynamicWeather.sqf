// Eden module "Dynamic Weather" (server): loads the mod, applies the module settings and starts the weather.
params ["_logic", "", "_activated"];

if (!isServer || {!_activated}) exitWith {};

call compile preprocessFileLineNumbers "dynamicweather\scripts\fn_init.sqf";

// module attribute -> setting (missing attributes keep the default)
{
    _x params ["_variable", "_attribute"];
    missionNamespace setVariable [_variable, _logic getVariable [_attribute, missionNamespace getVariable _variable]];
} forEach [
    ["DW_var_minOvercast", "minOvercast"],
    ["DW_var_maxOvercast", "maxOvercast"],
    ["DW_var_minFogSunny", "minFogSunny"],
    ["DW_var_maxFogSunny", "maxFogSunny"],
    ["DW_var_minFogStormy", "minFogStormy"],
    ["DW_var_maxFogStormy", "maxFogStormy"],
    ["DW_var_minRain", "minRain"],
    ["DW_var_maxRain", "maxRain"],
    ["DW_var_minWindSunny", "minWindSunny"],
    ["DW_var_maxWindSunny", "maxWindSunny"],
    ["DW_var_minWindStormy", "minWindStormy"],
    ["DW_var_maxWindStormy", "maxWindStormy"],
    ["DW_var_changeTimeMultiplierDay", "timeMultiplierChangeDay"],
    ["DW_var_staticTimeMultiplierDay", "timeMultiplierStaticDay"],
    ["DW_var_changeTimeMultiplierNight", "timeMultiplierChangeNight"],
    ["DW_var_staticTimeMultiplierNight", "timeMultiplierStaticNight"],
    ["DW_var_timeBetweenWeatherChangesMultiplierSunny", "timeBetweenWeatherChangesMultiplierSunny"],
    ["DW_var_timeBetweenWeatherChangesMultiplierStormy", "timeBetweenWeatherChangesMultiplierStormy"]
];

// "Custom" uses the range attributes above (DW_fnc_applyWeatherPreset)
DW_var_weatherPreset = ["custom", "dynamic", "dynamicFoggy", "sunny", "cloudy", "stormy", "rainy"] param [_logic getVariable ["weatherPreset", 0], "custom"];

private _skipNightTime = _logic getVariable ["skipNightTime", 19];

DW_var_skipNight = _skipNightTime != 0;

if (DW_var_skipNight) then {
    DW_var_skipNightTime = [_skipNightTime, 0];
};

DW_var_date = date select [0, 3];

[false] call DW_fnc_startDynamicWeather;
