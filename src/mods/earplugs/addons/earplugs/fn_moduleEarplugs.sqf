// Eden module "Earplugs" (server): loads the mod, sets the players' default settings from its attributes and starts
// it when the module is activated, stops it when the module is deactivated again (trigger).
params ["_logic", "", "_activated"];

if (!isServer) exitWith {};

if (!_activated) exitWith {
    if (!isNil "E_fnc_stopEarplugsServer") then {
        call E_fnc_stopEarplugsServer;
    };
};

call compile preprocessFileLineNumbers "earplugs\scripts\fn_init.sqf";

// automatic earplugs per vehicle category: the volume, or -1 (off: the player can still turn them on, then with the
// volume of the mod's defaults)
private _autoEnabled = [];
private _autoVolumes = [];

{
    _x params ["_attribute", "_fallback"];

    private _value = _logic getVariable [_attribute, _fallback];

    _autoEnabled pushBack (_value >= 0);
    _autoVolumes pushBack ([_value, _fallback] select (_value < 0));
} forEach [["volumeGround", 0.5], ["volumeAir", 0.3], ["volumeBoat", 0.5]];

E_var_defaultSettings = [_logic getVariable ["volumeMuted", 0.3], _autoEnabled, _autoVolumes];
publicVariable "E_var_defaultSettings";

call E_fnc_startEarplugsServer;
