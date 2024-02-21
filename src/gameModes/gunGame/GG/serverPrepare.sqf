enableRadio false;
enableSentences false;
showSubtitles false;
enableTeamSwitch false;
enableDynamicSimulationSystem false;

call GG_fnc_applyMap;

GG_var_loadout = getUnitLoadout (playableUnits select 0);
GG_var_leaderBoard = "";
GG_var_ended = false;
GG_var_unitsStats = [];

GG_var_mapScaleFactor = if (worldName == "Malden") then {
    1.3
} else {
    if (worldName == "Altis") then {
        0.5
    } else {
        if (worldName == "Stratis") then {
            2
        } else {
            1.1
        }
    }
};

_playZoneSize = getMarkerSize "GG_var_playZone";
GG_var_mapArea = (_playZoneSize select 0) * (_playZoneSize select 1);
if ((markerShape "GG_var_playZone") == "RECTANGLE") then {
    GG_var_mapArea = 4 * GG_var_mapArea;
} else {
    GG_var_mapArea = pi * GG_var_mapArea;
};
GG_var_wantedUnitAmount = 46 min (round (1.25 * (sqrt (sqrt GG_var_mapArea))));

GG_var_suspendAiLoopScript = scriptNull;
GG_var_suspendedUnits = playableUnits;

publicVariable "GG_var_mapScaleFactor";
publicVariable "GG_var_leaderBoard";

{
    _x addRating ((-3000) - (rating _x));

    _x setVariable ["GG_var_unitId", _forEachIndex];
    _x setVariable ["GG_var_lastSpawnPos", [0, 0, 0]];
    _x setVariable ["GG_var_weaponNum", 0, true];
    _x setVariable ["GG_var_deaths", 0, true];
    _x setVariable ["GG_var_aiSkill", 0.5 + random 0.3];

    [_x, ([_x] call GG_fnc_getAiNameArr)] remoteExecCall ["setName", 0, _x];

    [[_x], grpNull] remoteExecCall ["join", (groupOwner (group _x))];
} forEach GG_var_suspendedUnits;

DW_var_date = [2035, 07, 01] + (
    switch ((getArray (missionConfigFile >> "params" >> "startTime" >> "texts")) select ("startTime" call BIS_fnc_getParamValue)) do {
        case "Morning": {[6, 00]};
        case "Noon": {[12, 00]};
        case "Evening": {[18, 00]};
        case "Night": {[1, 00]};
    }
);

switch ((getArray (missionConfigFile >> "params" >> "weather" >> "texts")) select ("weather" call BIS_fnc_getParamValue)) do {
    case "Dynamic": {};
    case "Dynamic Foggy": {
        DW_var_minFogSunny = 0.1;
        DW_var_maxFogSunny = 0.2;
        DW_var_minFogStormy = 0.2;
        DW_var_maxFogStormy = 0.5;
    };
    case "Sun": {
        DW_var_maxOvercast = 0.35;
    };
    case "Clouds": {
        DW_var_minOvercast = 0.6;
        DW_var_maxOvercast = 0.7;
    };
    case "Storm": {
        DW_var_minRain = 0.5;
        DW_var_maxRain = 1.0;
        DW_var_minOvercast = 0.7;
        DW_var_minWindStormy = 0.6;
        DW_var_maxWindStormy = 1.0;
    };
};

_timeMultiplierDay = call compile ((getArray (missionConfigFile >> "params" >> "timeMultiplierDay" >> "texts")) select ("timeMultiplierDay" call BIS_fnc_getParamValue));
_timeMultiplierNight = call compile ((getArray (missionConfigFile >> "params" >> "timeMultiplierNight" >> "texts")) select ("timeMultiplierNight" call BIS_fnc_getParamValue));
DW_var_changeTimeMultiplierDay = _timeMultiplierDay;
DW_var_staticTimeMultiplierDay = _timeMultiplierDay;
DW_var_changeTimeMultiplierNight = _timeMultiplierNight;
DW_var_staticTimeMultiplierNight = _timeMultiplierNight;

DW_var_timeBetweenWeatherChangesMultiplierSunny = 0;
DW_var_timeBetweenWeatherChangesMultiplierStormy = 0;

DW_var_skipNight = "Enabled" == ((getArray (missionConfigFile >> "params" >> "skipNight" >> "texts")) select ("skipNight" call BIS_fnc_getParamValue));
publicVariable "DW_var_skipNight";

addMissionEventHandler ["HandleDisconnect", {_this call GG_fnc_HandleDisconnect;true}];
addMissionEventHandler ["EntityRespawned", {_this call GG_fnc_EntityRespawned;}];
addMissionEventHandler ["EntityKilled", {_this call GG_fnc_entityKilled;}];

GG_var_suspendAiLoopScript = [] spawn GG_fnc_suspendAiLoop;

[true] call DW_fnc_startDynamicWeather;

KF_var_ShowFriendlyFire = false;
KF_var_killInfoIncludeTK = true;
KF_var_killInfoDuration = 9999;
call KF_fnc_startKillfeed;

call DS_fnc_startDisableStaminaServer;
call DTV_fnc_startDisableTacticalViewServer;
call H_fnc_startHolsterServer;
call J_fnc_startJumpServer;
call AH_fnc_startAutoHealServer;

GG_var_serverInitDone = true;
publicVariable "GG_var_serverInitDone";