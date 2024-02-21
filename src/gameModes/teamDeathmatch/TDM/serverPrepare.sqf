DM_var_westPoints = 0;
DM_var_eastPoints = 0;
DM_var_roundNumber = 1;

DM_var_roundHdl = scriptNull;
DM_var_timerHdl = nil;
DM_var_gameRunning = false;
DM_var_watchedUnits = [];
DM_var_timerStr = "0:00";
DM_var_movingEnabled = true;
DM_var_respawnTime = 9999;
DM_var_zoneShrinkRatio = 0.7;

DM_var_aiMode = "ai" call BIS_fnc_getParamValue;

DM_var_suspendedUnitsWest = playableUnits select {(side _x) == west};
DM_var_suspendedUnitsEast = playableUnits select {(side _x) == east};

{
    {
        [_x, ([_x] call DM_fnc_getAiNameArr)] remoteExecCall ["setName", 0, _x];
        _x setVariable ["DM_var_unitId", _forEachIndex];
        _x setVariable ["DM_var_aiSkill", 0.5 + random 0.3];
        [[_x], grpNull] remoteExecCall ["join", (groupOwner (group _x))];
    } forEach _x;
} forEach [DM_var_suspendedUnitsWest, DM_var_suspendedUnitsEast];

DM_fnc_playZoneLoopHdl = scriptNull;

publicVariable "DM_var_westPoints";
publicVariable "DM_var_eastPoints";
publicVariable "DM_var_timerStr";
publicVariable "DM_var_movingEnabled";
publicVariable "DM_var_respawnTime";
publicVariable "DM_var_gameRunning";
publicVariable "DM_var_roundNumber";

MM_var_restrictUnitIcons = true;
publicVariable "MM_var_restrictUnitIcons";

enableRadio false;
enableSentences false;
showSubtitles false;
enableTeamSwitch false;
enableDynamicSimulationSystem false;

setTimeMultiplier (call compile ((getArray (missionConfigFile >> "params" >> "timeMultiplier" >> "texts")) select ("timeMultiplier" call BIS_fnc_getParamValue)));

setDate (
    [2035, 06, 01] + (
        switch ((getArray (missionConfigFile >> "params" >> "startTime" >> "texts")) select ("startTime" call BIS_fnc_getParamValue)) do {
            case "Morning": {[5, 00]};
            case "Noon": {[12, 00]};
            case "Evening": {[19, 00]};
            case "Night": {[1, 00]};
        }
    )
);

["Initialize"] call BIS_fnc_dynamicGroups;

DM_var_mapScaleFactor = switch worldName do {
    case "Malden": {1.3};
    case "Altis": {0.5};
    case "Stratis": {2};
};
publicVariable "DM_var_mapScaleFactor";

DM_var_loadoutsRestricted = (getArray (missionConfigFile >> "params" >> "loadouts" >> "texts")) select ("loadouts" call BIS_fnc_getParamValue) == "Restricted";
publicVariable "DM_var_loadoutsRestricted";

DM_var_autoHealEnabled = ((getArray (missionConfigFile >> "params" >> "autoHeal" >> "texts")) select ("autoHeal" call BIS_fnc_getParamValue)) == "Enabled";
publicVariable "DM_var_autoHealEnabled";

DM_var_minPointsToWin = (parseNumber (((getArray (missionConfigFile >> "params" >> "winCondition" >> "texts")) select ("winCondition" call BIS_fnc_getParamValue)) select [8, 3]) + 1) / 2;
DM_var_requireLeadOfTwoPoints = (getArray (missionConfigFile >> "params" >> "requireLeadOfTwoPoints" >> "texts")) select ("requireLeadOfTwoPoints" call BIS_fnc_getParamValue) == "Enabled";

DM_var_vehicleType = switch ((getArray (missionConfigFile >> "params" >> "vehicleType" >> "texts")) select ("vehicleType" call BIS_fnc_getParamValue)) do {
    case "No Vehicles": {"No Vehicles"};
    case "Quadbike": {"B_Quadbike_01_F"};
    case "Hatchback (Sport)": {"C_Hatchback_01_sport_F"};
    case "Ifrit": {"O_MRAP_02_F"};
    case "Hunter": {"B_MRAP_01_F"};
    case "Strider": {"I_MRAP_03_F"};
};

