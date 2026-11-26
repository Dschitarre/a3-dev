// Team Deathmatch start-up (server and client): server init, taking over a unit as player, disconnects, client setup.
// Also holds the match tuning values (equip phase, zone and round time limit are lobby params, TDM\params.hpp).

DM_var_respawnDelay = 4;            // respawn time while respawning is allowed (warmup, between rounds)
DM_var_noRespawnTime = 9999;        // respawn time that disables respawning during a round
DM_var_roundEndDelay = 3;
DM_var_readyTimeout = 20;           // the ready check waits at most this long for a hanging player
DM_var_readyPollInterval = 0.25;    // server polling of player readiness (scans all players)
DM_var_roundEndPollInterval = 0.1;  // server polling of "one team dead" (scans all units)
DM_var_hudCountInterval = 0.2;      // HUD alive-unit counts (scan all units)

// ---- server init ----

DM_fnc_initServer = {
    call DM_fnc_readParamsServer;
    call DM_fnc_initRoundStateServer;
    call DM_fnc_initAiPoolServer;

    MM_var_restrictUnitIcons = true;
    publicVariable "MM_var_restrictUnitIcons";

    call CMN_fnc_disableEngineFeatures;
    ["Initialize"] call BIS_fnc_dynamicGroups;

    DM_var_mapScaleFactor = call CMN_fnc_mapScaleFactor;
    publicVariable "DM_var_mapScaleFactor";

    call DM_fnc_initMapsServer;
    call DM_fnc_startModsServer;

    // true: the unit stays and becomes server AI (DM_fnc_handleDisconnect sets it up)
    addMissionEventHandler ["HandleDisconnect", {_this call DM_fnc_handleDisconnect; true}];
    addMissionEventHandler ["EntityRespawned", {_this call DM_fnc_entityRespawned}];

    // warmup arsenal (everything unlocked); clients apply DM_var_arsenalItems in DM_fnc_setupPlayer
    if (DM_var_loadoutsRestricted) then {
        [DM_var_maxRelRoundNumber] call DM_fnc_setArsenalItemsServer;
    } else {
        DM_var_arsenalItems = [];
        publicVariable "DM_var_arsenalItems";
    };

    DM_var_serverInitDone = true;
    publicVariable "DM_var_serverInitDone";

    [] spawn DM_fnc_gameModeLoop;
};

// lobby params (values[] in TDM\params.hpp); the map param is read in DM_fnc_initMapsServer
DM_fnc_readParamsServer = {
    DM_var_aiMode = "ai" call BIS_fnc_getParamValue;

    // loadouts: 0 Not restricted, 1 Restricted
    DM_var_loadoutsRestricted = ("loadouts" call BIS_fnc_getParamValue) == 1;
    publicVariable "DM_var_loadoutsRestricted";

    // autoHeal: 0 Disabled, 1 Enabled
    DM_var_autoHealEnabled = ("autoHeal" call BIS_fnc_getParamValue) == 1;
    publicVariable "DM_var_autoHealEnabled";

    // winCondition: values[] 0..10 -> "Best of N"
    private _bestOf = [1, 3, 5, 7, 11, 15, 23, 31, 47, 63, 127] select ("winCondition" call BIS_fnc_getParamValue);
    DM_var_minPointsToWin = (_bestOf + 1) / 2;
    publicVariable "DM_var_minPointsToWin";

    // requireLeadOfTwoPoints: 0 Disabled, 1 Enabled (public: HUD round info)
    DM_var_requireLeadOfTwoPoints = ("requireLeadOfTwoPoints" call BIS_fnc_getParamValue) == 1;
    publicVariable "DM_var_requireLeadOfTwoPoints";

    // vehicleType: 0 No Vehicles, 1 Quadbike, 2 Hatchback (Sport), 3 Ifrit, 4 Hunter, 5 Strider
    DM_var_vehicleType = ["", "B_Quadbike_01_F", "C_Hatchback_01_sport_F", "O_MRAP_02_F", "B_MRAP_01_F", "I_MRAP_03_F"] select ("vehicleType" call BIS_fnc_getParamValue);
    DM_var_vehiclesEnabled = DM_var_vehicleType != "";

    // vehicleAmount: 0 One per Team, 1 One per 2 Players (at least one), 2 One per Player
    DM_var_vehicleAmount = "vehicleAmount" call BIS_fnc_getParamValue;

    // zoneShrinkSpeed: 0 Slow, 1 Normal, 2 Fast, 3 Disabled
    private _zoneShrinkSpeed = "zoneShrinkSpeed" call BIS_fnc_getParamValue;
    DM_var_zoneShrinkEnabled = _zoneShrinkSpeed != 3;

    if (DM_var_zoneShrinkEnabled) then {
        DM_var_zoneShrinkSpeed = [1.3, 1, 0.7] select _zoneShrinkSpeed;
    };

    // seconds; roundTimeLimit 0 = no limit
    DM_var_equipPhaseDuration = "equipPhaseDuration" call BIS_fnc_getParamValue;
    DM_var_zoneShrinkDelay = "zoneShrinkDelay" call BIS_fnc_getParamValue;
    DM_var_roundTimeLimit = "roundTimeLimit" call BIS_fnc_getParamValue;

    // zoneDamage: HP (= damage / 100) per second outside of the zone
    DM_var_zoneDamage = ("zoneDamage" call BIS_fnc_getParamValue) / 100;
};

