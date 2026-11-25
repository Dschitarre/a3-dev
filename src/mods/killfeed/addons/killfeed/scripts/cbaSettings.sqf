// Integrated missions register the same settings with their own defaults and start the mod themselves.
params [["_integrated", false, [true]]];

if (!_integrated && {fileExists "modsIntegrated\killfeed\scripts\cbaSettings.sqf"}) exitWith {};

[
    "KF_cba_enabled",
    "CHECKBOX",
    ["Enable Killfeed", "Applies when the mission starts. A placed Eden module controls the standalone mod in its mission."],
    "Killfeed",
    _integrated,
    1,
    {},
    true
] call CBA_fnc_addSetting;

["KF_cba_showKillFeed", "CHECKBOX", ["Show killfeed (client)", "Shows the killfeed on your screen when the server enables it."], "Killfeed", true, 0, {if (hasInterface && {!isNil "KF_fnc_drawKillFeed"}) then {call KF_fnc_drawKillFeed};}] call CBA_fnc_addSetting;

["KF_cba_showMidFeed", "CHECKBOX", ["Show midfeed (client)", "Shows personal kill and assist messages when the server enables them."], "Killfeed", true, 0, {if (hasInterface && {!isNil "KF_fnc_drawMidFeed"}) then {call KF_fnc_drawMidFeed};}] call CBA_fnc_addSetting;

["KF_cba_showDeathFeed", "CHECKBOX", ["Show deathfeed (client)", "Shows the report after your own death when the server enables it."], "Killfeed", true, 0, {if (hasInterface && {!isNil "KF_fnc_drawDeathFeed"}) then {call KF_fnc_drawDeathFeed};}] call CBA_fnc_addSetting;

["KF_cba_showKillCam", "CHECKBOX", ["Play kill cam (client)", "Plays the camera after your death when the server and the mission permit it."], "Killfeed", true] call CBA_fnc_addSetting;

if (_integrated) then {
    ["KF_cba_override", "CHECKBOX", ["Use CBA settings in integrated missions", "Use the server settings below for this addon in the mission. Takes effect at mission start."], "Killfeed", false, 1, {}, true] call CBA_fnc_addSetting;
};

{
    _x params ["_name", "_type", "_title", "_values"];
    [_name, _type, _title, "Killfeed", _values, 1, {}, true] call CBA_fnc_addSetting;
} forEach [
    ["KF_cba_assists", "CHECKBOX", ["Assists", "Toggles assist functionality."], true],
    ["KF_cba_showFriendlyFire", "CHECKBOX", ["Show 'Friendly Fire'", "Shows a red 'Friendly Fire' text in the midfeed and the deathfeed in case of friendly fire."], true],
    ["KF_cba_deathCausesInversed", "CHECKBOX", ["Invert order of death causes", "Flips the order of death causes."], true],
    ["KF_cba_multipleDeathCauses", "CHECKBOX", ["Show multiple death causes per line", "Toggles whether there can be multiple death causes displayed per line, in case the hitter hit the killed by multiple different means."], false],
    ["KF_cba_picturesHeadIcon", "CHECKBOX", ["Show head icon in case of headshot", "Toggles whether a head icon is displayed in front of the weapon, in case of a headshot."], true],
    ["KF_cba_picturesBulletIcon", "CHECKBOX", ["Show bullet icon", "Toggles whether a bullet icon is displayed between the head and the weapon, in case of a headshot."], true],
    ["KF_cba_showAiInNames", "CHECKBOX", ["Show AI in names", "Toggles whether ' (AI)' is appended to the names of AI units and vehicles."], true],
    ["KF_cba_killFeedEnabled", "CHECKBOX", ["Enable killfeed (server)", "Enables the shared feed of recent eliminations."], true],
    ["KF_cba_killFeedCooldown", "SLIDER", ["Killfeed cooldown (seconds)", "Determines for how long kills should be displayed in the killfeed."], [5, 60, 30, 0]],
    ["KF_cba_killFeedMaximumLength", "SLIDER", ["Maximum killfeed length", "Maximum number of kills displayed at one time in the killfeed."], [5, 60, 10, 0]],
    ["KF_cba_killFeedInversed", "CHECKBOX", ["Flip killer and killed", "Flips the positions of killer and killed in the killfeed."], true],
    ["KF_cba_midFeedEnabled", "CHECKBOX", ["Enable midfeed (server)", "Enables personal kill and assist messages."], true],
    ["KF_cba_midFeedCooldown", "SLIDER", ["Midfeed cooldown (seconds)", "Determines for how long kills should be displayed in the midfeed."], [5, 60, 10, 0]],
    ["KF_cba_midFeedMaximumLength", "SLIDER", ["Maximum midfeed length", "Maximum number of kills displayed at one time in the midfeed."], [5, 60, 10, 0]],
    ["KF_cba_midFeedYouColorYellow", "CHECKBOX", ["Yellow 'You' in the midfeed", "Toggles whether the text 'You' in 'You killed ...' should also be displayed in yellow in the midfeed."], true],
    ["KF_cba_midFeedAssists", "CHECKBOX", ["Show assists in the midfeed", "Toggles whether there should be assists displayed in the midfeed."], true],
    ["KF_cba_deathFeedEnabled", "CHECKBOX", ["Enable deathfeed (server)", "Enables the personal report after death."], true],
    ["KF_cba_killInfoDuration", "SLIDER", ["Kill-info duration (seconds)", "Determines for how long the kill-info should be displayed."], [5, 60, 20, 0]],
    ["KF_cba_killCamEnabled", "CHECKBOX", ["Kill cam", "After the own death by another unit the camera flies to the killer and circles him (skip: Space)."], true],
    ["KF_cba_killCamHoldDuration", "SLIDER", ["Kill cam duration (seconds)", "Seconds the kill cam stays on the killer."], [3, 10, 5, 0]],
    ["KF_cba_killCamMaxDistance", "SLIDER", ["Kill cam maximum distance (m)", "No kill cam for a killer farther away at the death (m)."], [100, 3000, 300, 0]],
    ["KF_cba_killCamAirMaxHeight", "SLIDER", ["Kill cam maximum aircraft height (m)", "No kill cam for a killer in an aircraft higher above the ground (m)."], [100, 10000, 300, 0]],
    ["KF_cba_killCamTeamKills", "CHECKBOX", ["Kill cam for team kills", "Also shows the kill cam when a friendly unit was the killer."], true],
    ["KF_cba_killCamRequireLineOfSight", "CHECKBOX", ["Kill cam only with line of sight", "Shows the kill cam only if the victim could have seen the killer."], false],
    ["KF_cba_killCamIndirectKills", "CHECKBOX", ["Kill cam for indirect kills", "Also shows the kill cam for kills by mortars, artillery, mines and placed explosives."], false],
    ["KF_cba_killInfoIncludeTK", "CHECKBOX", ["Include team kills in kill-info", "Count friendly kills toward the match-wide longest kill and longest kill streak records."], false],
    ["KF_cba_deathTransition", "CHECKBOX", ["Show death transition", "Allow the death transition when using the death display."], true],
    ["KF_cba_assistWindow", "SLIDER", ["Assist window (seconds)", "Time during which a hit can count toward an elimination or assist."], [1, 120, 30, 0]]
];

