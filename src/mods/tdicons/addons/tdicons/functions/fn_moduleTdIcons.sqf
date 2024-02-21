if isServer then {
    params ["_logic", "", "_activated"];

    if !_activated exitWith {};

    call (compile preprocessFileLineNumbers "tdicons\scripts\fn_init.sqf");

    TDI_var_ShowAllSides = (_logic getVariable "showAllSides") == 1;
    TDI_var_ShowAllSidesOnSpectator = (_logic getVariable "showAllSidesOnSpectator") == 1;
    TDI_var_ShowUnitNames = (_logic getVariable "shoWUnitNames") == 1;
    TDI_var_HideInvisible = (_logic getVariable "hideInvisible") == 1;
    TDI_var_ShowGroupIcons = (_logic getVariable "showGroupIcons") == 1;
    TDI_var_HideInvisibleGroupMembers = (_logic getVariable "hideInvisibleGroupMembers") == 1;

    publicVariable "TDI_var_ShowAllSides";
    publicVariable "TDI_var_ShowAllSidesOnSpectator";
    publicVariable "TDI_var_ShowUnitNames";
    publicVariable "TDI_var_HideInvisible";
    publicVariable "TDI_var_ShowGroupIcons";
    publicVariable "TDI_var_HideInvisibleGroupMembers";

    call TDI_fnc_startTdIconsServer;
};