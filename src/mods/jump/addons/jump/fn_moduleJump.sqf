// Eden module "Jump" (server): loads the mod and starts it when the module is activated, stops it when the module
// is deactivated again (trigger).
params ["_logic", "", "_activated"];

if (!isServer) exitWith {};

if (!_activated) exitWith {
    if (!isNil "J_fnc_stopJumpServer") then {
        call J_fnc_stopJumpServer;
    };
};

call compile preprocessFileLineNumbers "jump\scripts\fn_init.sqf";

J_var_jumpSpeed = _logic getVariable ["jumpSpeed", 1];
publicVariable "J_var_jumpSpeed";

call J_fnc_startJumpServer;
