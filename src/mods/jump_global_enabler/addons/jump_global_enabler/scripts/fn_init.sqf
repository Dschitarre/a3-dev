if isServer then {
    call (compile preprocessFileLineNumbers "jump\scripts\fn_init.sqf");

    call J_fnc_startJumpServer;
};