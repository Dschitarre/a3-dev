if isServer then {
    _client = compile preprocessFileLineNumbers "killfeed\scripts\fnc_client.sqf";
    _clientServer = compile preprocessFileLineNumbers "killfeed\scripts\fnc_clientServer.sqf";
    _server = compile preprocessFileLineNumbers "killfeed\scripts\fnc_server.sqf";

    if hasInterface then {
        call _client;
    };

    call _clientServer;
    call _server;
    
    [_client, {if (!isServer && {hasInterface}) then {call _this;};}] remoteExecCall ["call", -2, true];
    [_clientServer, {if !isServer then {call _this;};}] remoteExecCall ["call", -2, true];
};