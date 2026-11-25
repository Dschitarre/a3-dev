// Lag switch detection (server): detects clients whose heartbeat stopped, and logs kills they made right after
// reconnecting to the RPT. Safe to load twice (addon and mission): everything only starts once.

// thresholds: a mission may set them before this file is loaded
if (isNil "LD_var_lagTime") then {LD_var_lagTime = 3;};                       // seconds without heartbeat that count as a lag
if (isNil "LD_var_suspectTime") then {LD_var_suspectTime = 10;};              // seconds a client stays a suspect after reconnecting
if (isNil "LD_var_includeAiVictims") then {LD_var_includeAiVictims = true;};  // also log kills of AI units

if (isNil "LD_var_clients") then {LD_var_clients = createHashMap;};
if (isNil "LD_var_lagScript") then {LD_var_lagScript = scriptNull;};
if (isNil "LD_var_entityKilledEhId") then {LD_var_entityKilledEhId = -1;};

// ---- lag detection ----
// Server-local state per client (network ID), so it never sticks to a unit that changes hands (slot taken over by
// AI or another player): [lastHeartbeat, isSuspect, lagStartTime, timeToReconnect]   (unknown times are -1)

LD_fnc_heartbeat = {
    params ["_serverTime"];

    private _client = LD_var_clients get remoteExecutedOwner;

    if (isNil "_client") exitWith {
        LD_var_clients set [remoteExecutedOwner, [_serverTime, false, -1, -1]];
    };

    _client set [0, _serverTime];
};

LD_fnc_updateLagState = {
    params ["_client", "_canBecomeSuspect"];
    _client params ["_lastHeartbeat", "_isSuspect", "_lagStart", "_timeToReconnect"];

    private _silence = serverTime - _lastHeartbeat;

    if (!_isSuspect) exitWith {
        if (_silence > LD_var_lagTime && {_canBecomeSuspect}) then {
            _client set [1, true];
            _client set [2, serverTime - LD_var_lagTime];
        };
    };

    if (_timeToReconnect == -1) exitWith {
        if (_silence < LD_var_lagTime) then {
            _client set [3, serverTime - _lagStart];
        };
    };

    if (_silence > LD_var_lagTime || {serverTime - (_lagStart + _timeToReconnect) > LD_var_suspectTime}) then {
        _client set [1, false];
        _client set [2, -1];
        _client set [3, -1];
    };
};

LD_fnc_startLagDetectionServer = {
    if (!isNull LD_var_lagScript) exitWith {};

    LD_var_lagScript = [] spawn {
        waitUntil {
            private _clients = values LD_var_clients;

            // more than half of the clients silent at once: the server itself hitched, nobody becomes a suspect
            private _silentCount = {serverTime - (_x select 0) > LD_var_lagTime} count _clients;
            private _canBecomeSuspect = _silentCount * 2 <= count _clients;

            {
                [_x, _canBecomeSuspect] call LD_fnc_updateLagState;
            } forEach _clients;

            sleep 0.25;
            false
        };
    };

    addMissionEventHandler ["PlayerDisconnected", {
        params ["", "", "", "", "_owner"];

        LD_var_clients deleteAt _owner;
    }];
};

// ---- kills ----
// The kill of a lag switcher usually arrives when he reconnects, so the killer is watched for a while.

LD_fnc_logKill = {
    params ["_unit", "_killer", "_client"];
    _client params ["", "", "_lagStart", "_timeToReconnect"];

    {
        diag_log _x;
    } forEach [
        "################### Possible LAGswitch DETECTED ###################",
        format [
            " Suspect %1 (%2) killed %3%4 from %5m",
            name _killer,
            getPlayerUID _killer,
            name _unit,
            ["", " (AI)"] select (!isPlayer _unit),
            [_unit distance _killer, 1] call BIS_fnc_cutDecimals
        ],
        format [
            " LCT: %1s, TtRC: %2s, KaRT: %3s",
            _lagStart,
            _timeToReconnect,
            serverTime - (_lagStart + _timeToReconnect)
        ],
        "##########################################################"
    ];
};

LD_fnc_entityKilled = {
    params ["_unit", "_killer", "_instigator"];

    if (isNull _instigator) then {
        _instigator = (UAVControl vehicle _killer) select 0;
    };

    if (isNull _instigator) then {
        _instigator = _killer;
    };

    if (isNull _unit || {isNull _instigator} || {_unit isEqualTo _instigator} || {!isPlayer _instigator}) exitWith {};

    // the victim: a player or, with LD_var_includeAiVictims, an AI unit
    if (!isPlayer _unit && {!LD_var_includeAiVictims || {!(_unit isKindOf "CAManBase")}}) exitWith {};

    private _client = LD_var_clients get (owner _instigator);

    // only a client that is lagging or just reconnected can have made a lag switch kill
    if (isNil "_client" || {!(_client select 1)}) exitWith {};

    private _startTime = serverTime;

    waitUntil {
        sleep 0.25;

        if (isNull _instigator) exitWith {true};

        // reconnected after a lag: lag start and time to reconnect are known
        if ((_client select 3) != -1) exitWith {
            [_unit, _instigator, +_client] call LD_fnc_logKill;
            true
        };

        serverTime - _startTime > LD_var_suspectTime
    };
};

LD_fnc_startKillCheckServer = {
    if (LD_var_entityKilledEhId != -1) exitWith {};

    LD_var_entityKilledEhId = addMissionEventHandler ["EntityKilled", {_this spawn LD_fnc_entityKilled}];
};

call LD_fnc_startLagDetectionServer;
call LD_fnc_startKillCheckServer;

LD_var_serverInitDone = true;
publicVariable "LD_var_serverInitDone";
