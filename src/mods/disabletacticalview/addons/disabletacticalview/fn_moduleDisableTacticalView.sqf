// Eden module "Disable Tactical View" (server): loads the mod and starts it when the module is activated, stops it
// when the module is deactivated again (trigger).
params ["_logic", "", "_activated"];

if (!isServer) exitWith {};

if (!_activated) exitWith {
    if (!isNil "DTV_fnc_stopDisableTacticalViewServer") then {
        call DTV_fnc_stopDisableTacticalViewServer;
    };
};

call compile preprocessFileLineNumbers "disabletacticalview\scripts\fn_init.sqf";

call DTV_fnc_startDisableTacticalViewServer;
