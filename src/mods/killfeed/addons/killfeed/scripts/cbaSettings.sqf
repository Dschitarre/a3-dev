// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\killfeed\scripts\cbaSettings.sqf"}) exitWith {};

[
    "KF_cba_enabled",
    "CHECKBOX",
    ["Enable Killfeed", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    ["Dschitarre", "Killfeed"],
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

["KF_cba_showKillFeed", "CHECKBOX", "Show the killfeed", ["Dschitarre", "Killfeed"], true, 0, {if (hasInterface && {!isNil "KF_fnc_drawKillFeed"}) then {call KF_fnc_drawKillFeed};}] call CBA_fnc_addSetting;

["KF_cba_showMidFeed", "CHECKBOX", "Show the midfeed", ["Dschitarre", "Killfeed"], true, 0, {if (hasInterface && {!isNil "KF_fnc_drawMidFeed"}) then {call KF_fnc_drawMidFeed};}] call CBA_fnc_addSetting;

["KF_cba_showDeathFeed", "CHECKBOX", "Show the deathfeed", ["Dschitarre", "Killfeed"], true, 0, {if (hasInterface && {!isNil "KF_fnc_drawDeathFeed"}) then {call KF_fnc_drawDeathFeed};}] call CBA_fnc_addSetting;

if (_integrated || {!isServer}) exitWith {};

["CBA_settingsInitialized", {
    if (KF_cba_enabled && {(allMissionObjects "moduleKillfeed") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "killfeed\scripts\fn_init.sqf";
        call KF_fnc_startKillfeed;
    };
}] call CBA_fnc_addEventHandler;
