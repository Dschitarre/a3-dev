{
    _clientFilePath = "modsIntegrated\" + _x + "\scripts\fnc_client.sqf";
    _clientServerFilePath = "modsIntegrated\" + _x + "\scripts\fnc_clientServer.sqf";
    _serverFilePath = "modsIntegrated\" + _x + "\scripts\fnc_server.sqf";

    if (fileExists _serverFilePath) then {
        call (compile (preprocessFileLineNumbers _serverFilePath));
    };

    if (fileExists _clientServerFilePath) then {
        call (compile (preprocessFileLineNumbers _clientServerFilePath));
    };
} forEach [
    "allowdamageglobal",
    "killfeed",
    "dynamicweather",
    "tdicons",
    "disablestamina",
    "disabletacticalview",
    "holster",
    "jump",
    "killfeed",
    "lagswitchdetection",
    "mapmarker"
];

{
    call (compile preprocessFileLineNumbers _x);
} forEach [
    "SC\gameMode\clientServer.sqf",
    "SC\gameMode\server\server.sqf",
    "SC\gameMode\server\serverLoops.sqf",
    "SC\gameMode\server\initKillfeed.sqf",
    "SC\ai\server.sqf",
    "SC\ai\serverLoops.sqf",
    "SC\ai\spawnAI.sqf",
    "SC\ai\spawnVehicle.sqf",
    "SC\rankSystem\clientServer.sqf",
    "SC\rankSystem\server.sqf",
    "SC\ai\initAIUnits.sqf",
    "SC\maps\applyMap.sqf",
    "SC\gameMode\server\initVars.sqf",
    "SC\gameMode\server\addActions.sqf",

    
    "SC\serverLoops.sqf"
];

showSubtitles false;
enableRadio false;
enableSentences false;
enableTeamSwitch false;
enableDynamicSimulationSystem false;

0 enableChannel [true, false];
1 enableChannel [true, false];
2 enableChannel false;
3 enableChannel [true, true];
4 enableChannel [true, true];
5 enableChannel [true, true];

["Initialize"] call BIS_fnc_dynamicGroups;
[missionNamespace, ((getMarkerPos ("SC_var_playZone")) vectorAdd [0, 0, 1600]), "Parachute"] call BIS_fnc_addRespawnPosition;

addMissionEventHandler ["EntityKilled", {_this call SC_fnc_EntityKilled;}];
addMissionEventHandler ["EntityRespawned", {_this call SC_fnc_EntityRespawned;}];
addMissionEventHandler ["HandleDisconnect", {_this call SC_fnc_HandleDisconnect;true}];

SC_var_playZoneLoopScript = [] spawn SC_fnc_playZoneAndVehicleCooldownLoop;
SC_var_gameModeLoopScript = [] spawn SC_fnc_gameModeLoop;
SC_var_weaponHolderLoopScript = [] spawn SC_fnc_weaponHolderLoop;
SC_var_aiLoopScript = [] spawn SC_fnc_aiLoop;
SC_var_suspendAiLoopScript = [] spawn SC_fnc_suspendAiLoop;
SC_var_groupLoopScript = [] spawn SC_fnc_aiGroupLoop;

[true] call DW_fnc_startDynamicWeather;
call DS_fnc_startDisableStaminaServer;
call DTV_fnc_startDisableTacticalViewServer;
call TDI_fnc_startTdIconsServer;
call H_fnc_startHolsterServer;
call J_fnc_startJumpServer;
call MM_fnc_startMapMarkerServer;

SC_var_serverInitDone = true;
publicVariable "SC_var_serverInitDone";