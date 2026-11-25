// Eden module "Map Marker" (server): loads the mod, applies the module settings and starts the map markers.
params ["_logic", "", "_activated"];

if (!isServer || {!_activated}) exitWith {};

call compile preprocessFileLineNumbers "mapmarker\scripts\fn_init.sqf";

// Checkbox attributes are BOOL; missions saved with the former Enabled/Disabled combos store 0/1
private _flag = {
    params ["_name", "_default"];

    private _value = _logic getVariable [_name, _default];

    if (_value isEqualType 0) then {_value != 0} else {_value}
};

MM_var_showAllSides = ["showAllSides", false] call _flag;
MM_var_showAllSidesOnSpectator = ["showAllSidesOnSpectator", false] call _flag;
MM_var_showUnitNames = ["showUnitNames", true] call _flag;
MM_var_showUnitNamesOnlyOnHover = ["showUnitNamesOnlyOnHover", false] call _flag;

{
    publicVariable _x;
} forEach [
    "MM_var_showAllSides",
    "MM_var_showAllSidesOnSpectator",
    "MM_var_showUnitNames",
    "MM_var_showUnitNamesOnlyOnHover"
];

call MM_fnc_startMapMarkerServer;
