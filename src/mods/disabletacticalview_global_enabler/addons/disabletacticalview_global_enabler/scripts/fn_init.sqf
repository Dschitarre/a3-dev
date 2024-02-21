if isServer then {
    call (compile preprocessFileLineNumbers "disabletacticalview\scripts\fn_init.sqf");

    call DTV_fnc_startDisableTacticalViewServer;
};