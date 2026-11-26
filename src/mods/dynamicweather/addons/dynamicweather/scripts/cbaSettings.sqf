// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\dynamicweather\scripts\cbaSettings.sqf"}) exitWith {};

[
    "DW_cba_enabled",
    "CHECKBOX",
    ["Enable Dynamic Weather", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Dynamic Weather",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated) then {
    ["DW_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "Dynamic Weather", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "Dynamic Weather", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["DW_cba_weatherPreset", "LIST", ["Weather preset", "Choose Custom to use the cloud cover, fog, rain and wind ranges below."], [["custom", "dynamic", "dynamicFoggy", "sunny", "cloudy", "stormy", "rainy"], ["Custom", "Dynamic", "Dynamic (foggy)", "Sunny", "Cloudy", "Stormy", "Rainy"], 0]],
    ["DW_cba_minOvercast", "SLIDER", ["Minimum overcast", "Lower border of the range the overcast can change within."], [0, 1, 0, 1]],
    ["DW_cba_maxOvercast", "SLIDER", ["Maximum overcast", "Upper border of the range the overcast can change within."], [0, 1, 1, 1]],
    ["DW_cba_minFogSunny", "SLIDER", ["Minimum fog while sunny", "Lower border of the range the fog can change within while it is sunny."], [0, 1, 0, 1]],
    ["DW_cba_maxFogSunny", "SLIDER", ["Maximum fog while sunny", "Upper border of the range the fog can change within while it is sunny."], [0, 1, 0, 1]],
    ["DW_cba_minFogStormy", "SLIDER", ["Minimum fog while stormy", "Lower border of the range the fog can change within while it is stormy."], [0, 1, 0, 1]],
    ["DW_cba_maxFogStormy", "SLIDER", ["Maximum fog while stormy", "Upper border of the range the fog can change within while it is stormy."], [0, 1, 0.1, 1]],
    ["DW_cba_minRain", "SLIDER", ["Minimum rain", "Lower border of the range the rain can change within."], [0, 1, 0, 1]],
    ["DW_cba_maxRain", "SLIDER", ["Maximum rain", "Upper border of the range the rain can change within."], [0, 1, 0.7, 1]],
    ["DW_cba_minWindSunny", "SLIDER", ["Minimum wind while sunny", "Lower border of the range the wind can change within while sunny."], [0, 1, 0, 1]],
    ["DW_cba_maxWindSunny", "SLIDER", ["Maximum wind while sunny", "Upper border of the range the wind can change within while sunny."], [0, 1, 0.3, 1]],
    ["DW_cba_minWindStormy", "SLIDER", ["Minimum wind while stormy", "Lower border of the range the wind can change within while stormy."], [0, 1, 0, 1]],
    ["DW_cba_maxWindStormy", "SLIDER", ["Maximum wind while stormy", "Upper border of the range the wind can change within while stormy."], [0, 1, 0.6, 1]],
    ["DW_cba_changeTimeMultiplierDay", "SLIDER", ["Change time multiplier during daytime", "Time multiplier during weather change (day)."], [1, 120, 15, 0]],
    ["DW_cba_changeTimeMultiplierNight", "SLIDER", ["Change time multiplier during night", "Time multiplier during weather change (night)."], [1, 120, 15, 0]],
    ["DW_cba_staticTimeMultiplierDay", "SLIDER", ["Static time multiplier during daytime", "Time multiplier while weather is static (day)."], [1, 120, 1, 0]],
    ["DW_cba_staticTimeMultiplierNight", "SLIDER", ["Static time multiplier during night", "Time multiplier while weather is static (night)."], [1, 120, 1, 0]],
    ["DW_cba_silenceBells", "CHECKBOX", ["Silence church bells", "Turns off the bells of churches and bell towers for every player."], true],
    ["DW_cba_skipNightTime", "SLIDER", ["Skip night from hour (0 = off)", "Hour of the mission day from which the clock skips to a bright morning (as bright as Altis at 06:00). Defaults to 18:00."], [0, 23, 18, 0]],
    ["DW_cba_timeBetweenWeatherChangesMultiplierSunny", "SLIDER", ["Time between weather changes when sunny", "Determines how long the weather stays the same between weather changes when it is sunny."], [0.1, 12, 1, 1]],
    ["DW_cba_timeBetweenWeatherChangesMultiplierStormy", "SLIDER", ["Time between weather changes when stormy", "Determines how long the weather stays the same between weather changes when it is stormy."], [0.1, 12, 1, 1]]
];

if (!isServer) exitWith {};

DW_fnc_applyCbaSettings = {
    DW_var_weatherPreset = DW_cba_weatherPreset;
    DW_var_minOvercast = DW_cba_minOvercast min DW_cba_maxOvercast;
    DW_var_maxOvercast = DW_cba_minOvercast max DW_cba_maxOvercast;
    DW_var_minFogSunny = DW_cba_minFogSunny min DW_cba_maxFogSunny;
    DW_var_maxFogSunny = DW_cba_minFogSunny max DW_cba_maxFogSunny;
    DW_var_minFogStormy = DW_cba_minFogStormy min DW_cba_maxFogStormy;
    DW_var_maxFogStormy = DW_cba_minFogStormy max DW_cba_maxFogStormy;
    DW_var_minRain = DW_cba_minRain min DW_cba_maxRain;
    DW_var_maxRain = DW_cba_minRain max DW_cba_maxRain;
    DW_var_minWindSunny = DW_cba_minWindSunny min DW_cba_maxWindSunny;
    DW_var_maxWindSunny = DW_cba_minWindSunny max DW_cba_maxWindSunny;
    DW_var_minWindStormy = DW_cba_minWindStormy min DW_cba_maxWindStormy;
    DW_var_maxWindStormy = DW_cba_minWindStormy max DW_cba_maxWindStormy;
    DW_var_changeTimeMultiplierDay = DW_cba_changeTimeMultiplierDay;
    DW_var_changeTimeMultiplierNight = DW_cba_changeTimeMultiplierNight;
    DW_var_staticTimeMultiplierDay = DW_cba_staticTimeMultiplierDay;
    DW_var_staticTimeMultiplierNight = DW_cba_staticTimeMultiplierNight;
    DW_var_timeBetweenWeatherChangesMultiplierSunny = DW_cba_timeBetweenWeatherChangesMultiplierSunny;
    DW_var_timeBetweenWeatherChangesMultiplierStormy = DW_cba_timeBetweenWeatherChangesMultiplierStormy;
    DW_var_silenceBells = DW_cba_silenceBells;
    DW_var_skipNight = DW_cba_skipNightTime > 0;
    DW_var_skipNightTime = [DW_cba_skipNightTime, 0];
};

if (_integrated) exitWith {};

DW_fnc_startCbaAddon = {
    if (DW_cba_enabled && {(allMissionObjects "moduleDynamicWeather") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "dynamicweather\scripts\fn_init.sqf";
        call DW_fnc_applyCbaSettings;
        [false] call DW_fnc_startDynamicWeather;
    };
};
