// GunGame spawning (server and client): spawning anywhere in the play zone out of sight, player spawn and death.

// client scripts of the player's spawn flow (GG_fnc_endRoundClient stops them)
GG_var_respawnScreenScript = scriptNull;
GG_var_spawnPlayerScript = scriptNull;
GG_var_playZoneLoopScript = scriptNull;

// ---- spawning ----

// true if no unit of _watchers is within a third of the zone size of _pos (AGL) or can see it
GG_fnc_isHiddenFrom = {
    params ["_pos", "_watchers"];

    // checkVisibility takes ASL positions: a point 1.5 m above the ground
    private _targetASL = (AGLToASL _pos) vectorAdd [0, 0, 1.5];

    (_watchers findIf {
        alive _x && {
            _x distance _pos <= GG_var_maxZoneSize / 3 ||
            {([objNull, "VIEW"] checkVisibility [eyePos _x, _targetASL]) > 0}
        }
    }) == -1
};

/*
    Scheduled, one candidate per frame: dry land in the zone under open sky, far from _lastSpawnPos and hidden from
    everyone; after GG_var_spawnSearchTimeout any dry open-sky spot. _aiUnit: stop once a player takes the unit over.
*/
GG_fnc_findSpawnPos = {
    params ["_lastSpawnPos", ["_aiUnit", objNull]];

    private _startTime = time;
    private _center = getMarkerPos "GG_var_playZone";
    _center = [_center select 0, _center select 1, 0];
    private _spawnPos = _center;
    private _watchers = [];
    private _nextWatcherUpdate = 0;

    waitUntil {
        if (isPlayer _aiUnit) exitWith {true};

        _spawnPos = [_center, 0, GG_var_maxZoneSize, 3, 0, 0, 0, [], _center] call BIS_fnc_findSafePos;
        _spawnPos = [_spawnPos select 0, _spawnPos select 1, 0];

        // the unit scan is the expensive part; the units barely move between two refreshes
        if (time >= _nextWatcherUpdate) then {
            _nextWatcherUpdate = time + GG_var_watcherUpdateInterval;
            _watchers = (entities [["CAManBase"], [], true, false]) inAreaArray "GG_var_playZone";
        };

        !surfaceIsWater _spawnPos &&
        {_spawnPos inArea "GG_var_playZone"} &&
        {[_spawnPos] call CMN_fnc_isUnderOpenSky} &&
        {
            time - _startTime >= GG_var_spawnSearchTimeout ||
            {
                _spawnPos isNotEqualTo _center &&
                {_lastSpawnPos distance _spawnPos >= GG_var_minTravelRatio * GG_var_maxZoneSize} &&
                {[_spawnPos, _watchers] call GG_fnc_isHiddenFrom}
            }
        }
    };

    _spawnPos
};

// "Respawn" event handler (client) -> server
GG_fnc_respawnServer = {
    params ["", "_corpse"];

    deleteVehicle _corpse;
};

// ---- player spawn and death (client) ----

// scheduled: spawns the player at a hidden spot in the zone
GG_fnc_spawnPlayer = {
    call CMN_fnc_hideCenterText;

    private _spawnPos = [GG_var_lastSpawnPos] call GG_fnc_findSpawnPos;

    if (!(_spawnPos inArea "GG_var_playZone")) exitWith {
        GG_var_spawnPlayerScript = [] spawn GG_fnc_spawnPlayer;
    };

    setPlayerRespawnTime 0;
    waitUntil {alive player};

    if (!isNull GG_var_playZoneLoopScript) then {
        terminate GG_var_playZoneLoopScript;
    };

    GG_var_playZoneLoopScript = [] spawn GG_fnc_playZoneLoop;

    player setPos _spawnPos;
    player setDir ((getDir player + (player getRelDir getMarkerPos "GG_var_playZone")) mod 360);
    player setVelocity [0, 0, 0];
    player setVariable ["GG_var_lastPos", getPosATL player];

    [] spawn GG_fnc_watchSpawnInZone;

    [player, true] call CMN_fnc_setSimulationGlobal;
    player switchCamera CMN_var_lastView;
    cutText ["", "BLACK IN", 1];
    [player] call GG_fnc_setRating;

    // with the earplugs that are in (earplugs mod)
    1 fadeSound (call (missionNamespace getVariable ["E_fnc_effectiveVolume", {1}]));
    [player] call GG_fnc_startSpawnProtection;
    call CMN_fnc_startCameraViewLoop;
    [player] call GG_fnc_applyWeapon;
    waitUntil {!isNull player};
    call CMN_fnc_restoreNightVision;
};

// first second after a spawn: a player who ends up outside of the zone is blacked out and spawned again
GG_fnc_watchSpawnInZone = {
    private _startTime = time;

    waitUntil {
        if (!(player inArea "GG_var_playZone")) exitWith {
            terminate GG_var_spawnPlayerScript;
            call CMN_fnc_stopCameraViewLoop;
            [player, false] call CMN_fnc_setSimulationGlobal;
            cutText ["", "BLACK FADED", 9999];
            0 fadeSound 0;
            GG_var_spawnPlayerScript = [] spawn GG_fnc_spawnPlayer;
            true
        };

        time - _startTime >= 1
    };
};

// the respawn screen, unless it is already open
GG_fnc_openRespawnScreen = {
    if (!scriptDone GG_var_respawnScreenScript) exitWith {};

    GG_var_respawnScreenScript = [] spawn GG_fnc_respawnScreen;
};

// "press space", then spawn; a round end (GG_var_ended) closes it, the next round opens it again
GG_fnc_respawnScreen = {
    if (!isNull GG_var_playZoneLoopScript) then {
        terminate GG_var_playZoneLoopScript;
    };

    if (GG_var_ended || {!(["<t align='center'>Press space to spawn</t>", {GG_var_ended}] call CMN_fnc_waitForSpaceKey)}) exitWith {};

    GG_var_spawnPlayerScript = [] spawn GG_fnc_spawnPlayer;
};

// "Respawn" event handler
GG_fnc_respawn = {
    params ["_unit", "_corpse"];

    [_unit, _corpse] remoteExec ["GG_fnc_respawnServer", 2];
};

// "Killed" event handler: the respawn screen after the kill cam (killfeed)
GG_fnc_killed = {
    setPlayerRespawnTime 9999;
    call CMN_fnc_stopCameraViewLoop;
    GG_var_lastSpawnPos = getPosATL player;

    [] spawn {
        sleep 4;

        if (!isNil "KF_fnc_waitUntilKillCamDone") then {
            call KF_fnc_waitUntilKillCamDone;
        };

        call GG_fnc_openRespawnScreen;
    };
};
