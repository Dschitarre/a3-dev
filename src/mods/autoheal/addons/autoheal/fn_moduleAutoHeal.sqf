// Eden module "Auto Heal" (server): loads the mod and starts it when the module is activated, stops it when the
// module is deactivated again (trigger).
params ["_logic", "", "_activated"];

if (!isServer) exitWith {};

if (!_activated) exitWith {
    if (!isNil "AH_fnc_stopAutoHealServer") then {
        call AH_fnc_stopAutoHealServer;
    };
};

call compile preprocessFileLineNumbers "autoheal\scripts\fn_init.sqf";

AH_var_healSpeed = _logic getVariable ["healSpeed", 1];
AH_var_healCooldown = _logic getVariable ["healCooldown", 12];
AH_var_healCooldownMedic = _logic getVariable ["healCooldownMedic", 8];

publicVariable "AH_var_healSpeed";
publicVariable "AH_var_healCooldown";
publicVariable "AH_var_healCooldownMedic";

call AH_fnc_startAutoHealServer;
