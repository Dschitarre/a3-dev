// GunGame start-up (server and client): server init, taking over a unit as player, client setup, disconnects.
// Also holds the match tuning values (mode, AI amount and ladder are lobby params, GG\params.hpp).

GG_var_maxUnits = 46;               // alive units at most (= player slots)
GG_var_leaderBoardLayer = 1010;     // cut layers of the screen texts (ui\ui.sqf)
GG_var_nextWeaponsLayer = 1012;
GG_var_hudInterval = 0.1;

// ---- server init ----

GG_fnc_initServer = {
    call CMN_fnc_disableEngineFeatures;
    call GG_fnc_readParamsServer;
    [call GG_fnc_initialMapIndex] call GG_fnc_applyMap;

    // base loadout for GG_fnc_applyWeapon on every machine, from a slot no player controls
    GG_var_loadout = getUnitLoadout (((playableUnits select {!isPlayer _x}) + playableUnits) select 0);
    publicVariable "GG_var_loadout";

    GG_var_weaponList = call GG_fnc_buildLadder;
    publicVariable "GG_var_weaponList";

    call GG_fnc_initTeamsServer;

    GG_var_ended = false;
    GG_var_playerStats = createHashMap;
    GG_var_mapScaleFactor = call CMN_fnc_mapScaleFactor;
    GG_var_suspendAiLoopScript = scriptNull;

    publicVariable "GG_var_ended";
    publicVariable "GG_var_mapScaleFactor";

    call GG_fnc_initAiPoolServer;
    call GG_fnc_refreshLeaderBoardServer;

    // true: the unit stays and becomes server AI (GG_fnc_handleDisconnect parks it)
    addMissionEventHandler ["HandleDisconnect", {_this call GG_fnc_handleDisconnect; true}];
    addMissionEventHandler ["EntityRespawned", {_this call GG_fnc_entityRespawned}];
    addMissionEventHandler ["EntityKilled", {_this call GG_fnc_entityKilled}];

    GG_var_suspendAiLoopScript = [] spawn GG_fnc_suspendAiLoop;

    call GG_fnc_startModsServer;

    GG_var_serverInitDone = true;
    publicVariable "GG_var_serverInitDone";
};

// lobby params (values[] in GG\params.hpp); the Map param is read in GG_fnc_initialMapIndex / GG_fnc_nextMapIndex
GG_fnc_readParamsServer = {
    // teamMode: 0 Free for all, 1 Team GunGame
    GG_var_teamMode = ("teamMode" call BIS_fnc_getParamValue) == 1;
    publicVariable "GG_var_teamMode";

    // ai: 0 Auto (zone size), 1 Off, N >= 2 fill up to N units (GG_fnc_applyMap sets GG_var_wantedUnitAmount)
    GG_var_aiMode = "ai" call BIS_fnc_getParamValue;

    // killsPerStage: kills for the next weapon (the grenade stage always needs one)
    GG_var_killsPerStage = "killsPerStage" call BIS_fnc_getParamValue;

    // demotion: 0 Disabled, 1 Enabled - a suicide costs one weapon
    GG_var_demotion = ("demotion" call BIS_fnc_getParamValue) == 1;
};

/*
    The playable units are the AI pool. Every slot gets its id (public: clients find their own leaderboard rank by it)
    and ladder stats; only units no player controls become AI, so players connected at mission start (rotation,
    #restart) keep their unit.
*/
GG_fnc_initAiPoolServer = {
    {
        [_x] call GG_fnc_setRating;
        _x setVariable ["GG_var_unitId", _forEachIndex, true];
        [_x] call GG_fnc_resetLadderStats;
    } forEach playableUnits;

    GG_var_nextUnitId = count playableUnits;
    GG_var_suspendedUnits = playableUnits select {!isPlayer _x};

    {
        [_x] call GG_fnc_initAiUnit;
    } forEach GG_var_suspendedUnits;
};

