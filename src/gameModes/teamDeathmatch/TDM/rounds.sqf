// Team Deathmatch rounds (server, clients react): warmup with map vote and ready check, round loop, round end and the
// round state the server publishes.

DM_var_warmupReadyRest = 10;        // seconds left of the warmup once most players are ready

// ---- warmup and rounds (server) ----

DM_fnc_gameModeLoop = {
    DM_var_playZoneLoopHdl = [] spawn DM_fnc_playZoneLoop;

    call DM_fnc_runWarmup;

    waitUntil {call DM_fnc_playRound};
};

/*
    Free play with respawns on a warmup map. Meanwhile the players vote for the map of the match (action menu, when
    the MapName param leaves a choice) and can mark themselves ready, which cuts the warmup short.
*/
DM_fnc_runWarmup = {
    // warmup map, preferably not the map of round 1
    if (DM_var_alternatingMaps) then {
        private _warmupMaps = DM_var_randomMapRotation select [1, count DM_var_randomMapRotation - 1];

        if (_warmupMaps isEqualTo []) then {
            _warmupMaps = DM_var_randomMapRotation;
        };

        [selectRandom _warmupMaps, selectRandom [true, false]] call DM_fnc_applyMap;
    };

    [DM_var_respawnDelay] call DM_fnc_setRespawnTimeTo;
    [DM_var_maxRelRoundNumber] call DM_fnc_startAiBalance;

    if (DM_var_vehiclesEnabled) then {
        call DM_fnc_spawnVehiclesForSides;
        call DM_fnc_startVehicleLoop;
    };

    [false] call DM_fnc_waitForPlayersReady;

    private _warmupTime = "warmupTime" call BIS_fnc_getParamValue;
    private _mapChoices = call DM_fnc_mapVoteChoices;
    private _voteScript = scriptNull;
    DM_var_votedMap = -1;

    if (_mapChoices isNotEqualTo []) then {
        _voteScript = [_mapChoices, _warmupTime] spawn {
            params ["_mapChoices", "_warmupTime"];

            private _options = _mapChoices apply {[_x] call DM_fnc_mapName};
            DM_var_votedMap = _mapChoices select (["Map of the match", _options, _warmupTime] call CMN_fnc_runVote);
        };
    };

    DM_var_timerHdl = [_warmupTime] spawn DM_fnc_timer;
    ["teamDeathmatch", [["Warmup started", "Warmup started. Map vote: action menu"] select (!isNull _voteScript)]] call DM_fnc_showNotificationGlobal;
    [_warmupTime] call DM_fnc_waitForWarmupEnd;

    if (!scriptDone DM_var_timerHdl) then {
        terminate DM_var_timerHdl;
    };

    if (!isNull _voteScript) then {
        [0] call CMN_fnc_setVoteEnd;
        waitUntil {scriptDone _voteScript};
    };

    DM_var_inWarmup = false;
    publicVariable "DM_var_inWarmup";

    call DM_fnc_stopAiBalance;
    [DM_var_votedMap] call DM_fnc_applyWarmupMapChoice;
    call DM_fnc_resetPlayerScores;
};

// waits for the end of the warmup; when most players are ready (action menu) only DM_var_warmupReadyRest seconds are left
DM_fnc_waitForWarmupEnd = {
    params ["_warmupTime"];

    private _endTime = time + _warmupTime;

    waitUntil {
        sleep DM_var_readyPollInterval;

        if (_endTime - time > DM_var_warmupReadyRest && {call DM_fnc_mostPlayersReady}) then {
            _endTime = time + DM_var_warmupReadyRest;
            terminate DM_var_timerHdl;
            DM_var_timerHdl = [DM_var_warmupReadyRest] spawn DM_fnc_timer;
            [DM_var_warmupReadyRest] call CMN_fnc_setVoteEnd;
            ["teamDeathmatch", [format ["Most players are ready, the match starts in %1 seconds", DM_var_warmupReadyRest]]] call DM_fnc_showNotificationGlobal;
        };

        time >= _endTime
    };
};

// more than half of the players marked themselves ready (action menu, DM_var_warmupReady)
DM_fnc_mostPlayersReady = {
    private _players = allPlayers - (allMissionObjects "HeadlessClient_F");

    2 * ({_x getVariable ["DM_var_warmupReady", false]} count _players) > count _players
};

// one round; returns true when the match is over
DM_fnc_playRound = {
    private _relRoundNumber = call DM_fnc_prepareRound;
    [_relRoundNumber] call DM_fnc_runEquipPhase;
    [_relRoundNumber] call DM_fnc_runFight;

    call DM_fnc_finishRound
};

