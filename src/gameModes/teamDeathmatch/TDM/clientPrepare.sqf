DM_var_movementEH = nil;
DM_var_fireId = nil;
DM_var_earplugsOn = false;
DM_var_isInVehicleVision = false;
DM_var_nvGogglesEnabled = call DM_fnc_isNight;
DM_var_earplugsCooldown = 0;
DM_var_cameraViewLoopScript = scriptNull;
DM_var_gpsSet = false;

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

_loadout = getUnitLoadout player;

player setUnitTrait ["Engineer", true];
player setUnitTrait ["UAVHacker", true];
player setVariable ["DM_var_startLoadout", _loadout];
player setVariable ["DM_var_lastLoadout", _loadout];

[player] join grpNull;

["InitializePlayer", [player]] call BIS_fnc_dynamicGroups;
(["GUI"] call BIS_fnc_rscLayer) cutRsc["GUI", "PLAIN", 0, true];

player addEventHandler ["Killed", {_this call DM_fnc_killed;}];
player addEventHandler ["Respawn", {_this call DM_fnc_respawn;}];
player addEventHandler ["VisionModeChanged", {_this call DM_fnc_visionModeChanged;}];
addMissionEventHandler ["Map", {_this call DM_fnc_map;}];
[missionNamespace, "arsenalClosed", {_this call DM_fnc_arsenalClosed;}] call BIS_fnc_addScriptedEventHandler;
[missionNamespace, "arsenalOpened", {_this call DM_fnc_arsenalOpened;}] call BIS_fnc_addScriptedEventHandler;
disableSerialization;
(findDisplay 46) displayAddEventHandler ["KeyDown", {_this call DM_fnc_keyDownEarplugs}];

if !DM_var_loadoutsRestricted then {
    [] spawn {
        DM_var_equip = "Land_HelipadEmpty_F"
        createVehicleLocal [0, 0, 0];
        waitUntil {!(isNull DM_var_equip)};
        _hdl = ["AmmoboxInit", [DM_var_equip, true]] spawn BIS_fnc_arsenal;
    };
};

if (((getArray (missionConfigFile >> "params" >> "3rdPerson" >> "texts")) select ("3rdPerson" call BIS_fnc_getParamValue) == "Not allowed") && ((difficultyOption "thirdPersonView") == 1)) then {
    [] spawn DM_fnc_thirdPersonLoop;
    disableSerialization;
    (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call DM_fnc_keyDownThirdPerson}];
} else {
    DM_var_lastView = if ((difficultyOption "thirdPersonView") == 0) then {"INTERNAL"} else {"EXTERNAL"};
};

[] spawn {
    waitUntil {!(player getVariable "DM_var_isLoading")};

    [] spawn DM_fnc_guiLoop;
    [] spawn DM_fnc_movementLoop;
    [] spawn DM_fnc_spectatorNightVisionLoop;

    [] spawn {
        if (DM_var_respawnTime > 4) then {
            ["", 0, 0, 0, 0, 0, 1011] spawn BIS_fnc_dynamicText;
            [] spawn DM_fnc_spectator;
        } else {
            sleep 2;
            ["", 0, 0, 0, 0, 0, 1011] spawn BIS_fnc_dynamicText;
            [false] spawn DM_fnc_setToSpawn;
            [] spawn DM_fnc_resetLoadout;
            [objNull, objNull] call DM_fnc_respawn;
            cutText ["", "BLACK IN", 0, true];

            if DM_var_nvGogglesEnabled then {
                player action ["nvGoggles", player];
            };

            player enableInfoPanelComponent ["right", "MinimapDisplay", true];
            player enableInfoPanelComponent ["left", "MinimapDisplay", false];
            opengps true;
            player enableInfoPanelComponent ["left", "MinimapDisplay", true];
            DM_var_gpsSet = true;
        };

        [] spawn DM_fnc_respawnTimeLoop;
    };
};