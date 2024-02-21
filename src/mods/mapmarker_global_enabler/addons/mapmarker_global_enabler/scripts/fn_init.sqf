if isServer then {
    call (compile preprocessFileLineNumbers "mapmarker\scripts\fn_init.sqf");

    call MM_fnc_startMapMarkerServer;
};