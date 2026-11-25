// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\tdicons\scripts\cbaSettings.sqf"}) exitWith {};

[
    "TDI_cba_enabled",
    "CHECKBOX",
    ["Enable 3D Icons", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "3D Icons"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

["TDI_cba_showIcons", "CHECKBOX", "Show 3D icons", ["Dschitarre", "3D Icons"], true] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (TDI_cba_enabled && {(allMissionObjects "moduleTdIcons") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "tdicons\scripts\fn_init.sqf";
        call TDI_fnc_startTdIconsServer;
    };
}] call CBA_fnc_addEventHandler;
