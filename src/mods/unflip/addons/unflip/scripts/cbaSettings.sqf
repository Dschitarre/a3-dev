// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\unflip\scripts\cbaSettings.sqf"}) exitWith {};

[
    "UF_cba_enabled",
    "CHECKBOX",
    ["Enable Unflip", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "Unflip"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (UF_cba_enabled && {(allMissionObjects "moduleUnflip") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "unflip\scripts\fn_init.sqf";
        call UF_fnc_startUnflipServer;
    };
}] call CBA_fnc_addEventHandler;
