// Eden module "Holster" (server): loads the mod and starts it when the module is activated, stops it when the
// module is deactivated again (trigger).
params ["_logic", "", "_activated"];

if (!isServer) exitWith {};

if (!_activated) exitWith {
    if (!isNil "H_fnc_stopHolsterServer") then {
        call H_fnc_stopHolsterServer;
    };
};

call compile preprocessFileLineNumbers "holster\scripts\fn_init.sqf";

call H_fnc_startHolsterServer;
