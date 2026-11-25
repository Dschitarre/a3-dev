// Eden module "Entity Culling" (server): loads the mod, publishes the module settings and starts the culling on every
// client when the module is activated, stops it (everything hidden is revealed) when it is deactivated (trigger).
params ["_logic", "", "_activated"];

if (!isServer) exitWith {};

if (!_activated) exitWith {
    if (!isNil "EC_fnc_stopEntityCullingServer") then {
        call EC_fnc_stopEntityCullingServer;
    };
};

call compile preprocessFileLineNumbers "entityculling\scripts\fn_init.sqf";

// module attribute -> setting (missing attributes keep the current value)
{
    _x params ["_variable", "_attribute"];

    missionNamespace setVariable [_variable, _logic getVariable [_attribute, missionNamespace getVariable _variable]];
    publicVariable _variable;
} forEach [
    ["EC_var_enabled", "enabled"],
    ["EC_var_frameBudget", "frameBudget"],
    ["EC_var_minDistance", "minDistance"],
    ["EC_var_checkInterval", "checkInterval"],
    ["EC_var_hideAfterChecks", "hideAfterChecks"],
    ["EC_var_lookahead", "lookahead"],
    ["EC_var_debug", "debug"]
];

call EC_fnc_startEntityCullingServer;
