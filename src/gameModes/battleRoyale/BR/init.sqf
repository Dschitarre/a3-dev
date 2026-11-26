// Battle Royale start-up (server and client): lobby params, server init, taking over a unit as player, client setup,
// parking units and position helpers. Also holds the general tuning values.

BR_var_parkPos = [0, 0, 10]; // frozen, hidden units wait here (AI pool, units aboard the aircraft)
BR_var_noRespawnTime = 1e6; // respawn time that disables respawning: dead is dead
BR_var_landPosTries = 25; // random tries for a spot on land before a fallback is taken
BR_var_baseLoadout = [[], [], [], [], [], [], "", "", [], ["ItemMap", "ItemGPS", "ItemRadio", "ItemCompass", "ItemWatch", ""]];

// plain clothes every combatant starts in (BR_worldPool "startUniforms" of BR\loot\lootPool<mapGroup>.hpp); classes of
// DLCs that are not loaded are skipped
BR_var_uniforms = (getArray (missionConfigFile >> "BR_worldPool" >> "startUniforms")) select {isClass (configFile >> "CfgWeapons" >> _x)};

// ---- position helpers ----

// [x, y, 0] of a 2D or 3D position
BR_fnc_groundPos = {
    params ["_pos"];

    [_pos select 0, _pos select 1, 0]
};

// uniformly distributed point in a circle
BR_fnc_randomPosInCircle = {
    params ["_center", "_radius"];

    [_center getPos [_radius * sqrt random 1, random 360]] call BR_fnc_groundPos
};

// a point on land in the circle (with _openSky: nothing above it); the last candidate if none is found
BR_fnc_randomLandPos = {
    params ["_center", "_radius", ["_openSky", false]];

    private _candidate = [_center] call BR_fnc_groundPos;

    for "_i" from 1 to BR_var_landPosTries do {
        _candidate = [_center, _radius] call BR_fnc_randomPosInCircle;

        if (!surfaceIsWater _candidate && {!_openSky || {[_candidate] call CMN_fnc_isUnderOpenSky}}) exitWith {};

    };

    _candidate
};

// ---- server init ----

// lobby params (values[] in BR\params.hpp)
BR_fnc_readParamsServer = {

    // teamSize: 1 Solo, 2 Duo, 4 Squad
    BR_var_teamSize = "teamSize" call BIS_fnc_getParamValue;
    publicVariable "BR_var_teamSize";

    // aiFill: 0 Disabled, 1 Enabled
    BR_var_aiFill = ("aiFill" call BIS_fnc_getParamValue) == 1;

    // combatants: 0 Auto (by the map's land area, BR_fnc_mapCombatants), else the number; AI beyond the mission's slots
    // is created (BR\aiFill.sqf)
    private _combatants = "combatants" call BIS_fnc_getParamValue;
    BR_var_targetCombatants = [_combatants, call BR_fnc_mapCombatants] select (_combatants == 0);
    BR_var_targetCombatants = (BR_var_combatantsRange select 0) max (BR_var_targetCombatants min (BR_var_combatantsRange select 1));

    BR_var_warmupTime = "warmupTime" call BIS_fnc_getParamValue;

    // teamJump: 0 Individually, 1 Together
    BR_var_teamJump = ("teamJump" call BIS_fnc_getParamValue) == 1;

    // zoneSpeed: 0 Slow, 1 Normal, 2 Fast -> factor on all zone times
    BR_var_zoneTimeFactor = [1.4, 1, 0.7] select ("zoneSpeed" call BIS_fnc_getParamValue);

    // lootAmount: 0 Low, 1 Normal, 2 High -> loot chance per building position (scaled to the area, BR\maps\maps.sqf)
    BR_var_lootChanceBase = [0.4, 0.6, 0.8] select ("lootAmount" call BIS_fnc_getParamValue);

    // vehicleAmount: vehicles in an area of the reference size (BR\maps\maps.sqf scales it to the area)
    BR_var_vehicleCountBase = "vehicleAmount" call BIS_fnc_getParamValue;

    // airdrops: 0 Disabled, 1 Enabled
    BR_var_airdropsEnabled = ("airdrops" call BIS_fnc_getParamValue) == 1;
};

