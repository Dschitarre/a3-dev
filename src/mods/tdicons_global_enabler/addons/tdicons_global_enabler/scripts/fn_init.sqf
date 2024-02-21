if isServer then {
    call (compile preprocessFileLineNumbers "tdicons\scripts\fn_init.sqf");

    call TDI_fnc_startTdIconsServer;
};