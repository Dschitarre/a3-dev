if isServer then {
    call (compile preprocessFileLineNumbers "autoheal\scripts\fn_init.sqf");

    call AH_fnc_startAutoHealServer;
};