BR_fnc_initServer = {
    call BR_fnc_readParamsServer;
    call BR_fnc_initDowned;
    call CMN_fnc_disableEngineFeatures;

    call BR_fnc_initMatchStateServer;
    call BR_fnc_initTeamsServer;
    call SC_fnc_initGroupMenuServer;
    call BR_fnc_initPoolServer;
    [BR_var_targetCombatants] call BR_fnc_selectPlayArea;
    call BR_fnc_initLootServer;
    call BR_fnc_startModsServer;

    addMissionEventHandler ["HandleDisconnect", {
        _this call BR_fnc_handleDisconnect;
        true
    }];

    addMissionEventHandler ["EntityRespawned", {_this call BR_fnc_entityRespawned}];
    addMissionEventHandler ["EntityKilled", {_this call BR_fnc_entityKilled}];

    BR_var_serverInitDone = true;
    publicVariable "BR_var_serverInitDone";

    [] spawn BR_fnc_matchLoop;
};

BR_fnc_startModsServer = {
    [[2035, 6, 1], false] call CMN_fnc_applyWorldParams;
    if (missionNamespace getVariable ["DW_cba_enabled", true]) then {
        [true] call DW_fnc_startDynamicWeather;
    };

    KF_var_killInfoIncludeTK = true;
    KF_var_showFriendlyFire = false; // a downed mate finished by mistake or a grenade: no "friendly fire" marks
    KF_var_killCamEnabled = true; // user 2026-11-23: the kill cam first, then the spectator (BR_fnc_killed waits for it)

    // team modes (BR\downed.sqf, as Sector Control): going down is the kill in the feeds (AIS reports it), the death
    // afterwards ("finally killed", bled out) only a line in the mid feed
    if (!isNil "AIS_var_initDone") then {
        KF_var_showFinallyKilledForUnitDeaths = true;
        KF_var_addScoreForUnitDeaths = false;
        KF_var_showUnitDeathsInKillfeed = false;
        KF_var_showUnitDeathsInMidfeed = true;
        KF_var_showUnitDeathsInDeathFeed = false;
        KF_var_showUnitDeathsInKillInfo = false;
    };

    if (missionNamespace getVariable ["KF_cba_enabled", true]) then {
        call KF_fnc_startKillfeed;
    };

    // Engine factions do not describe BR teams. Use the same virtual team IDs for feed scoring and match kills.
    KF_fnc_isTeamKill = BR_fnc_isTeammate;

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
    if (missionNamespace getVariable ["J_cba_enabled", true]) then {
        call J_fnc_startJumpServer;
    };
};

// ---- parking (where the unit is local) ----
// A parked unit is frozen and hidden at BR_var_parkPos: suspended AI, units aboard the aircraft, spectators' units.

BR_fnc_parkUnit = {
    params ["_unit"];

    if (isNull _unit) exitWith {};

    if (!local _unit) exitWith {
        [_unit] remoteExecCall ["BR_fnc_parkUnit", _unit];
    };

    if (!isNull objectParent _unit) then {
        moveOut _unit;
    };

    _unit setPos BR_var_parkPos;
    _unit setVelocity [0, 0, 0];
    [_unit, false] call CMN_fnc_setSimulationGlobal;
    [_unit, true] remoteExecCall ["hideObjectGlobal", 2];
};

// simulation on before the move: a position set while the unit is frozen is not sent to the other machines
BR_fnc_unparkUnit = {
    params ["_unit", "_posASL"];

    [_unit, true] call CMN_fnc_setSimulationGlobal;
    _unit setPosASL _posASL;
    _unit setVelocity [0, 0, 0];
    [_unit, false] remoteExecCall ["hideObjectGlobal", 2];
};

