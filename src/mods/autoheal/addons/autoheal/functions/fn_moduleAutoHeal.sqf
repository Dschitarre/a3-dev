if isServer then {
    params ["_logic", "", "_activated"];

    if !_activated exitWith {};

    call (compile preprocessFileLineNumbers "autoheal\scripts\fn_init.sqf");

    AH_var_HealSpeed = _logic getVariable "healSpeed";
    AH_var_HealCoolDown = _logic getVariable "healCooldown";
    AH_var_HealCooldownMedic = _logic getVariable "healCooldownMedic";

    publicVariable "AH_var_HealSpeed";
    publicVariable "AH_var_HealCooldownMedic";
    publicVariable "AH_var_HealCoolDown";

    call AH_fnc_startAutoHealServer;
};