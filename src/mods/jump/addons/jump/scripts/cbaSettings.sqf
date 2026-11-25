// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\jump\scripts\cbaSettings.sqf"}) exitWith {};

[
    "J_cba_enabled",
    "CHECKBOX",
    ["Enable Jump", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "Jump"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (J_cba_enabled && {(allMissionObjects "moduleJump") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "jump\scripts\fn_init.sqf";
        call J_fnc_startJumpServer;
    };
}] call CBA_fnc_addEventHandler;
