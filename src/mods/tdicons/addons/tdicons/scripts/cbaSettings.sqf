// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\tdicons\scripts\cbaSettings.sqf"}) exitWith {};

[
    "TDI_cba_enabled",
    "CHECKBOX",
    ["Enable 3D Icons", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "3D Icons",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

["TDI_cba_showIcons", "CHECKBOX", "Show 3D icons", "3D Icons", true] call CBA_fnc_addSetting;

if (_integrated) then {
    ["TDI_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "3D Icons", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "3D Icons", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["TDI_cba_showAllSides", "CHECKBOX", ["Show all sides", "Toggles whether units of all sides are displayed."], false],
    ["TDI_cba_showAllSidesOnSpectator", "CHECKBOX", ["Show all sides when in spectator", "Toggles whether units of all sides are displayed when in spectator."], false],
    ["TDI_cba_showUnitNames", "CHECKBOX", ["Show Unit Names", "Toggles whether the names of units are shown below the icons."], true],
    ["TDI_cba_hideInvisible", "CHECKBOX", ["Hide invisible", "Toggles whether the icons of units, that are not visible, are hidden."], true],
    ["TDI_cba_showGroupIcons", "CHECKBOX", ["Show Group Icons", "Toggles whether to show group icons (if enabled, please disable group icons in the difficulty settings)."], false],
    ["TDI_cba_hideInvisibleGroupMembers", "CHECKBOX", ["Hide invisible Group Members", "Toggles whether the icons of group members, that are not visible, are hidden."], false],
    ["TDI_cba_drawUnitsOnSpectator", "CHECKBOX", ["Draw units while spectating", "Enable unit icons while using the spectator camera."], true],
    ["TDI_cba_groupUnitsLimitedDistance", "CHECKBOX", ["Limit range of group icons", "Apply the general distance limit to group members as well."], false]
];

if (!isServer) exitWith {};

TDI_fnc_applyCbaSettings = {
    TDI_var_showAllSides = TDI_cba_showAllSides;
    TDI_var_showAllSidesOnSpectator = TDI_cba_showAllSidesOnSpectator;
    TDI_var_showUnitNames = TDI_cba_showUnitNames;
    TDI_var_hideInvisible = TDI_cba_hideInvisible;
    TDI_var_showGroupIcons = TDI_cba_showGroupIcons;
    TDI_var_hideInvisibleGroupMembers = TDI_cba_hideInvisibleGroupMembers;
    TDI_var_drawUnitsOnSpectator = TDI_cba_drawUnitsOnSpectator;
    TDI_var_groupUnitsLimitedDistance = TDI_cba_groupUnitsLimitedDistance;

    {
        publicVariable _x;
    } forEach [
        "TDI_var_showAllSides",
        "TDI_var_showAllSidesOnSpectator",
        "TDI_var_showUnitNames",
        "TDI_var_hideInvisible",
        "TDI_var_showGroupIcons",
        "TDI_var_hideInvisibleGroupMembers",
        "TDI_var_drawUnitsOnSpectator",
        "TDI_var_groupUnitsLimitedDistance"
    ];
};

if (_integrated) exitWith {};

TDI_fnc_startCbaAddon = {
    if (TDI_cba_enabled && {(allMissionObjects "moduleTdIcons") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "tdicons\scripts\fn_init.sqf";
        call TDI_fnc_applyCbaSettings;
        call TDI_fnc_startTdIconsServer;
    };
};