// starting clothes and items (where the unit is local)
BR_fnc_applyBaseLoadout = {
    params ["_unit"];

    _unit setUnitLoadout BR_var_baseLoadout;

    if (BR_var_uniforms isNotEqualTo []) then {
        _unit forceAddUniform selectRandom BR_var_uniforms;
    };
};

// ---- player takeover (server) ----

/*
    remoteExec'd by BR_fnc_initClient. The one place where a unit becomes a player unit, for a JIP player taking over
    an AI as well as for a player who had the unit at mission start. Answers with BR_var_role = [token, role]:
    "warmup" (spawn at the start area), "combatant" (keep playing the unit: aboard or on the ground), "spectator".
*/
BR_fnc_initPlayerServer = {
    params ["_player", ["_playerName", ""], ["_token", ""]];

    if (isNull _player) exitWith {};

    [_player, _playerName] call CMN_fnc_initPlayerUnit;
    _player setVariable ["BR_var_name", _playerName, true];

    // Recover the slot from the server's unit registry if a joining entity lost its published metadata.
    // Editor variable names are deliberately irrelevant.
    private _slotId = _player getVariable ["BR_var_slotId", -1];
    private _hadTeam = (_player getVariable ["BR_var_teamId", -1]) != -1;

    if (_slotId == -1) then {
        _slotId = BR_var_slotUnits find _player;
    };

    if (_slotId >= 0) then {
        _player setVariable ["BR_var_slotId", _slotId, true];
        if (!_hadTeam) then {_player setVariable ["BR_var_teamId", floor (_slotId / BR_var_teamSize), true]};

        if (_slotId < count BR_var_slotUnits) then {
            BR_var_slotUnits set [_slotId, _player];
        };
    };

    private _role = switch (true) do {
        case (BR_var_state == "warmup" && {!(missionNamespace getVariable ["BR_var_groupsLocked", false])}): {"warmup"};
        case (BR_var_state != "ended" && {alive _player} && {_player getVariable ["BR_var_inMatch", false]}): {"combatant"};
        default {"spectator"};
    };

    if (_role == "warmup") then {
        [_player] call BR_fnc_assignJoiningGroup;
        call BR_fnc_balanceRoster;
    };

    // the team's player group exists before the client gets its role (BR_fnc_setupPlayer joins it)
    if (_role != "spectator") then {
        [_player getVariable ["BR_var_teamId", -1]] call BR_fnc_teamPlayerGroup;
    };

    // a unit that never was or no longer is in the match waits parked (its corpse, if dead, stays for looting)
    if (_role == "spectator" && {alive _player}) then {
        [_player] call BR_fnc_parkUnit;
    };

    _player setVariable ["BR_var_role", [_token, _role], true];
    diag_log format ["BR join: %1 (%2) -> %3, state %4, slot %5, team on the server before %6", _playerName, _player, _role, BR_var_state, _slotId, _hadTeam];
};

// ---- client init ----

// server state the client setup reads
BR_var_clientServerVars = [
"BR_var_state",
"BR_var_stateEndTime",
"BR_var_teamSize",
"BR_var_teamPlayerGroups",
"BR_var_rosterUnits",
"BR_var_zone",
"BR_var_playAreaName",
"BR_var_aliveCounts",
"BR_var_airdropCrates"
];

