GG_var_cameraViewLoopScript = scriptNull;
GG_var_playZoneLoopScript = scriptNull;
GG_var_spawnPlayerScript = scriptNull;
GG_var_guiLoopScript = scriptNull;
GG_var_nvGogglesEnabled = call GG_fnc_isNight;
GG_var_isInVehicleVision = false;

setViewDistance 1300;
setObjectViewDistance 1100;
setTerrainGrid 0.78125;
showSubtitles false;
enableRadio false;
enableSentences false;
enableTeamSwitch false;
enableDynamicSimulationSystem false;

0 enableChannel [true, false];
1 enableChannel [true, false];
2 enableChannel [false, false];

[player] join grpNull;
(["GG_var_GUI"] call BIS_fnc_rscLayer) cutRsc ["GG_var_GUI", "PLAIN", 0, true];
player addRating ((-3000) - (rating player));

GG_var_lastSpawnPos = [0, 0, 0];
GG_var_loadout = getUnitLoadout player;

player addEventHandler ["Killed", {_this call GG_fnc_killed;}];
player addEventHandler ["Respawn", {_this call GG_fnc_respawn;}];
player addEventHandler ["Take", {_this call GG_fnc_take;}];
player addEventHandler ["FiredMan", {_this call GG_fnc_firedMan;}];
player addEventHandler ["InventoryOpened", {["inventoryDisabled"] call Bis_fnc_ShowNotification;true}];
player addEventHandler ["VisionModeChanged", {_this call GG_fnc_visionModeChanged;}];

addMissionEventHandler ["Map", {_this call GG_fnc_map;}];

if ((((getArray (missionConfigFile >> "params" >> "thirdPerson" >> "texts")) select ("thirdPerson" call BIS_fnc_getParamValue)) == "Disabled") && ((difficultyOption "thirdPersonView") == 1)) then {
    GG_var_forceFPPLoopScript = [] spawn GG_fnc_forceFPPLoop;
    (findDisplay 46) displayAddEventHandler ["KeyDown", {params ["", "_key"]; if (_key in (actionKeys "personView")) then {true};}];
} else {
    GG_var_lastView = if ((difficultyOption "thirdPersonView") == 0) then {"INTERNAL"} else {"EXTERNAL"};
};

call GG_fnc_refreshLeaderBoardClient;
"GG_var_leaderBoard" addPublicVariableEventHandler {call GG_fnc_refreshLeaderBoardClient;};

GG_var_guiLoopScript = [] spawn GG_fnc_guiLoop;
[] spawn GG_fnc_spectatorNightVisionLoop;

[] spawn {
    sleep 2;
    [] spawn GG_fnc_respawnScreen;
    waitUntil {(simulationEnabled player) && {alive player} && {player inArea "GG_var_playZone"}};
    player setVariable ["GG_var_lastPos", (getPosATL player)];

    player enableInfoPanelComponent ["right", "MinimapDisplay", true];
    player enableInfoPanelComponent ["left", "MinimapDisplay", false];
    opengps true;
    player enableInfoPanelComponent ["left", "MinimapDisplay", true];
};