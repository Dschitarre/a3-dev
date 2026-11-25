// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\magrepack\scripts\cbaSettings.sqf"}) exitWith {};

[
    "MR_cba_enabled",
    "CHECKBOX",
    ["Enable Magazine Repack", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Magazine Repack",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

if (_integrated) then {
    ["MR_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "Magazine Repack", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "Magazine Repack", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["MR_cba_secondsPerRound", "SLIDER", ["Time per round (seconds)", "Time a player needs to move one round from one magazine into another."], [0.05, 0.3, 0.12, 2]],
    ["MR_cba_aiRepack", "CHECKBOX", ["AI repacks", "AI units repack their magazines instantly from time to time when they are not in combat."], true],
    ["MR_cba_aiInterval", "SLIDER", ["AI repack interval (seconds)", "Time between two repacks of the AI units."], [15, 300, 60, 0]]
];

if (!isServer) exitWith {};

MR_fnc_applyCbaSettings = {
    MR_var_secondsPerRound = MR_cba_secondsPerRound;
    MR_var_aiRepack = MR_cba_aiRepack;
    MR_var_aiInterval = MR_cba_aiInterval;
};

if (_integrated) exitWith {};

MR_fnc_startCbaAddon = {
    if (MR_cba_enabled && {(allMissionObjects "moduleMagRepack") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "magrepack\scripts\fn_init.sqf";
        call MR_fnc_applyCbaSettings;
        call MR_fnc_startMagRepackServer;
    };
};