/*
    Scheduled (initPlayerLocal.sqf): freeze the player until the server has taken the unit over, then set it up.
    CMN_var_isLoading only exists while (or after) a preload ran after CMN_fnc_trackPreload: a joining client usually
    finished its preload before the main display - and with it the handlers - exists, and the parked unit gives no
    reason for a new one. So an unset flag means "loaded" (requiring it kept joining players at "Loading" for good).
*/
BR_fnc_initClient = {
    call BR_fnc_initDowned;
    [player, false] call CMN_fnc_setSimulationGlobal;
    0 fadeSound 0;
    setPlayerRespawnTime BR_var_noRespawnTime;

    call CMN_fnc_showLoadingScreen;
    call CMN_fnc_trackPreload;

    private _waitStart = diag_tickTime;
    private _lastLog = diag_tickTime;

    waitUntil {
        if ((diag_tickTime - _lastLog) > 10) then {
            _lastLog = diag_tickTime;
            diag_log format ["BR join: waiting for the server init (player %1, serverInitDone %2)", player, !(isNil "BR_var_serverInitDone")];
        };

        !isNull player && {!isNil "BR_var_serverInitDone"}
    };

    // the token tells this answer apart from a role an earlier player of this unit got
    private _token = str floor random 1e7;
    [player, profileName, _token] remoteExecCall ["BR_fnc_initPlayerServer", 2];

    waitUntil {
        if ((diag_tickTime - _lastLog) > 10) then {
            _lastLog = diag_tickTime;
            diag_log format [
            "BR join: waiting (missing server vars %1, role %2 / token %3, loading %4, team %5)",
            BR_var_clientServerVars select {isNil _x},
            player getVariable ["BR_var_role", "none"],
            _token,
            player getVariable ["CMN_var_isLoading", "undefined"],
            player getVariable ["BR_var_teamId", "undefined"]
            ];
        };

        [missionNamespace, BR_var_clientServerVars] call CMN_fnc_varsDefined &&
            {((player getVariable ["BR_var_role",[]]) param [0, ""]) == _token} &&
            {[player,["BR_var_teamId"]] call CMN_fnc_varsDefined} &&
            {!(player getVariable ["CMN_var_isLoading", false])}
    };

    diag_log format ["BR join: set up after %1 s", round (diag_tickTime - _waitStart)];

    call BR_fnc_setupPlayer;
};

BR_fnc_setupPlayer = {
    call CMN_fnc_initNightVision;
    call CMN_fnc_setupClientEnvironment; // view distances: the settings loop in BR\hud.sqf (flight / ground)

    // the team's player group: group channel and squad UI with the team mates (the server made it before the role;
    // spectators have none)
    private _teamGroup = BR_var_teamPlayerGroups param [player getVariable "BR_var_teamId", grpNull];

    if (!isNull _teamGroup) then {
        [player] joinSilent _teamGroup;
    };

    [player] call BR_fnc_makeRenegade;

    (["BR_rscHud"] call BIS_fnc_rscLayer) cutRsc ["BR_rscHud", "PLAIN", 0, true];
    call BR_fnc_initMapColors;

    player addEventHandler ["Killed", {call BR_fnc_killed}];
    player addEventHandler ["Respawn", {_this call BR_fnc_respawn}];

    addMissionEventHandler ["Map", {
        params ["_isOpened"];

        if (_isOpened) then {
            call BR_fnc_mapZoom;
        };

    }];

    addMissionEventHandler ["Draw3D", {call BR_fnc_drawTeamIcons}];
    addMissionEventHandler ["Draw3D", {call BR_fnc_drawZone3D}];
    call BR_fnc_addTeamVehicleAction;
    call BR_fnc_initUniforms;
    call BR_fnc_initItems;

    // Entity visibility is computed exclusively by the dedicated culling HC.
    call BR_fnc_initGroupsClient;
    call BR_fnc_initKillfeedColors;

    // thirdPerson: 0 Disabled, 1 Enabled
    [("thirdPerson" call BIS_fnc_getParamValue) == 1] call CMN_fnc_initCameraView;

    // the GPS in the right panel, open from the start (BR\mapDraw.sqf)
    call BR_fnc_showGpsRight;

    [] spawn BR_fnc_gpsPanelLoop;
    [] spawn BR_fnc_mapDrawLoop;
    [] spawn BR_fnc_hudLoop;
    [] spawn CMN_fnc_spectatorNightVisionLoop;
    [] spawn BR_fnc_startPlayer;
};

// scheduled: continues with the role the server assigned
BR_fnc_startPlayer = {
    switch ((player getVariable "BR_var_role") select 1) do {
        case "warmup": {
            call BR_fnc_warmupSpawn;
            call BR_fnc_waitForBoarding;
        };
        case "combatant": {
            if (player getVariable ["BR_var_aboard", false]) then {
                call BR_fnc_flightClient;
            } else {

                call BR_fnc_resumeCombatant;
            };
        };
        default {
            call BR_fnc_startSpectator;
        };
    };
};