DM_fnc_initRoundStateServer = {
    DM_var_westPoints = 0;
    DM_var_eastPoints = 0;
    DM_var_roundNumber = 1;
    DM_var_gameRunning = false;
    DM_var_timerStr = "0:00";
    DM_var_movingEnabled = true;
    DM_var_respawnTime = DM_var_noRespawnTime;
    DM_var_inWarmup = true;
    DM_var_repeatRound = false;         // the last round was a draw and is played again

    DM_var_roundHdl = scriptNull;
    DM_var_timerHdl = scriptNull;
    DM_var_vehicleLoopHdl = scriptNull;
    DM_var_playZoneLoopHdl = scriptNull;
    DM_var_aiBalanceHdl = scriptNull;
    DM_var_watchedUnits = [];
    DM_var_teamVehicles = [];

    {
        publicVariable _x;
    } forEach [
        "DM_var_westPoints",
        "DM_var_eastPoints",
        "DM_var_roundNumber",
        "DM_var_gameRunning",
        "DM_var_timerStr",
        "DM_var_movingEnabled",
        "DM_var_respawnTime",
        "DM_var_inWarmup"
    ];
};

/*
    The playable units are the AI pool. Every slot gets its id (pool order) and mission loadout; only units no
    player controls become AI, so players connected at mission start (rotation, #restart) keep their unit.
*/
DM_fnc_initAiPoolServer = {
    {
        private _side = _x;

        {
            _x setVariable ["DM_var_unitId", _forEachIndex];
            _x setVariable ["DM_var_slotLoadout", getUnitLoadout _x];
        } forEach (playableUnits select {side _x == _side});
    } forEach [west, east];

    DM_var_suspendedUnitsWest = playableUnits select {side _x == west && {!isPlayer _x}};
    DM_var_suspendedUnitsEast = playableUnits select {side _x == east && {!isPlayer _x}};

    {
        [_x] call CMN_fnc_initAiUnit;
    } forEach (DM_var_suspendedUnitsWest + DM_var_suspendedUnitsEast);
};

DM_fnc_startModsServer = {
    // specSettings: 0 Own Team, 1 Everyone
    TDI_var_showAllSidesOnSpectator = ("specSettings" call BIS_fnc_getParamValue) == 1;
    RscSpectator_allowFreeCam = TDI_var_showAllSidesOnSpectator;
    publicVariable "TDI_var_showAllSidesOnSpectator";
    publicVariable "RscSpectator_allowFreeCam";
    TDI_var_showGroupIcons = true;
    publicVariable "TDI_var_showGroupIcons";
    DM_var_tdIconsEnabled = missionNamespace getVariable ["TDI_cba_enabled", true];
    publicVariable "DM_var_tdIconsEnabled";
    if (DM_var_tdIconsEnabled) then {
        call TDI_fnc_startTdIconsServer;
    };

    // kill cam: none once a round is decided (the warmup has no rounds)
    KF_fnc_killCamRoundOver = {!DM_var_gameRunning && {!DM_var_inWarmup}};
    if (missionNamespace getVariable ["KF_cba_enabled", true]) then {
        call KF_fnc_startKillfeed;
    };
    if (missionNamespace getVariable ["DS_cba_enabled", true]) then {
        call DS_fnc_startDisableStaminaServer;
    };
    if (missionNamespace getVariable ["DTV_cba_enabled", true]) then {
        call DTV_fnc_startDisableTacticalViewServer;
    };
    if (missionNamespace getVariable ["E_cba_enabled", true]) then {
        call E_fnc_startEarplugsServer;
    };
    if (missionNamespace getVariable ["H_cba_enabled", true]) then {
        call H_fnc_startHolsterServer;
    };
    if (missionNamespace getVariable ["UF_cba_enabled", true]) then {
        call UF_fnc_startUnflipServer;
    };
    if (missionNamespace getVariable ["MR_cba_enabled", true]) then {
        call MR_fnc_startMagRepackServer;
    };
    if (missionNamespace getVariable ["J_cba_enabled", true]) then {
        call J_fnc_startJumpServer;
    };
    if (missionNamespace getVariable ["MM_cba_enabled", true]) then {
        call MM_fnc_startMapMarkerServer;
    };

    // skipNight: 0 Disabled, 1 Enabled
    [[2035, 6, 1], ("skipNight" call BIS_fnc_getParamValue) == 1] call CMN_fnc_applyWorldParams;
    if (missionNamespace getVariable ["DW_cba_enabled", true]) then {
        [true] call DW_fnc_startDynamicWeather;
    };

    if (DM_var_autoHealEnabled) then {
        if (missionNamespace getVariable ["AH_cba_enabled", true]) then {
            call AH_fnc_startAutoHealServer;
        };
    };
};