// map/sides, everyone back to the HQ, cleanup and AI; returns the relative round number
DM_fnc_prepareRound = {
    terminate DM_var_playZoneLoopHdl;

    if (DM_var_alternatingMaps) then {
        (call DM_fnc_getCurrentMap) params ["_mapIndex", "_switchedSides"];
        [_mapIndex, _switchedSides] call DM_fnc_applyMap;

        if (_switchedSides && {!DM_var_repeatRound}) then {
            ["teamDeathmatch", ["Same map again, the teams switch sides"]] call DM_fnc_showNotificationGlobal;
        };
    } else {
        // halftime: the teams swap their bases (not again when a drawn round is repeated)
        if (DM_var_roundNumber == DM_var_minPointsToWin && {DM_var_minPointsToWin != 1} && {!DM_var_repeatRound}) then {
            call DM_fnc_switchSides;
            ["teamDeathmatch", ["Halftime, the teams switch sides"]] call DM_fnc_showNotificationGlobal;
        };
    };

    DM_var_repeatRound = false;

    [false] call DM_fnc_movement;
    call DM_fnc_setAllPlayersToSpawn;

    sleep 1;

    call DM_fnc_despawnAi;
    call DM_fnc_cleanUp;
    [DM_var_respawnDelay] call DM_fnc_setRespawnTimeTo;    // respawns dead players

    private _relRoundNumber = [DM_var_roundNumber] call DM_fnc_relativeRoundNumber;
    [_relRoundNumber] call DM_fnc_startAiBalance;
    ["teamDeathmatch", ["Waiting for other players"]] call DM_fnc_showNotificationGlobal;
    DM_var_playZoneLoopHdl = [] spawn DM_fnc_playZoneLoop;

    [false] call DM_fnc_waitForPlayersReady;

    _relRoundNumber
};

DM_fnc_runEquipPhase = {
    params ["_relRoundNumber"];

    [DM_var_roundNumber] call DM_fnc_roundStartedNotification;
    [_relRoundNumber] call DM_fnc_startEquipPhaseGlobal;
    DM_var_timerHdl = [DM_var_equipPhaseDuration] spawn DM_fnc_timer;

    sleep 2;

    if (DM_var_vehiclesEnabled) then {
        call DM_fnc_spawnVehiclesForSides;
        call DM_fnc_startVehicleLoop;
    };

    sleep 3;

    // the round starts when the equip phase is over or everyone is ready and out of the arsenal
    waitUntil {
        sleep DM_var_readyPollInterval;
        scriptDone DM_var_timerHdl || {call DM_fnc_bothSidesHaveUnits && {[true] call DM_fnc_allPlayersReady}}
    };

    if (!scriptDone DM_var_timerHdl) then {
        terminate DM_var_timerHdl;
    };
};

/*
    Fight until one team is dead or the round time limit is reached; the zone starts shrinking after
    DM_var_zoneShrinkDelay. Before that the AI balance stops: players still loading are benched and a last balance
    counts only the players who fight.
*/
DM_fnc_runFight = {
    params ["_relRoundNumber"];

    call DM_fnc_stopAiBalance;
    call DM_fnc_benchLoadingPlayers;
    [_relRoundNumber, true] spawn DM_fnc_balanceAi;

    [true] call DM_fnc_gameRunning;
    [true] call DM_fnc_movement;
    call DM_fnc_fightStartedNotification;
    [DM_var_noRespawnTime] call DM_fnc_setRespawnTimeTo;

    private _startTime = time;
    private _zoneShrinkPending = DM_var_zoneShrinkEnabled;
    private _hasTimeLimit = DM_var_roundTimeLimit > 0;

    // HUD timer: the time limit if there is one, otherwise the zone countdowns (the second one: DM_fnc_zoneShrink)
    switch (true) do {
        case _hasTimeLimit: {
            DM_var_timerHdl = [DM_var_roundTimeLimit] spawn DM_fnc_timer;
        };
        case _zoneShrinkPending: {
            DM_var_timerHdl = [DM_var_zoneShrinkDelay] spawn DM_fnc_timer;
        };
        default {
            call DM_fnc_setTimerTo0;
        };
    };

    waitUntil {
        sleep DM_var_roundEndPollInterval;

        if (_zoneShrinkPending && {time - _startTime >= DM_var_zoneShrinkDelay}) then {
            _zoneShrinkPending = false;
            ["zone"] call DM_fnc_showNotificationGlobal;
            DM_var_roundHdl = [] spawn DM_fnc_zoneShrink;
        };

        call DM_fnc_oneTeamDead || {_hasTimeLimit && {time - _startTime >= DM_var_roundTimeLimit}}
    };

    if (!scriptDone DM_var_roundHdl) then {
        terminate DM_var_roundHdl;
    };

    call DM_fnc_stopVehicleLoop;
};

