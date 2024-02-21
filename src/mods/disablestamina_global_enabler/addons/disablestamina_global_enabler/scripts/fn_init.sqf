if isServer then {
    call (compile preprocessFileLineNumbers "disablestamina\scripts\fn_init.sqf");

    call DS_fnc_startDisableStaminaServer;
};