// ---- player takeover (server) ----

/*
    remoteExec'd by DM_fnc_initClient. The one place where a unit becomes a player unit, for a JIP player taking
    over a pool AI as well as for a player who had the unit at mission start. Idempotent.
    _takenOverState: [posATL, dir, loadout, damage, vehicle] of the unit when the client took it over, [] if it was
    not a living, simulated unit. A JIP player who took over a fighting AI during a round spectates until the next
    round, so a pool unit takes the AI's place and the team keeps its strength.
*/
DM_fnc_initPlayerServer = {
    params ["_player", ["_playerName", ""], ["_takenOverState", []]];

    if (isNull _player) exitWith {};

    private _wasFightingAi = DM_var_gameRunning &&
        {_takenOverState isNotEqualTo []} &&
        {(_player getVariable ["CMN_var_aiNameJipId", ""]) isNotEqualTo ""};

    DM_var_suspendedUnitsWest = DM_var_suspendedUnitsWest - [_player];
    DM_var_suspendedUnitsEast = DM_var_suspendedUnitsEast - [_player];
    [_player, _playerName] call CMN_fnc_initPlayerUnit;

    // the slot's mission loadout, not whatever an AI was wearing in it
    _player setVariable ["DM_var_startLoadout", _player getVariable ["DM_var_slotLoadout", getUnitLoadout _player], true];
    _player setVariable ["DM_var_arsenalOpened", false, true];

    if (_wasFightingAi) then {
        [side group _player, _takenOverState] call DM_fnc_replaceAi;
    };
};

// ---- disconnects (server) ----

/*
    "HandleDisconnect" (returns true, so the unit stays as server AI). During a round a living unit fights on as a
    real AI; otherwise (or when it was parked as spectator) it goes back into the pool, which DM_fnc_aiBalanceLoop
    refills from. A dead unit respawns and is parked by DM_fnc_entityRespawned.
*/
DM_fnc_handleDisconnect = {
    params ["_unit"];

    [_unit] spawn {
        params ["_unit"];

        // the engine hands the unit to the server after this event
        private _timeout = time + 10;

        waitUntil {
            sleep 0.1;
            isNull _unit || {!isPlayer _unit && {local _unit}} || {time > _timeout}
        };

        if (isNull _unit || {isPlayer _unit} || {!local _unit}) exitWith {};

        [_unit] call CMN_fnc_initAiUnit;

        if (!alive _unit) exitWith {};

        if (DM_var_gameRunning && {simulationEnabled _unit}) exitWith {
            // CMN_fnc_initAiUnit moves the unit into its own group (remoteExec): combat settings go to that group
            _timeout = time + 3;

            waitUntil {
                sleep 0.1;
                (units group _unit) isEqualTo [_unit] || {time > _timeout}
            };

            _unit setSkill ([_unit] call CMN_fnc_aiSkill);
            _unit setVariable ["CMN_var_aiScript", [_unit] spawn DM_fnc_aiFight];
        };

        [_unit] call DM_fnc_suspendUnit;
    };
};

// ---- client init ----

// server state the client setup reads
DM_var_clientServerVars = [
    "DM_var_maxZoneSize",
    "DM_var_mapScaleFactor",
    "DM_var_gameRunning",
    "DM_var_respawnTime",
    "DM_var_movingEnabled",
    "DM_var_timerStr",
    "DM_var_loadoutsRestricted",
    "DM_var_autoHealEnabled",
    "DM_var_eastPoints",
    "DM_var_westPoints",
    "DM_var_roundNumber",
    "DM_var_minPointsToWin",
    "DM_var_requireLeadOfTwoPoints",
    "DM_var_inWarmup",
    "DM_var_arsenalItems"
];

