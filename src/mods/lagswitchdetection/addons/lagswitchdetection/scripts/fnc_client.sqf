// Lag switch detection (client): sends a heartbeat with this client's serverTime to the server every
// LD_var_heartbeatInterval seconds, from an unscheduled per-frame handler (a busy scheduler cannot delay it).

if (isNil "LD_var_heartbeatInterval") then {LD_var_heartbeatInterval = 1;};   // a mission may set it before

if (hasInterface && {isNil "LD_var_heartbeatEhId"}) then {
    LD_var_nextHeartbeat = 0;

    LD_var_heartbeatEhId = addMissionEventHandler ["EachFrame", {
        if (diag_tickTime < LD_var_nextHeartbeat) exitWith {};

        LD_var_nextHeartbeat = diag_tickTime + LD_var_heartbeatInterval;
        [serverTime] remoteExecCall ["LD_fnc_heartbeat", 2];
    }];
};

LD_var_clientInitDone = true;
