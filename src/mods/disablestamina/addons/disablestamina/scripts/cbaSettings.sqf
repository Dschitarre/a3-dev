// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\disablestamina\scripts\cbaSettings.sqf"}) exitWith {};

[
    "DS_cba_enabled",
    "CHECKBOX",
    ["Enable Disable Stamina", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "Disable Stamina"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (DS_cba_enabled && {(allMissionObjects "moduleDisableStamina") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "disablestamina\scripts\fn_init.sqf";
        call DS_fnc_startDisableStaminaServer;
    };
}] call CBA_fnc_addEventHandler;