if (!isServer) exitWith {};

KF_fnc_applyCbaSettings = {
    KF_var_assists = KF_cba_assists;
    KF_var_showFriendlyFire = KF_cba_showFriendlyFire;
    KF_var_deathCausesInversed = KF_cba_deathCausesInversed;
    KF_var_multipleDeathCauses = KF_cba_multipleDeathCauses;
    KF_var_picturesHeadIcon = KF_cba_picturesHeadIcon;
    KF_var_picturesBulletIcon = KF_cba_picturesBulletIcon;
    KF_var_showAiInNames = KF_cba_showAiInNames;
    KF_var_killFeedEnabled = KF_cba_killFeedEnabled;
    KF_var_killFeedCooldown = KF_cba_killFeedCooldown;
    KF_var_killFeedMaximumLength = KF_cba_killFeedMaximumLength;
    KF_var_killFeedInversed = KF_cba_killFeedInversed;
    KF_var_midFeedEnabled = KF_cba_midFeedEnabled;
    KF_var_midFeedCooldown = KF_cba_midFeedCooldown;
    KF_var_midFeedMaximumLength = KF_cba_midFeedMaximumLength;
    KF_var_midFeedYouColorYellow = KF_cba_midFeedYouColorYellow;
    KF_var_midFeedAssists = KF_cba_midFeedAssists;
    KF_var_deathFeedEnabled = KF_cba_deathFeedEnabled;
    KF_var_killInfoDuration = KF_cba_killInfoDuration;
    KF_var_killCamEnabled = KF_cba_killCamEnabled;
    KF_var_killCamHoldDuration = KF_cba_killCamHoldDuration;
    KF_var_killCamMaxDistance = KF_cba_killCamMaxDistance;
    KF_var_killCamAirMaxHeight = KF_cba_killCamAirMaxHeight;
    KF_var_killCamTeamKills = KF_cba_killCamTeamKills;
    KF_var_killCamRequireLineOfSight = KF_cba_killCamRequireLineOfSight;
    KF_var_killCamIndirectKills = KF_cba_killCamIndirectKills;
    KF_var_killInfoIncludeTK = KF_cba_killInfoIncludeTK;
    KF_var_deathTransition = KF_cba_deathTransition;
    KF_var_assistWindow = KF_cba_assistWindow;
};

if (_integrated) exitWith {};

KF_fnc_startCbaAddon = {
    if (KF_cba_enabled && {(allMissionObjects "moduleKillfeed") isEqualTo []}) then {
        call compile preprocessFileLineNumbers "killfeed\scripts\fn_init.sqf";
        call KF_fnc_applyCbaSettings;
        call KF_fnc_startKillfeed;
    };
};