GG_fnc_startModsServer = {
    // skipNight: 0 Disabled, 1 Enabled
    [[2035, 7, 1], ("skipNight" call BIS_fnc_getParamValue) == 1] call CMN_fnc_applyWorldParams;
    DW_var_timeBetweenWeatherChangesMultiplierSunny = 0;
    DW_var_timeBetweenWeatherChangesMultiplierStormy = 0;
    publicVariable "DW_var_skipNight";
    if (missionNamespace getVariable ["DW_cba_enabled", true]) then {
        [true] call DW_fnc_startDynamicWeather;
    };

    KF_var_showFriendlyFire = GG_var_teamMode;
    KF_var_killInfoIncludeTK = !GG_var_teamMode;
    KF_var_killInfoDuration = GG_var_podiumDuration;
    KF_fnc_killCamRoundOver = {GG_var_ended};   // kill cam: none once the round is won
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
    if (missionNamespace getVariable ["MR_cba_enabled", true]) then {
        call MR_fnc_startMagRepackServer;
    };
    if (missionNamespace getVariable ["J_cba_enabled", true]) then {
        call J_fnc_startJumpServer;
    };
    if (missionNamespace getVariable ["AH_cba_enabled", true]) then {
        call AH_fnc_startAutoHealServer;
    };

    // map and GPS: the own unit, in Team GunGame also the team (its side); generic unit icons as in TDM
    MM_var_restrictUnitIcons = true;
    MM_var_showOwnUnitOnly = !GG_var_teamMode;
    publicVariable "MM_var_restrictUnitIcons";
    publicVariable "MM_var_showOwnUnitOnly";
    if (missionNamespace getVariable ["MM_cba_enabled", true]) then {
        call MM_fnc_startMapMarkerServer;
    };
};

// ---- player takeover (server) ----

/*
    remoteExec'd by GG_fnc_initClient. The one place where a unit becomes a player unit, for a JIP player taking over
    a pool AI as well as for a player who had the unit at mission start. Idempotent.
    A returning player gets his stats of the round back; nobody starts below the lowest stage in the game. In team mode
    the player joins the team with fewer players and climbs its ladder.
*/
GG_fnc_initPlayer = {
    params ["_player", ["_playerName", ""]];

    if (isNull _player) exitWith {};

    GG_var_suspendedUnits = GG_var_suspendedUnits - [_player];
    [_player, _playerName] call CMN_fnc_initPlayerUnit;
    _player setVariable ["GG_var_lastSpawnPos", nil];

    // a unit the engine created for the slot has no id yet
    if ((_player getVariable ["GG_var_unitId", -1]) == -1) then {
        _player setVariable ["GG_var_unitId", GG_var_nextUnitId, true];
        GG_var_nextUnitId = GG_var_nextUnitId + 1;
    };

    // [stage, kills, deaths, best streak] of a player who left during this round
    (GG_var_playerStats getOrDefault [getPlayerUID _player, [0, 0, 0, 0]]) params ["_weaponNum", "_kills", "_deaths", "_bestStreak"];

    [_player, _weaponNum max ([_player] call GG_fnc_lowestWeaponNum), _kills, _deaths, _bestStreak] call GG_fnc_resetLadderStats;

    if (GG_var_teamMode) then {
        [_player, [_player] call GG_fnc_teamForPlayer] call GG_fnc_joinTeam;
    } else {
        [_player] call GG_fnc_setRating;
    };

    if (!GG_var_ended) then {
        call GG_fnc_refreshLeaderBoardServer;
    };
};

// ---- client init ----

// server state the client setup reads
GG_var_clientServerVars = [
    "GG_var_leaderBoard",
    "GG_var_maxZoneSize",
    "GG_var_mapScaleFactor",
    "GG_var_loadout",
    "GG_var_weaponList",
    "GG_var_teamMode",
    "GG_var_teamLoadouts",
    "GG_var_ended"
];

// scheduled (initPlayerLocal.sqf): freeze the player until the server has taken the unit over, then set it up
GG_fnc_initClient = {
    [player, false] call CMN_fnc_setSimulationGlobal;
    0 fadeSound 0;

    // earplugs mod: while the unit is not simulated (loading, spawn out of the zone, round end) the mission sets the
    // sound volume
    E_var_suspendCondition = {!simulationEnabled player};

    call CMN_fnc_showLoadingScreen;
    call CMN_fnc_trackPreload;

    waitUntil {!isNull player && {!isNil "GG_var_serverInitDone"}};
    [player, profileName] remoteExecCall ["GG_fnc_initPlayer", 2];

    waitUntil {
        [missionNamespace, GG_var_clientServerVars] call CMN_fnc_varsDefined &&
        {[player, ["CMN_var_isLoading", "GG_var_weaponNum", "GG_var_kills", "GG_var_deaths", "GG_var_unitId"]] call CMN_fnc_varsDefined} &&
        {!(player getVariable "CMN_var_isLoading")}
    };

    call GG_fnc_setupPlayer;
};

