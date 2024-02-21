if isServer then {
    params ["_logic", "", "_activated"];

    if !_activated exitWith {};

    call (compile preprocessFileLineNumbers "earplugs\scripts\fn_init.sqf");

    E_var_volumeMuted = _logic getVariable "volumeMuted";
    publicVariable "E_var_volumeMuted";

    call E_fnc_startEarplugsServer;
};