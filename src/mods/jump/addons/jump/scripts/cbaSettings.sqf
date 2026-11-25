// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\jump\scripts\cbaSettings.sqf"}) exitWith {};

[
    "J_cba_enabled",
    "CHECKBOX",
    ["Enable Jump", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Jump",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated) then {
    ["J_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "Jump", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "Jump", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["J_cba_jumpSpeed", "SLIDER", ["Jump speed", "Factor, by which the default jump speed gets multiplied."], [0.1, 10, 1, 2]]
];

if (!isServer) exitWith {};

J_fnc_applyCbaSettings = {
    J_var_jumpSpeed = J_cba_jumpSpeed;
    publicVariable "J_var_jumpSpeed";
};

if (_integrated) exitWith {};

J_fnc_startCbaAddon = {
    if (J_cba_enabled && {(allMissionObjects "moduleJump") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "jump\scripts\fn_init.sqf";
        call J_fnc_applyCbaSettings;
        call J_fnc_startJumpServer;
    };
};
