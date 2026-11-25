// Eden module "3D Icons" (server): loads the mod, applies the module settings and starts the icons.
params ["_logic", "", "_activated"];

if (!isServer || {!_activated}) exitWith {};

call compile preprocessFileLineNumbers "tdicons\scripts\fn_init.sqf";

// Checkbox attributes are BOOL; missions saved with the former Enabled/Disabled combos store 0/1
private _flag = {
    params ["_name", "_default"];

    private _value = _logic getVariable [_name, _default];

    if (_value isEqualType 0) then {_value != 0} else {_value}
};

TDI_var_showAllSides = ["showAllSides", false] call _flag;
TDI_var_showAllSidesOnSpectator = ["showAllSidesOnSpectator", false] call _flag;
TDI_var_showUnitNames = ["showUnitNames", true] call _flag;
TDI_var_hideInvisible = ["hideInvisible", true] call _flag;
TDI_var_showGroupIcons = ["showGroupIcons", false] call _flag;
TDI_var_hideInvisibleGroupMembers = ["hideInvisibleGroupMembers", false] call _flag;

{
    publicVariable _x;
} forEach [
    "TDI_var_showAllSides",
    "TDI_var_showAllSidesOnSpectator",
    "TDI_var_showUnitNames",
    "TDI_var_hideInvisible",
    "TDI_var_showGroupIcons",
    "TDI_var_hideInvisibleGroupMembers"
];

call TDI_fnc_startTdIconsServer;
