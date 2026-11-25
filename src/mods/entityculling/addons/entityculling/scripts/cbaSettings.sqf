// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\entityculling\scripts\cbaSettings.sqf"}) exitWith {};

[
    "EC_cba_enabled",
    "CHECKBOX",
    ["Enable Entity Culling", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "Entity Culling"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (EC_cba_enabled && {(allMissionObjects "moduleEntityCulling") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "entityculling\scripts\fn_init.sqf";
        call EC_fnc_startEntityCullingServer;
    };
}] call CBA_fnc_addEventHandler;
