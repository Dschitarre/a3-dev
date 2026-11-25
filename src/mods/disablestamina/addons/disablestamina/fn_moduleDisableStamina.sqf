// Eden module "Disable Stamina" (server): loads the mod and starts it when the module is activated, stops it when
// the module is deactivated again (trigger).
params ["_logic", "", "_activated"];

if (!isServer) exitWith {};

if (!_activated) exitWith {
    if (!isNil "DS_fnc_stopDisableStaminaServer") then {
        call DS_fnc_stopDisableStaminaServer;
    };
};

call compile preprocessFileLineNumbers "disablestamina\scripts\fn_init.sqf";

DS_var_weaponSwayEnabled = _logic getVariable ["weaponSwayEnabled", 1];
DS_var_weaponSwayDisabled = _logic getVariable ["weaponSwayDisabled", 0.3];

publicVariable "DS_var_weaponSwayEnabled";
publicVariable "DS_var_weaponSwayDisabled";

call DS_fnc_startDisableStaminaServer;
