if isServer then {
    call (compile preprocessFileLineNumbers "earplugs\scripts\fn_init.sqf");

    call E_fnc_startEarplugsServer;
};