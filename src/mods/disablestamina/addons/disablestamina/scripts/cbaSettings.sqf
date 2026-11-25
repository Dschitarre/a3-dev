// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\disablestamina\scripts\cbaSettings.sqf"}) exitWith {};

[
    "DS_cba_enabled",
    "CHECKBOX",
    ["Enable Disable Stamina", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Disable Stamina",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated) then {
    ["DS_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "Disable Stamina", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "Disable Stamina", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["DS_cba_weaponSwayEnabled", "SLIDER", ["Weapon sway when enabled", "Amount of weapon sway when stamina is enabled."], [0, 1, 1, 2]],
    ["DS_cba_weaponSwayDisabled", "SLIDER", ["Weapon sway when disabled", "Amount of weapon sway when stamina is disabled."], [0, 1, 0.3, 2]]
];

if (!isServer) exitWith {};

DS_fnc_applyCbaSettings = {
    DS_var_weaponSwayEnabled = DS_cba_weaponSwayEnabled;
    DS_var_weaponSwayDisabled = DS_cba_weaponSwayDisabled;

    {
        publicVariable _x;
    } forEach [
        "DS_var_weaponSwayEnabled",
        "DS_var_weaponSwayDisabled"
    ];
};

if (_integrated) exitWith {};

DS_fnc_startCbaAddon = {
    if (DS_cba_enabled && {(allMissionObjects "moduleDisableStamina") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "disablestamina\scripts\fn_init.sqf";
        call DS_fnc_applyCbaSettings;
        call DS_fnc_startDisableStaminaServer;
    };
};