GG_fnc_setupPlayer = {
    GG_var_lastSpawnPos = [0, 0, 0];

    call CMN_fnc_initNightVision;
    call CMN_fnc_setupClientEnvironment;

    // team mode: the server has put the player into his team's group
    if (!GG_var_teamMode) then {
        [player] join grpNull;
    };

    (["GG_rscHud"] call BIS_fnc_rscLayer) cutRsc ["GG_rscHud", "PLAIN", 0, true];
    [player] call GG_fnc_setRating;

    player addEventHandler ["Killed", {call GG_fnc_killed}];
    player addEventHandler ["Respawn", {_this call GG_fnc_respawn}];
    player addEventHandler ["Take", {_this call GG_fnc_take}];
    player addEventHandler ["FiredMan", {_this call GG_fnc_firedMan}];
    player addEventHandler ["InventoryOpened", {["inventoryDisabled"] call BIS_fnc_showNotification; true}];
    addMissionEventHandler ["Map", {
        params ["_isOpened"];
        [_isOpened, "GG_var_playZone", GG_var_mapScaleFactor, GG_var_maxZoneSize] call CMN_fnc_mapZoom;
    }];

    // thirdPerson: 0 Disabled, 1 Enabled
    [("thirdPerson" call BIS_fnc_getParamValue) == 1] call CMN_fnc_initCameraView;

    call GG_fnc_refreshLeaderBoardClient;
    call GG_fnc_refreshNextWeapon;
    "GG_var_leaderBoard" addPublicVariableEventHandler {call GG_fnc_refreshLeaderBoardClient};

    [] spawn GG_fnc_guiLoop;
    [] spawn CMN_fnc_spectatorNightVisionLoop;
    [] spawn GG_fnc_startPlayer;

    GG_var_playerSetUp = true;
};

// scheduled: the respawn screen (once no round end is running), then GPS once the player is in the zone
GG_fnc_startPlayer = {
    sleep 2;
    waitUntil {!GG_var_ended};
    call GG_fnc_openRespawnScreen;

    waitUntil {simulationEnabled player && {alive player} && {player inArea "GG_var_playZone"}};
    player setVariable ["GG_var_lastPos", getPosATL player];
    call CMN_fnc_enableGps;
};

// ---- disconnects (server) ----

/*
    "HandleDisconnect" (returns true, so the unit stays as server AI). The player's round stats are kept for his
    return; the unit becomes a pool AI again on the lowest stage in the game and is parked, so the pool keeps its size.
    A dead unit respawns and is parked by GG_fnc_entityRespawned.
*/
GG_fnc_handleDisconnect = {
    params ["_unit", "", "_uid"];

    if (_uid != "") then {
        GG_var_playerStats set [_uid, [
            _unit getVariable ["GG_var_weaponNum", 0],
            _unit getVariable ["GG_var_kills", 0],
            _unit getVariable ["GG_var_deaths", 0],
            _unit getVariable ["GG_var_bestStreak", 0]
        ]];
    };

    [_unit] spawn {
        params ["_unit"];

        // the engine hands the unit to the server after this event
        private _timeout = time + 10;

        waitUntil {
            sleep 0.1;
            isNull _unit || {!isPlayer _unit && {local _unit}} || {time > _timeout}
        };

        if (isNull _unit || {isPlayer _unit} || {!local _unit}) exitWith {};

        [_unit] call GG_fnc_initAiUnit;
        [_unit, [_unit] call GG_fnc_lowestWeaponNum] call GG_fnc_resetLadderStats;

        if (alive _unit) then {
            [_unit] call GG_fnc_suspendUnit;

            _timeout = time + 5;

            waitUntil {
                sleep 0.25;
                isNull _unit || {!simulationEnabled _unit} || {time > _timeout}
            };
        };

        if (!GG_var_ended) then {
            call GG_fnc_refreshLeaderBoardServer;
        };
    };
};
