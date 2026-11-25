// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\earplugs\scripts\cbaSettings.sqf"}) exitWith {};

[
    "E_cba_enabled",
    "CHECKBOX",
    ["Enable Earplugs", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "Earplugs"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

["E_cba_showIcon", "CHECKBOX", "Show the earplugs icon", ["Dschitarre", "Earplugs"], true] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (E_cba_enabled && {(allMissionObjects "moduleEarplugs") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "earplugs\scripts\fn_init.sqf";
        call E_fnc_startEarplugsServer;
    };
}] call CBA_fnc_addEventHandler;
