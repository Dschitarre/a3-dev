if isServer then {
    params ["_logic", "", "_activated"];

    if !_activated exitWith {};

    call (compile preprocessFileLineNumbers "holster\scripts\fn_init.sqf");

    call H_fnc_startHolsterServer;
};