// everyone fights everyone: the killfeed shows all names white instead of in their (shared) side color; the player's
// own name stays yellow. The killfeed's color loop picks up the changed table (KF_fnc_refreshColors).
BR_fnc_initKillfeedColors = {
    [] spawn {
        waitUntil {!isNil "KF_var_fixedColors"};

        {
            if ((_x select 0) in ["kf:west", "kf:east", "kf:guer", "kf:civ", "kf:unknown"]) then {
                _x set [1, "#FFFFFF"];
            };
        } forEach KF_var_fixedColors;
    };
};

// warmup: a free spot at the start area, unarmed and invulnerable
// remoteExecCall'd by BR_fnc_keepPlayersInStartArea: a player outside of the start area during the warmup gets a new spot
BR_fnc_returnToStartArea = {
    if (!alive player || {BR_var_state != "warmup"} || {!isNull objectParent player}) exitWith {};

    player setPosASL (AGLToASL ([BR_var_startAreaCenter, BR_var_startAreaRadius] call BR_fnc_randomLandPos));
    player setVelocity [0, 0, 0];
};

BR_fnc_warmupSpawn = {
    private _spawnPos = [BR_var_startAreaCenter, BR_var_startAreaRadius] call BR_fnc_randomLandPos;

    [player] call BR_fnc_applyBaseLoadout;
    [player, false] call ADG_fnc_allowDamage;
    [player, AGLToASL _spawnPos] call BR_fnc_unparkUnit;
    player setDir random 360;
    player switchCamera CMN_var_lastView;
    call CMN_fnc_startCameraViewLoop;

    call CMN_fnc_hideCenterText;
    cutText ["", "BLACK IN", 1, true];
    1 fadeSound 1;
};

// scheduled: the server boards every combatant when the flight starts
BR_fnc_waitForBoarding = {
    BR_var_boardBlack = false;

    waitUntil {
        sleep 0.1;

        // to black shortly before the warmup ends: meanwhile the server parks the player (over the sea) and seats it in
        // the aircraft (BR_fnc_startMatch) - the camera showed the park position and the world in between. A warmup
        // that starts over (a player left) shows the world again.
        private _ending = BR_var_stateEndTime >= 0 && {serverTime >= BR_var_stateEndTime - BR_var_boardFadeTime};

        if (_ending && {!BR_var_boardBlack}) then {
            BR_var_boardBlack = true;
            cutText ["", "BLACK OUT", BR_var_boardFadeTime, true];
            BR_var_boardFadeTime fadeSound 0;
        };

        if (!_ending && {BR_var_boardBlack} && {BR_var_state == "warmup"}) then {
            BR_var_boardBlack = false;
            cutText ["", "BLACK IN", BR_var_boardFadeTime, true];
            BR_var_boardFadeTime fadeSound 1;
        };

        player getVariable ["BR_var_aboard", false] || {BR_var_state != "warmup" && {!(player getVariable ["BR_var_inMatch", false])}}
    };

    // not aboard: the spectator view fades in by itself (BR_fnc_startSpectator)

    if (player getVariable ["BR_var_aboard", false]) then {
        call BR_fnc_flightClient;
    } else {

        call BR_fnc_startSpectator;
    };
};

// a JIP player who took over an AI that is already on its way down or on the ground
BR_fnc_resumeCombatant = {
    [player, true] call CMN_fnc_setSimulationGlobal;
    player switchCamera CMN_var_lastView;
    call CMN_fnc_startCameraViewLoop;
    call CMN_fnc_hideCenterText;
    cutText ["", "BLACK IN", 1, true];
    1 fadeSound 1;

    if (isNull objectParent player && {((getPosATL player) select 2) > BR_var_freefallMinHeight}) then {
        [player, BR_var_freefallOpenHeight, {[player, true] call ADG_fnc_allowDamage}] spawn BR_fnc_watchFreefall;
    };
};
