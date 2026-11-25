// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\earplugs\scripts\cbaSettings.sqf"}) exitWith {};

[
    "E_cba_enabled",
    "CHECKBOX",
    ["Enable Earplugs", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Earplugs",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

["E_cba_showIcon", "CHECKBOX", "Show the earplugs icon", "Earplugs", true] call CBA_fnc_addSetting;

if (_integrated) then {
    ["E_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "Earplugs", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "Earplugs", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["E_cba_volumeMuted", "SLIDER", ["Volume with earplugs (F1)", "Default game volume while the earplugs of the F1 key are in."], [0, 1, 0.3, 2]],
    ["E_cba_volumeGround", "SLIDER", ["Automatic earplugs in ground vehicles", "Sound level as a fraction. Set to -1 to disable automatic insertion in ground vehicles."], [-1, 1, 0.5, 2]],
    ["E_cba_volumeAir", "SLIDER", ["Automatic earplugs in aircraft", "Sound level as a fraction. Set to -1 to disable automatic insertion in aircraft."], [-1, 1, 0.3, 2]],
    ["E_cba_volumeBoat", "SLIDER", ["Automatic earplugs in boats", "Sound level as a fraction. Set to -1 to disable automatic insertion in boats."], [-1, 1, 0.5, 2]]
];

if (!isServer) exitWith {};

E_fnc_applyCbaSettings = {
    private _vehicleVolumes = [[E_cba_volumeGround, 0.5], [E_cba_volumeAir, 0.3], [E_cba_volumeBoat, 0.5]];
    E_var_defaultSettings = [
        E_cba_volumeMuted,
        _vehicleVolumes apply {(_x select 0) >= 0},
        _vehicleVolumes apply {
            _x params ["_volume", "_fallback"];
            [_volume, _fallback] select (_volume < 0)
        }
    ];
    publicVariable "E_var_defaultSettings";
};

if (_integrated) exitWith {};

E_fnc_startCbaAddon = {
    if (E_cba_enabled && {(allMissionObjects "moduleEarplugs") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "earplugs\scripts\fn_init.sqf";
        call E_fnc_applyCbaSettings;
        call E_fnc_startEarplugsServer;
    };
};