DM_var_vehiclesEnabled = DM_var_vehicleType != "No Vehicles";
DM_var_vehicleAmount = (getArray (missionConfigFile >> "params" >> "vehicleAmount" >> "texts")) select ("vehicleAmount" call BIS_fnc_getParamValue);

_zoneValue = (getArray (missionConfigFile >> "params" >> "zoneShrinkSpeed" >> "texts")) select ("zoneShrinkSpeed" call BIS_fnc_getParamValue);

DM_var_zoneShrinkEnabled = _zoneValue != "Disabled";

if DM_var_zoneShrinkEnabled then {
    DM_var_zoneShrinkSpeed = switch _zoneValue do {
        case "Slow": {1.3};
        case "Normal": {1};
        case "Fast": {0.7};
    };
};

DM_var_alternatingMaps = false;
DM_var_randomMapRotation = [];

_mapValues = getArray (missionConfigFile >> "params" >> "MapName" >> "texts");
_mapSetting = _mapValues select ("MapName" call BIS_fnc_getParamValue);

DM_var_mapNames = _mapValues select [2, (count _mapValues) - 2];

if (_mapSetting == "Alternating Maps") then {
    DM_var_alternatingMaps = true;
    _numberOfMaps = ((DM_var_minPointsToWin + 1) / 2) min (count DM_var_mapNames);
    _remainingMaps = DM_var_mapNames;

    for "_i" from 1 to _numberOfMaps do {
        _randomMap = selectRandom _remainingMaps;
        _remainingMaps = _remainingMaps - [_randomMap];
        DM_var_randomMapRotation pushBack _randomMap;
    };
} else {
    if (_mapSetting == "1 Random Map") then {
        _mapSetting = selectRandom DM_var_mapNames;
    };

    [_mapSetting, false] call DM_fnc_applyMap;
};

TDI_var_ShowAllSidesOnSpectator = ((getArray (missionConfigFile >> "params" >> "specSettings" >> "texts")) select ("specSettings" call BIS_fnc_getParamValue)) != "Own Team";
RscSpectator_allowFreeCam = TDI_var_ShowAllSidesOnSpectator;
publicVariable "TDI_var_ShowAllSidesOnSpectator";
publicVariable "RscSpectator_allowFreeCam";
call TDI_fnc_startTdIconsServer;

call KF_fnc_startKillfeed;
call DS_fnc_startDisableStaminaServer;
call DTV_fnc_startDisableTacticalViewServer;
call H_fnc_startHolsterServer;
call J_fnc_startJumpServer;
call MM_fnc_startMapMarkerServer;

_timeMultiplierDay = call compile ((getArray (missionConfigFile >> "params" >> "timeMultiplierDay" >> "texts")) select ("timeMultiplierDay" call BIS_fnc_getParamValue));
_timeMultiplierNight = call compile ((getArray (missionConfigFile >> "params" >> "timeMultiplierNight" >> "texts")) select ("timeMultiplierNight" call BIS_fnc_getParamValue));
DW_var_changeTimeMultiplierDay = _timeMultiplierDay;
DW_var_staticTimeMultiplierDay = _timeMultiplierDay;
DW_var_changeTimeMultiplierNight = _timeMultiplierNight;
DW_var_staticTimeMultiplierNight = _timeMultiplierNight;
DW_var_skipNight = "Enabled" == ((getArray (missionConfigFile >> "params" >> "skipNight" >> "texts")) select ("skipNight" call BIS_fnc_getParamValue));

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

DW_var_date = [2035, 06, 01] + (
    switch ((getArray (missionConfigFile >> "params" >> "startTime" >> "texts")) select ("startTime" call BIS_fnc_getParamValue)) do {
        case "Morning": {[6, 00]};
        case "Noon": {[12, 00]};
        case "Evening": {[18, 00]};
        case "Night": {[1, 00]};
    }
);

addMissionEventHandler ["EntityRespawned", {_this call DM_fnc_EntityRespawned;}];

[true] call DW_fnc_startDynamicWeather;

if DM_var_autoHealEnabled then {
    call AH_fnc_startAutoHealServer;
};

DM_var_serverInitDone = true;
publicVariable "DM_var_serverInitDone";

[] spawn DM_fnc_gameModeLoop;