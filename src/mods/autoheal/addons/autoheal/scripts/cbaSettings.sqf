// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\autoheal\scripts\cbaSettings.sqf"}) exitWith {};

[
    "AH_cba_enabled",
    "CHECKBOX",
    ["Enable Auto Heal", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Auto Heal",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated) then {
    ["AH_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "Auto Heal", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "Auto Heal", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["AH_cba_healSpeed", "SLIDER", ["Heal speed", "Factor, by which the default speed of healing gets multiplied."], [0.1, 10, 1, 2]],
    ["AH_cba_healCooldown", "SLIDER", ["Heal cooldown", "Time, after which a unit starts to heal."], [0, 60, 12, 0]],
    ["AH_cba_healCooldownMedic", "SLIDER", ["Medic heal cooldown", "Time, after which a medic unit starts to heal."], [0, 60, 8, 0]]
];

if (!isServer) exitWith {};

AH_fnc_applyCbaSettings = {
    AH_var_healSpeed = AH_cba_healSpeed;
    AH_var_healCooldown = AH_cba_healCooldown;
    AH_var_healCooldownMedic = AH_cba_healCooldownMedic;

    {
        publicVariable _x;
    } forEach [
        "AH_var_healSpeed",
        "AH_var_healCooldown",
        "AH_var_healCooldownMedic"
    ];
};

if (_integrated) exitWith {};

AH_fnc_startCbaAddon = {
    if (AH_cba_enabled && {(allMissionObjects "moduleAutoHeal") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "autoheal\scripts\fn_init.sqf";
        call AH_fnc_applyCbaSettings;
        call AH_fnc_startAutoHealServer;
    };
};
