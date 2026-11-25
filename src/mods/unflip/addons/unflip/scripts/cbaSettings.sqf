// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\unflip\scripts\cbaSettings.sqf"}) exitWith {};

[
    "UF_cba_enabled",
    "CHECKBOX",
    ["Enable Unflip", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Unflip",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated) then {
    ["UF_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "Unflip", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "Unflip", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["UF_cba_maxDistance", "SLIDER", ["Reach (m)", "Maximum distance between the player's eyes and the vehicle's outline."], [3, 10, 6, 0]],
    ["UF_cba_minTilt", "SLIDER", ["Flipped from (degrees)", "Tilt from which a vehicle counts as flipped (0 = upright, 90 = on its side, 180 = on its roof)."], [45, 85, 65, 0]],
    ["UF_cba_durationMin", "SLIDER", ["Hold duration (light) (seconds)", "Seconds of holding for light vehicles (quad bike); heavier ones take longer, up to the duration for heavy vehicles."], [1, 8, 3, 0]],
    ["UF_cba_durationMax", "SLIDER", ["Hold duration (heavy) (seconds)", "Seconds of holding for heavy vehicles (tanks)."], [3, 15, 8, 0]],
    ["UF_cba_damageProtection", "SLIDER", ["Damage protection (seconds)", "Seconds an unflipped vehicle takes no damage, so it cannot break when it lands."], [0, 5, 2, 0]],
    ["UF_cba_aiAutoUnflip", "CHECKBOX", ["Unflip AI vehicles", "The server unflips the vehicles of the AI on its own when they have been flipped for a while."], true],
    ["UF_cba_aiDelay", "SLIDER", ["AI vehicles: delay (seconds)", "Seconds an AI vehicle must have been flipped (and standing still) before the server unflips it."], [5, 60, 10, 0]],
    ["UF_cba_maxSpeed", "SLIDER", ["Maximum eligible speed (m/s)", "Vehicles moving faster are still sliding or tumbling and cannot be righted."], [0, 5, 1, 2]],
    ["UF_cba_massLight", "SLIDER", ["Light vehicle mass (kg)", "At or below this mass the light hold duration applies."], [1, 5000, 500, 0]],
    ["UF_cba_massHeavy", "SLIDER", ["Heavy vehicle mass (kg)", "At or above this mass the heavy hold duration applies."], [5001, 150000, 40000, 0]],
    ["UF_cba_aiCheckInterval", "SLIDER", ["AI check interval (seconds)", "Time between server checks for overturned AI vehicles."], [1, 30, 3, 1]]
];

if (!isServer) exitWith {};

UF_fnc_applyCbaSettings = {
    UF_var_maxDistance = UF_cba_maxDistance;
    UF_var_minTilt = UF_cba_minTilt;
    UF_var_durationMin = UF_cba_durationMin min UF_cba_durationMax;
    UF_var_durationMax = UF_cba_durationMin max UF_cba_durationMax;
    UF_var_damageProtection = UF_cba_damageProtection;
    UF_var_aiAutoUnflip = UF_cba_aiAutoUnflip;
    UF_var_aiDelay = UF_cba_aiDelay;
    UF_var_maxSpeed = UF_cba_maxSpeed;
    UF_var_massLight = UF_cba_massLight;
    UF_var_massHeavy = UF_cba_massHeavy;
    UF_var_aiCheckInterval = UF_cba_aiCheckInterval;
};

if (_integrated) exitWith {};

UF_fnc_startCbaAddon = {
    if (UF_cba_enabled && {(allMissionObjects "moduleUnflip") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "unflip\scripts\fn_init.sqf";
        call UF_fnc_applyCbaSettings;
        call UF_fnc_startUnflipServer;
    };
};
