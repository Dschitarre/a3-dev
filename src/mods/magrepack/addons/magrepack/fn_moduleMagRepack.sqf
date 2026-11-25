// Eden module "Magazine Repack" (server): loads the mod, applies the module settings and starts it when the module is
// activated, stops it when the module is deactivated again (trigger).
params ["_logic", "", "_activated"];

if (!isServer) exitWith {};

if (!_activated) exitWith {
    if (!isNil "MR_fnc_stopMagRepackServer") then {
        call MR_fnc_stopMagRepackServer;
    };
};

call compile preprocessFileLineNumbers "magrepack\scripts\fn_init.sqf";

// module attribute -> setting (missing attributes keep the current value); the start publishes them
{
    _x params ["_variable", "_attribute"];

    missionNamespace setVariable [_variable, _logic getVariable [_attribute, missionNamespace getVariable _variable]];
} forEach [
    ["MR_var_enabled", "enabled"],
    ["MR_var_secondsPerRound", "secondsPerRound"],
    ["MR_var_aiRepack", "aiRepack"],
    ["MR_var_aiInterval", "aiInterval"]
];

call MR_fnc_startMagRepackServer;
