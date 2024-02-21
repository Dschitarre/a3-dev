if isServer then {
    params ["_logic", "", "_activated"];

    if !_activated exitWith {};

    call (compile preprocessFileLineNumbers "disabletacticalview\scripts\fn_init.sqf");

    call DTV_fnc_startDisableTacticalViewServer;
};