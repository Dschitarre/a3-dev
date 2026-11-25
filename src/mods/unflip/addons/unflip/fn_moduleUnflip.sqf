// Eden module "Unflip" (server): loads the mod, applies the module settings and starts it when the module is
// activated, stops it when the module is deactivated again (trigger).
params ["_logic", "", "_activated"];

if (!isServer) exitWith {};

if (!_activated) exitWith {
    if (!isNil "UF_fnc_stopUnflipServer") then {
        call UF_fnc_stopUnflipServer;
    };
};

call compile preprocessFileLineNumbers "unflip\scripts\fn_init.sqf";

// module attribute -> setting (missing attributes keep the current value); the start publishes them
{
    _x params ["_variable", "_attribute"];

    missionNamespace setVariable [_variable, _logic getVariable [_attribute, missionNamespace getVariable _variable]];
} forEach [
    ["UF_var_enabled", "enabled"],
    ["UF_var_maxDistance", "maxDistance"],
    ["UF_var_minTilt", "minTilt"],
    ["UF_var_durationMin", "durationMin"],
    ["UF_var_durationMax", "durationMax"],
    ["UF_var_damageProtection", "damageProtection"],
    ["UF_var_aiAutoUnflip", "aiAutoUnflip"],
    ["UF_var_aiDelay", "aiDelay"]
];

call UF_fnc_startUnflipServer;