/*
    Scheduled (initPlayerLocal.sqf): park the player until the server has taken the unit over, then set it up.
    The state of the unit before parking goes to the server, which puts a pool unit in the place of a fighting AI.
*/
DM_fnc_initClient = {
    private _takenOverState = [];

    if (alive player && {simulationEnabled player}) then {
        _takenOverState = [getPosATL player, getDir player, getUnitLoadout player, damage player, objectParent player];
    };

    [player, false] call CMN_fnc_setSimulationGlobal;
    0 fadeSound 0;
    player setPos [0, 0, 100];

    // earplugs mod: while the unit is not simulated (loading, benched, spectating) the mission sets the sound volume
    E_var_suspendCondition = {!simulationEnabled player};
    setPlayerRespawnTime DM_var_noRespawnTime;

    call CMN_fnc_showLoadingScreen;
    call VA_fnc_init;       // arsenal template whitelist (vaOverride\vaOverride.sqf)
    [player, false] call ADG_fnc_allowDamage;
    call CMN_fnc_trackPreload;

    waitUntil {!isNull player && {!isNil "DM_var_serverInitDone"}};
    [player, profileName, _takenOverState] remoteExec ["DM_fnc_initPlayerServer", 2];

    waitUntil {
        [missionNamespace, DM_var_clientServerVars] call CMN_fnc_varsDefined &&
        {[player, ["CMN_var_isLoading", "DM_var_arsenalOpened", "DM_var_startLoadout"]] call CMN_fnc_varsDefined}
    };

    call DM_fnc_setupPlayer;
};

DM_fnc_setupPlayer = {
    DM_var_movementEH = nil;
    DM_var_fireId = nil;
    DM_var_gpsSet = false;

    call CMN_fnc_initNightVision;
    call CMN_fnc_setupClientEnvironment;

    player setUnitTrait ["Engineer", true];
    player setUnitTrait ["UAVHacker", true];
    player setVariable ["DM_var_lastLoadout", player getVariable "DM_var_startLoadout"];

    [player] join grpNull;

    ["InitializePlayer", [player]] call BIS_fnc_dynamicGroups;
    (["DM_rscHud"] call BIS_fnc_rscLayer) cutRsc ["DM_rscHud", "PLAIN", 0, true];

    player addEventHandler ["Killed", {_this call DM_fnc_killed}];
    player addEventHandler ["Respawn", {_this call DM_fnc_respawn}];
    player addEventHandler ["FiredMan", {_this call DM_fnc_firedMan}];
    addMissionEventHandler ["Map", {
        params ["_isOpened"];
        [_isOpened, "DM_mrk_playZone", DM_var_mapScaleFactor, DM_var_maxZoneSize] call CMN_fnc_mapZoom;
    }];
    [missionNamespace, "arsenalClosed", {_this call DM_fnc_arsenalClosed}] call BIS_fnc_addScriptedEventHandler;
    [missionNamespace, "arsenalOpened", {_this call DM_fnc_arsenalOpened}] call BIS_fnc_addScriptedEventHandler;

    if (DM_var_loadoutsRestricted) then {
        // current arsenal content (warmup or current round), also for players joining mid-match
        if (isNil "DM_var_equip") then {
            DM_var_arsenalItems spawn DM_fnc_applyItemsOnArsenal;
        };
    } else {
        [] spawn DM_fnc_createFullArsenal;
    };

    // thirdPerson: 0 Disabled, 1 Enabled
    [("thirdPerson" call BIS_fnc_getParamValue) == 1] call CMN_fnc_initCameraView;

    [] spawn DM_fnc_startPlayer;
};

// scheduled: after preloading, start the client loops and spectate (round running) or spawn at the HQ
DM_fnc_startPlayer = {
    waitUntil {!(player getVariable "CMN_var_isLoading")};

    [] spawn DM_fnc_guiLoop;
    [] spawn DM_fnc_movementLoop;
    [] spawn CMN_fnc_spectatorNightVisionLoop;
    [{["DM_mrk_playZone", DM_var_mapScaleFactor, DM_var_maxZoneSize]}] spawn CMN_fnc_spectatorMapZoneLoop;

    if (DM_var_respawnTime > DM_var_respawnDelay) then {
        call CMN_fnc_hideCenterText;
        [] spawn DM_fnc_spectator;
    } else {
        sleep 2;
        call CMN_fnc_hideCenterText;
        [false] spawn DM_fnc_setToSpawn;
        [[DM_var_roundNumber] call DM_fnc_relativeRoundNumber] spawn DM_fnc_resetLoadout;
        [objNull, objNull] call DM_fnc_respawn;     // also enables the GPS
        cutText ["", "BLACK IN", 0, true];
        call CMN_fnc_restoreNightVision;
    };

    [] spawn DM_fnc_respawnTimeLoop;
};
