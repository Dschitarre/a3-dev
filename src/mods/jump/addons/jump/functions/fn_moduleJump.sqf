if isServer then {
    params ["_logic", "", "_activated"];

    if !_activated exitWith {};

    call (compile preprocessFileLineNumbers "jump\scripts\fn_init.sqf");

    J_var_JumpSpeed = _logic getVariable "jumpSpeed";

    call J_fnc_startJumpServer;
};