// scores the round, a draw gives no point and the round is repeated; returns true when the match is over
DM_fnc_finishRound = {
    private _winSide = call DM_fnc_getWinSide;
    private _isDraw = _winSide == sideUnknown;

    if (_isDraw) then {
        ["teamDeathmatch", ["Draw - the round is repeated"]] call DM_fnc_showNotificationGlobal;
    } else {
        [_winSide] call DM_fnc_increaseSidesScore;
        [([_winSide] call DM_fnc_getSideString) + "wonThisRound"] call DM_fnc_showNotificationGlobal;
    };

    [false] call DM_fnc_gameRunning;
    call DM_fnc_resetPlayZone;
    call DM_fnc_setTimerTo0;

    if (!scriptDone DM_var_timerHdl) then {
        terminate DM_var_timerHdl;
    };

    DM_var_timerHdl = [DM_var_roundEndDelay] spawn DM_fnc_timer;
    waitUntil {scriptDone DM_var_timerHdl};

    if (_isDraw) exitWith {
        DM_var_repeatRound = true;
        false
    };

    private _leaderPoints = DM_var_westPoints max DM_var_eastPoints;
    private _lead = abs (DM_var_westPoints - DM_var_eastPoints);

    if (_leaderPoints >= DM_var_minPointsToWin && {!DM_var_requireLeadOfTwoPoints || {_lead >= 2}}) exitWith {
        [_winSide] call DM_fnc_runMatchEnd;
        [(toLowerANSI str _winSide), _winSide] remoteExecCall ["DM_fnc_endMissionLocal", 0];
        true
    };

    DM_var_roundNumber = DM_var_roundNumber + 1;
    publicVariable "DM_var_roundNumber";
    false
};

/*
    Waits until both sides have a unit and every player is ready (DM_fnc_playerReady). A player who is still not
    ready after DM_var_readyTimeout is not waited for any longer; if he is still loading when the round starts, he
    spectates it (DM_fnc_benchLoadingPlayers).
*/
// every machine: ends the mission at once, without the signature closing shot (its "<SIDE> WON" title would appear
// behind the match end texts); players of the winning side get the victory debriefing
DM_fnc_endMissionLocal = {
    params ["_end", "_winner"];

    [_end, (!hasInterface) || {(side group player) == _winner}, false] call BIS_fnc_endMission;
};

DM_fnc_waitForPlayersReady = {
    params ["_includeArsenal"];

    private _timeout = time + DM_var_readyTimeout;

    waitUntil {
        sleep DM_var_readyPollInterval;
        call DM_fnc_bothSidesHaveUnits && {time >= _timeout || {[_includeArsenal] call DM_fnc_allPlayersReady}}
    };
};

/*
    Round start: a player still loading would keep his team alive from the HQ. He is taken out of the round and
    spectates until the next one, like a player who joins during a round.
*/
DM_fnc_benchLoadingPlayers = {
    {
        _x enableSimulationGlobal false;
        [] remoteExec ["DM_fnc_benchPlayer", _x];
    } forEach (allPlayers select {alive _x && {simulationEnabled _x} && {_x getVariable ["CMN_var_isLoading", false]}});
};

// ---- round state (server publishes, clients react) ----

DM_fnc_setTimerTo0 = {
    DM_var_timerStr = "0:00";
    publicVariable "DM_var_timerStr";
};

// also locks the team vehicles while movement is disabled (equip phase)
DM_fnc_movement = {
    params ["_state"];

    DM_var_movingEnabled = _state;
    publicVariable "DM_var_movingEnabled";
    [!_state] call DM_fnc_lockTeamVehicles;
};

DM_fnc_gameRunning = {
    params ["_state"];

    DM_var_gameRunning = _state;
    publicVariable "DM_var_gameRunning";
};

DM_fnc_setRespawnTimeTo = {
    params ["_respawnTime"];

    DM_var_respawnTime = _respawnTime;
    publicVariable "DM_var_respawnTime";
};

// counts down from _seconds to 0, publishing DM_var_timerStr once per second
DM_fnc_timer = {
    params ["_seconds"];

    for "_remaining" from _seconds to 0 step -1 do {
        DM_var_timerStr = [_remaining] call DM_fnc_durationToMinSec;
        publicVariable "DM_var_timerStr";
        sleep 1;
    };
};

// 75 -> "1:15"
DM_fnc_durationToMinSec = {
    params ["_seconds"];

    private _secs = _seconds mod 60;

    format ["%1:%2%3", floor (_seconds / 60), ["", "0"] select (_secs < 10), _secs]
};

// [template, args] like BIS_fnc_showNotification, on every machine with an interface
DM_fnc_showNotificationGlobal = {
    _this remoteExecCall ["DM_fnc_showNotificationClient", [0, -2] select isDedicated];
};

DM_fnc_showNotificationClient = {
    if (hasInterface) then {
        _this call BIS_fnc_showNotification;
    };
};

