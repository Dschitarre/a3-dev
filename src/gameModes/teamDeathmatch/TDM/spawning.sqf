// Team Deathmatch spawning (server and client): spawn positions at the HQs, player spawn and death, spectator.
// Markers in mission.sqm: DM_mrk_westHQ, DM_mrk_eastHQ, respawn_west, respawn_east.

// ---- spawn positions ----

DM_fnc_hqMarker = {
    params ["_side"];

    "DM_mrk_" + toLowerANSI str _side + "HQ"
};

DM_fnc_respawnMarker = {
    params ["_side"];

    "respawn_" + toLowerANSI str _side
};

/*
    Scheduled. An empty spot for _type around _pos (growing radius) under open sky, optionally within _maxDist of _pos.
    After _timeout seconds _pos itself is returned.
*/
DM_fnc_findSpawnPos = {
    params ["_pos", "_type", "_timeout", ["_maxDist", -1]];

    private _spawnPos = [];
    private _radius = 3;
    private _startTime = time;

    waitUntil {
        waitUntil {_pos findEmptyPositionReady [0, _radius]};
        _spawnPos = _pos findEmptyPosition [0, _radius, _type];
        _radius = _radius + 0.5;

        if (_spawnPos isNotEqualTo []) then {
            _spawnPos = [_spawnPos select 0, _spawnPos select 1, 0];
        };

        if(_spawnPos isNotEqualTo [] && {_maxDist < 0 || {_spawnPos distance _pos < _maxDist}} &&
            {[_spawnPos] call CMN_fnc_isUnderOpenSky}) exitWith {
            true
        };

        if (time - _startTime > _timeout) exitWith {
            _spawnPos = _pos;
            true
        };

        false
    };

    _spawnPos
};

// ---- player spawn and death ----

// the game volume after the mission's own fades (black screens, spectator): the one of the earplugs that are in
// (earplugs mod), else the full volume
DM_fnc_soundVolume = {
    call (missionNamespace getVariable ["E_fnc_effectiveVolume", {1}])
};

// server: every living player back to his HQ
DM_fnc_setAllPlayersToSpawn = {
    [] remoteExecCall ["DM_fnc_setToSpawnIfAlive", [0, -2] select isDedicated];
};

DM_fnc_setToSpawnIfAlive = {
    if (hasInterface && {!isNull player} && {alive player}) then {
        [true] spawn DM_fnc_setToSpawn;
    };
};

// scheduled: moves the player to a free spot at his HQ and keeps him there for 2 s
DM_fnc_setToSpawn = {
    params ["_transitionEnabled"];

    if (_transitionEnabled) then {
        1 fadeSound 0;
        cutText ["", "BLACK OUT", 0, true];
        sleep 1;
    };

    private _side = side group player;
    private _spawnPos = [getMarkerPos ([_side] call DM_fnc_hqMarker), "B_Soldier_F", 2, 5] call DM_fnc_findSpawnPos;

    player setPos _spawnPos;
    private _startTime = time;
    player setDamage 0;
    [_transitionEnabled] call DM_fnc_ehRespawnClient;

    waitUntil {
        if (player distance _spawnPos > 10) then {
            player setPos _spawnPos;
            player setDir markerDir ([_side] call DM_fnc_respawnMarker);
            player setVelocity [0, 0, 0];
        };

        time - _startTime > 2
    };
};

// everything a (re)spawn at the HQ resets: camera, loadout, NV, sound, spawn protection
DM_fnc_ehRespawnClient = {
    params ["_transitionEnabled"];

    if (!DM_var_gpsSet) then {
        call CMN_fnc_enableGps;
        DM_var_gpsSet = true;
    };

    [player, false] call ADG_fnc_allowDamage;
    if (missionNamespace getVariable ["DM_var_tdIconsEnabled", false]) then {
        call TDI_fnc_startTdIconsClient;
    };
    private _nvWasEnabled = CMN_var_nvGogglesEnabled;
    player switchCamera CMN_var_lastView;
    call CMN_fnc_startCameraViewLoop;
    player setDir markerDir ([side group player] call DM_fnc_respawnMarker);
    1 fadeSound (call DM_fnc_soundVolume);
    player setUnitLoadout (player getVariable "DM_var_lastLoadout");

    // the loadout change switches the goggles off (and with them the NV state): restore both
    [_nvWasEnabled] spawn {
        params ["_nvWasEnabled"];

        if (_nvWasEnabled) then {
            waitUntil {!CMN_var_nvGogglesEnabled};
            CMN_var_nvGogglesEnabled = true;
        };

        waitUntil {!isNull player};
        player switchMove "UP";
        call CMN_fnc_restoreNightVision;
    };

    if (_transitionEnabled) then {
        cutText ["", "BLACK IN", 0, true];
    };

    // spawn protection until 3 s after spawning and the round has started
    [] spawn {
        sleep 3;
        waitUntil {DM_var_movingEnabled};
        [player, true] call ADG_fnc_allowDamage;
    };
};

