if isServer then {
    params ["_logic", "", "_activated"];

    if !_activated exitWith {};

    call (compile preprocessFileLineNumbers "disablestamina\scripts\fn_init.sqf");

    DS_var_weaponSwayEnabled = _logic getVariable "weaponSwayEnabled";
    DS_var_weaponSwayDisabled = _logic getVariable "weaponSwayDisabled";

    publicVariable "DS_var_weaponSwayEnabled";
    publicVariable "DS_var_weaponSwayDisabled";

    call DS_fnc_startDisableStaminaServer;
};