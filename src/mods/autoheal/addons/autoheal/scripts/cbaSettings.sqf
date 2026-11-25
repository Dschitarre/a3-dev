// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\autoheal\scripts\cbaSettings.sqf"}) exitWith {};

[
    "AH_cba_enabled",
    "CHECKBOX",
    ["Enable Auto Heal", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "Auto Heal"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (AH_cba_enabled && {(allMissionObjects "moduleAutoHeal") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "autoheal\scripts\fn_init.sqf";
        call AH_fnc_startAutoHealServer;
    };
}] call CBA_fnc_addEventHandler;
