// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\disabletacticalview\scripts\cbaSettings.sqf"}) exitWith {};

[
    "DTV_cba_enabled",
    "CHECKBOX",
    ["Enable Disable Tactical View", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Disable Tactical View",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

DTV_fnc_startCbaAddon = {
    if (DTV_cba_enabled && {(allMissionObjects "moduleDisableTacticalView") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "disabletacticalview\scripts\fn_init.sqf";
        call DTV_fnc_startDisableTacticalViewServer;
    };
};
