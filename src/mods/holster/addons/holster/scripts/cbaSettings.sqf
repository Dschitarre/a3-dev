// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\holster\scripts\cbaSettings.sqf"}) exitWith {};

[
    "H_cba_enabled",
    "CHECKBOX",
    ["Enable Holster", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Holster",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

H_fnc_startCbaAddon = {
    if (H_cba_enabled && {(allMissionObjects "moduleHolster") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "holster\scripts\fn_init.sqf";
        call H_fnc_startHolsterServer;
    };
};