DM_fnc_roundStartedNotification = {
    params ["_roundNumber"];

    private _newEquipmentUnlocked = if (!DM_var_loadoutsRestricted || _roundNumber == 1) then {
        false
    } else {
        private _relRoundNumber = [_roundNumber] call DM_fnc_relativeRoundNumber;
        private _oldRelRoundNumber = [_roundNumber - 1] call DM_fnc_relativeRoundNumber;

        // more unlock rounds reached now than in the previous round
        ({_x <= _relRoundNumber} count DM_var_unlockRounds) > ({_x <= _oldRelRoundNumber} count DM_var_unlockRounds)
    };

    private _text = format ["Round starts in %1 seconds", DM_var_equipPhaseDuration];

    if (_newEquipmentUnlocked) then {
        _text = _text + ". New equipment unlocked";
    };

    ["teamDeathmatch", [_text]] call DM_fnc_showNotificationGlobal;

    private _matchPointSides = call DM_fnc_matchPointSides;

    if (_matchPointSides isNotEqualTo []) then {
        private _matchPointText = if (count _matchPointSides == 2) then {
            "Match point for both teams"
        } else {
            "Match point " + ([_matchPointSides select 0] call DM_fnc_getSideString)
        };

        ["teamDeathmatch", [_matchPointText]] call DM_fnc_showNotificationGlobal;
    };
};

DM_fnc_fightStartedNotification = {
    private _text = "Round started";

    if (DM_var_zoneShrinkEnabled) then {
        _text = _text + format [". Zone shrinks in %1 seconds", DM_var_zoneShrinkDelay];
    };

    if (DM_var_roundTimeLimit > 0) then {
        _text = _text + format [". Time limit %1", [DM_var_roundTimeLimit] call DM_fnc_durationToMinSec];
    };

    ["teamDeathmatch", [_text]] call DM_fnc_showNotificationGlobal;
};

// client: blocks walking, firing and throwing while the server has movement disabled
DM_fnc_movementClient = {
    params ["_movingEnabled"];

    if (_movingEnabled) exitWith {
        if (!isNil "DM_var_movementEH") then {
            (findDisplay 46) displayRemoveEventHandler ["KeyDown", DM_var_movementEH];
            DM_var_movementEH = nil;
        };

        if (!isNil "DM_var_fireId") then {
            player removeAction DM_var_fireId;
            DM_var_fireId = nil;
        };
    };

    if (!isNil "DM_var_movementEH") exitWith {};

    DM_var_movementEH = (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["", "_key"];

        private _blockedKeys = actionKeys "moveForward" + actionKeys "moveBack" + actionKeys "TurnLeft" +
            actionKeys "TurnRight" + actionKeys "MoveFastForward" + actionKeys "MoveSlowForward" + actionKeys "Throw";

        if (_key in _blockedKeys) then {
            true
        };
    }];

    // an empty action on the fire key ("DefaultAction") swallows shots
    DM_var_fireId = player addAction ["", {}, "", 0, false, true, "DefaultAction"];
};

// "FiredMan" (client): a grenade or explosive thrown or placed while movement is disabled (e.g. other key) is taken back
DM_fnc_firedMan = {
    params ["_unit", "_weapon", "", "", "", "_magazine", "_projectile"];

    if (DM_var_movingEnabled || {!(_weapon in ["Throw", "Put"])}) exitWith {};

    deleteVehicle _projectile;
    _unit addMagazine _magazine;
};

/*
    Client, scheduled (remoteExec by DM_fnc_benchLoadingPlayers): the round started while this client was loading.
    Once loading is done the player is parked out of sight and spectates; the next round frees him
    (DM_fnc_respawnTimeLoop).
*/
DM_fnc_benchPlayer = {
    waitUntil {!(player getVariable ["CMN_var_isLoading", false])};

    if (simulationEnabled player || {!DM_var_gameRunning}) exitWith {};

    call DM_fnc_closeArs;
    player setPos [0, 0, 100];
    [] spawn DM_fnc_spectator;
};

DM_fnc_movementLoop = {
    private _movingEnabled = true;

    waitUntil {
        if (DM_var_movingEnabled isNotEqualTo _movingEnabled) then {
            _movingEnabled = DM_var_movingEnabled;
            [_movingEnabled] call DM_fnc_movementClient;
        };

        false
    };
};

// applies the server's respawn time; when respawning opens, players parked as spectators get simulated again
DM_fnc_respawnTimeLoop = {
    private _respawnTime = DM_var_noRespawnTime;

    waitUntil {
        if (DM_var_respawnTime != _respawnTime) then {
            _respawnTime = DM_var_respawnTime;
            setPlayerRespawnTime _respawnTime;

            if (_respawnTime == DM_var_respawnDelay && {!simulationEnabled player}) then {
                sleep 3;
                [player, true] call CMN_fnc_setSimulationGlobal;
            };
        };

        false
    };
};
