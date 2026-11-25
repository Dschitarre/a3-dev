// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\entityculling\scripts\cbaSettings.sqf"}) exitWith {};

[
    "EC_cba_enabled",
    "CHECKBOX",
    ["Enable Entity Culling", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Entity Culling",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated) then {
    ["EC_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "Entity Culling", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "Entity Culling", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["EC_cba_frameBudget", "SLIDER", ["Frame budget (ms)", "Time per frame each client may spend on visibility tests; more budget keeps more entities hidden."], [0.25, 4, 1, 2]],
    ["EC_cba_minDistance", "SLIDER", ["Minimum distance (m)", "Entities closer to the camera or the player's unit / vehicle are never hidden (plus a margin for the camera's speed)."], [5, 100, 10, 0]],
    ["EC_cba_checkInterval", "SLIDER", ["Check interval (seconds)", "Minimum time between two checks of a visible entity."], [0.1, 1, 0.2, 1]],
    ["EC_cba_hideAfterChecks", "SLIDER", ["Hide after checks", "Invisible checks in a row before an entity is hidden (it is shown again at the first check that sees it)."], [1, 5, 3, 0]],
    ["EC_cba_lookahead", "SLIDER", ["Prediction (seconds)", "Camera and entity movement a check covers; hidden entities are checked again after half of it."], [0.3, 1, 0.5, 2]],
    ["EC_cba_debug", "CHECKBOX", ["Debug overlay", "Every client shows its hidden / checked entities, the worker's time per frame and its frame rate."], false]
];

if (!isServer) exitWith {};

EC_fnc_applyCbaSettings = {
    EC_var_minDistance = EC_cba_minDistance;
    EC_var_checkInterval = EC_cba_checkInterval;
    EC_var_hideAfterChecks = EC_cba_hideAfterChecks;
    EC_var_lookahead = EC_cba_lookahead;
    EC_var_debug = EC_cba_debug;
    EC_var_frameBudget = EC_cba_frameBudget / 1000;

    {
        publicVariable _x;
    } forEach [
        "EC_var_frameBudget",
        "EC_var_minDistance",
        "EC_var_checkInterval",
        "EC_var_hideAfterChecks",
        "EC_var_lookahead",
        "EC_var_debug"
    ];
};

if (_integrated) exitWith {};

EC_fnc_startCbaAddon = {
    if (EC_cba_enabled && {(allMissionObjects "moduleEntityCulling") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "entityculling\scripts\fn_init.sqf";
        call EC_fnc_applyCbaSettings;
        call EC_fnc_startEntityCullingServer;
    };
};
