// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\mapmarker\scripts\cbaSettings.sqf"}) exitWith {};

[
    "MM_cba_enabled",
    "CHECKBOX",
    ["Enable Map Marker", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Map Marker",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

["MM_cba_showMarkers", "CHECKBOX", "Show map markers", "Map Marker", true] call CBA_fnc_addSetting;

if (_integrated) then {
    ["MM_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "Map Marker", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "Map Marker", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["MM_cba_showAllSides", "CHECKBOX", ["Show all sides", "Toggles whether units of all sides are displayed."], false],
    ["MM_cba_showAllSidesOnSpectator", "CHECKBOX", ["Show all sides when in spectator", "Toggles whether units of all sides are displayed when in spectator."], false],
    ["MM_cba_showUnitNames", "CHECKBOX", ["Show Unit Names", "Toggles whether to show the names of units."], true],
    ["MM_cba_showUnitNamesOnlyOnHover", "CHECKBOX", ["Show Unit Names only on Hover", "Toggles whether to show the name of a unit only when hovering over it on the map."], false],
    ["MM_cba_showAliveGroupUnits", "CHECKBOX", ["Show living group members", "Include living group members in the unit overlay."], true],
    ["MM_cba_showOwnUnitOnly", "CHECKBOX", ["Show only your own unit", "Restrict the unit overlay to the player or the currently viewed unit."], false]
];

if (!isServer) exitWith {};

MM_fnc_applyCbaSettings = {
    MM_var_showAllSides = MM_cba_showAllSides;
    MM_var_showAllSidesOnSpectator = MM_cba_showAllSidesOnSpectator;
    MM_var_showUnitNames = MM_cba_showUnitNames;
    MM_var_showUnitNamesOnlyOnHover = MM_cba_showUnitNamesOnlyOnHover;
    MM_var_showAliveGroupUnits = MM_cba_showAliveGroupUnits;
    MM_var_showOwnUnitOnly = MM_cba_showOwnUnitOnly;

    {
        publicVariable _x;
    } forEach [
        "MM_var_showAllSides",
        "MM_var_showAllSidesOnSpectator",
        "MM_var_showUnitNames",
        "MM_var_showUnitNamesOnlyOnHover",
        "MM_var_showAliveGroupUnits",
        "MM_var_showOwnUnitOnly"
    ];
};

if (_integrated) exitWith {};

MM_fnc_startCbaAddon = {
    if (MM_cba_enabled && {(allMissionObjects "moduleMapMarker") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "mapmarker\scripts\fn_init.sqf";
        call MM_fnc_applyCbaSettings;
        call MM_fnc_startMapMarkerServer;
    };
};
