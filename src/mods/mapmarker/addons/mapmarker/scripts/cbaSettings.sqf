// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\mapmarker\scripts\cbaSettings.sqf"}) exitWith {};

[
    "MM_cba_enabled",
    "CHECKBOX",
    ["Enable Map Marker", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "Map Marker"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

["MM_cba_showMarkers", "CHECKBOX", "Show map markers", ["Dschitarre", "Map Marker"], true] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (MM_cba_enabled && {(allMissionObjects "moduleMapMarker") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "mapmarker\scripts\fn_init.sqf";
        call MM_fnc_startMapMarkerServer;
    };
}] call CBA_fnc_addEventHandler;
