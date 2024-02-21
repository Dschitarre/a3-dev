if isServer then {
    _clientServer = compile preprocessFileLineNumbers "autoheal\scripts\fnc_clientServer.sqf";
    _server = compile preprocessFileLineNumbers "autoheal\scripts\fnc_server.sqf";

    call _clientServer;
    call _server;

    [_clientServer, {if !isServer then {call _this;};}] remoteExecCall ["call", -2, true];
};