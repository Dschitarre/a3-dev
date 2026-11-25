// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\magrepack\scripts\cbaSettings.sqf"}) exitWith {};

[
    "MR_cba_enabled",
    "CHECKBOX",
    ["Enable Magazine Repack", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "Magazine Repack"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (MR_cba_enabled && {(allMissionObjects "moduleMagRepack") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "magrepack\scripts\fn_init.sqf";
        call MR_fnc_startMagRepackServer;
    };
}] call CBA_fnc_addEventHandler;
