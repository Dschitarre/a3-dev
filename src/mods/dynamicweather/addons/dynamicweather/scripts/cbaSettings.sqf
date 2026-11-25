// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\dynamicweather\scripts\cbaSettings.sqf"}) exitWith {};

[
    "DW_cba_enabled",
    "CHECKBOX",
    ["Enable Dynamic Weather", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "Dynamic Weather"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (DW_cba_enabled && {(allMissionObjects "moduleDynamicWeather") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "dynamicweather\scripts\fn_init.sqf";
        [false] call DW_fnc_startDynamicWeather;
    };
}] call CBA_fnc_addEventHandler;
