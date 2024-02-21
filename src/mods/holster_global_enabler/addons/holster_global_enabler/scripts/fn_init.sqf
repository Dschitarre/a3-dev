if isServer then {
    call (compile preprocessFileLineNumbers "holster\scripts\fn_init.sqf");

    call H_fnc_startHolsterServer;
};