// "Respawn" event handler
DM_fnc_respawn = {
    params ["", "_corpse"];

    [player, true] call CMN_fnc_setSimulationGlobal;
    ["Terminate"] call BIS_fnc_EGSpectator;
    [isNull _corpse] call DM_fnc_ehRespawnClient;

    player addAction [
        "<img size='1.1' color='#ffffff' shadow='2' image='\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\rearm_ca.paa'/> Change Loadout",
        {call DM_fnc_openArs},
        nil,
        1.5,
        true,
        false,
        "",
        "player distance getMarkerPos ([side group player] call DM_fnc_hqMarker) <= 7 && !DM_var_gameRunning",
        0
    ];

    // warmup: map vote (common\vote.sqf) and ready check (DM_fnc_waitForWarmupEnd)
    player addAction ["Map vote", {call CMN_fnc_openVoteDialog}, nil, 1.4, false, true, "", "CMN_var_vote isNotEqualTo []", 0];
    player addAction [
        "Ready (shortens the warmup)",
        {player setVariable ["DM_var_warmupReady", true, true]},
        nil,
        1.3,
        false,
        true,
        "",
        "DM_var_inWarmup && {!(player getVariable ['DM_var_warmupReady', false])}",
        0
    ];
    player addAction [
        "Not ready",
        {player setVariable ["DM_var_warmupReady", false, true]},
        nil,
        1.3,
        false,
        true,
        "",
        "DM_var_inWarmup && {player getVariable ['DM_var_warmupReady', false]}",
        0
    ];

    if (!DM_var_gameRunning && {!isNull _corpse}) then {
        deleteVehicle _corpse;
    };
};

// "Killed" event handler: during a round the dead player can switch to the spectator, after the kill cam (killfeed)
DM_fnc_killed = {
    if (playerRespawnTime>10 && {!isNil "KF_fnc_markRoundEliminated"}) then {call KF_fnc_markRoundEliminated};
    call CMN_fnc_stopCameraViewLoop;

    if (!simulationEnabled player) exitWith {};

    [] spawn {
        sleep 4;

        if (!isNil "KF_fnc_waitUntilKillCamDone") then {
            call KF_fnc_waitUntilKillCamDone;
        };

        if (playerRespawnTime <= 10) exitWith {};

        ["<t align='center'>Press space to spectate</t>", {alive player}] call CMN_fnc_waitForSpaceKey;
        ["", 0, 0, 0, 0, 0, 788] spawn BIS_fnc_dynamicText;

        if (!alive player) then {
            [] spawn DM_fnc_spectator;
        };
    };
};

// ---- spectator (client) ----

DM_fnc_spectator = {
    ["", 0, 0, 0, 0, 0, 788] spawn BIS_fnc_dynamicText;

    private _sides = if (TDI_var_showAllSidesOnSpectator) then {[west, east]} else {[side group player]};

    ["Initialize", [
        player,
        _sides,
        true,
        RscSpectator_allowFreeCam,
        RscSpectator_allowFreeCam,
        true,
        false,
        false,
        false,
        true
    ]] call BIS_fnc_EGSpectator;
    call TDI_fnc_stopTdIconsClient;

    if (RscSpectator_allowFreeCam) exitWith {
        cutText ["", "PLAIN", 0, true];
        0.5 fadeSound (call DM_fnc_soundVolume);
    };

    // without free camera the view stays black while the camera is not on a living unit
    [] spawn {
        private _showing = false;

        waitUntil {
            private _onLivingUnit = simulationEnabled focusOn && {alive focusOn} &&
                {positionCameraToWorld [0, 0, 0] distance [0, 0, 0] > 100};

            if (_onLivingUnit isNotEqualTo _showing) then {
                _showing = _onLivingUnit;
                cutText ["", ["BLACK FADED", "PLAIN"] select _showing, 0, true];
                0 fadeSound ([0, call DM_fnc_soundVolume] select _showing);
            };

            simulationEnabled player && {alive player} && {!isNull (findDisplay 46)}
        };

        ["Terminate"] call BIS_fnc_EGSpectator;
        cutText ["", "BLACK FADED", 9999, true];
    };
};
