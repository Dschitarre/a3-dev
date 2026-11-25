// Battle Royale match flow (server; clients follow the published state): warmup at the start area while the roster is
// balanced, then the flight and the fight until one team is left (BR\results.sqf ends it).
// BR_var_state: "warmup" -> "flight" (combatants aboard) -> "fight" (everyone jumped) -> "ended".

// BR_var_stateEndTime: serverTime the warmup ends, -1 while it waits for the first player

BR_var_balanceInterval = 1;         // warmup: roster rebalancing (players joining / leaving)
BR_var_startAreaMargin = 150;       // warmup: a player this far outside of the start area is brought back
BR_var_prepareLead = 25;            // s before the warmup ends the match start is prepared (BR_fnc_prepareMatch)

// ---- state (server publishes, clients read) ----

BR_fnc_initMatchStateServer = {
    BR_var_state = "";
    BR_var_aliveCounts = [0, 0];
    BR_var_airdropCrates = [];

    publicVariable "BR_var_aliveCounts";
    publicVariable "BR_var_airdropCrates";
    ["warmup"] call BR_fnc_setState;
};

BR_fnc_setState = {
    params ["_state", ["_endTime", -1]];

    BR_var_stateEndTime = _endTime;
    BR_var_state = _state;
    publicVariable "BR_var_stateEndTime";
    publicVariable "BR_var_state";
};

// [template, args] like BIS_fnc_showNotification, on every machine with an interface
BR_fnc_notifyAll = {
    _this remoteExecCall ["BR_fnc_notifyClient", [0, -2] select isDedicated];
};

BR_fnc_notifyClient = {
    if (hasInterface) then {
        _this call BIS_fnc_showNotification;
    };
};

// ---- match (server) ----

BR_fnc_matchLoop = {
    // the loot site markers from the mission start on: players see them in the warmup already (user 2026-11-24)
    [] spawn {
        call BR_fnc_findLootTents;
        call BR_fnc_markLootSites;
    };
    call BR_fnc_runWarmup;
    call BR_fnc_startMatch;
};

// the countdown starts with the first player and restarts when everyone left
BR_fnc_runWarmup = {
    waitUntil {
        call BR_fnc_balanceRoster;

        private _hasPlayers = (BR_var_rosterUnits findIf {isPlayer _x}) != -1;

        if (_hasPlayers && {BR_var_stateEndTime < 0}) then {
            ["warmup", serverTime + BR_var_warmupTime] call BR_fnc_setState;
            ["brInfo", [format ["Match starts in %1 s", BR_var_warmupTime]]] call BR_fnc_notifyAll;
        };

        if (!_hasPlayers && {BR_var_stateEndTime >= 0}) then {
            ["warmup"] call BR_fnc_setState;
        };

        // the heavy part of the match start while everyone still runs around (no frozen screen at the flight)
        if (_hasPlayers && {isNil "BR_var_prepareScript"} && {serverTime >= BR_var_stateEndTime - BR_var_prepareLead}) then {
            BR_var_prepareScript = [] spawn BR_fnc_prepareMatch;
        };

        call BR_fnc_keepPlayersInStartArea;
        call BR_fnc_cleanUpGroups;
        sleep BR_var_balanceInterval;
        _hasPlayers && {serverTime >= BR_var_stateEndTime}
    };
};

// warmup: a set-up player far outside of the start area (whatever moved him) gets a new spot in it; logged
BR_fnc_keepPlayersInStartArea = {
    {
        if (
            alive _x &&
            {simulationEnabled _x} &&
            {isNull objectParent _x} &&
            {((_x getVariable ["BR_var_role", []]) param [1, ""]) == "warmup"} &&
            {_x distance2D BR_var_startAreaCenter > BR_var_startAreaRadius + BR_var_startAreaMargin}
        ) then {
            diag_log format ["BR warmup: %1 outside of the start area at %2, sent back", name _x, getPosATL _x];
            [] remoteExecCall ["BR_fnc_returnToStartArea", _x];
        };
    } forEach (allPlayers select {!(_x isKindOf "HeadlessClient_F")});
};

/*
    Scheduled, BR_var_prepareLead before the warmup ends: the extra AI (parked), the first zone and the AI drop spots -
    the work that made the server hang at the flight start.
*/
BR_fnc_prepareMatch = {
    private _startTime = diag_tickTime;

    call BR_fnc_createExtraAi;
    call BR_fnc_planFirstZone;
    call BR_fnc_planAiDropSpots;
    call BR_fnc_buildLandmasses;
    diag_log format ["BR match prepared in %1 s: %2 extra AI, %3 drop spots", (diag_tickTime - _startTime) toFixed 1, count BR_var_extraUnits, count BR_var_aiDropSpots];
};

// everyone boards, the aircraft takes off; vehicles, zone, loot and AI start working
BR_fnc_startMatch = {
    if (isNil "BR_var_prepareScript") then {
        BR_var_prepareScript = [] spawn BR_fnc_prepareMatch;
    };

    waitUntil {
        sleep 0.1;
        scriptDone BR_var_prepareScript
    };

    call BR_fnc_lockRoster;

    call BR_fnc_planFlight;
    call BR_fnc_assignJumpPoints;
    call BR_fnc_createAircraft;
    ["flight"] call BR_fnc_setState;
    call BR_fnc_publishAliveCounts;
    // notifications are structured text: "&" of names like "Kore & Syrta" has to be an entity
    ["brInfo", [(BR_var_playAreaName splitString "&") joinString "&amp;"]] call BR_fnc_notifyAll;

    [] spawn BR_fnc_spawnVehicles;
    [] spawn BR_fnc_flightLoop;
    [] spawn BR_fnc_zoneLoop;
    [] spawn BR_fnc_zoneDamageLoop;
    [] spawn BR_fnc_lootLoop;
    [] spawn BR_fnc_aiLoop;
};
