if isServer then {
    _client = compile preprocessFileLineNumbers "dynamicweather\scripts\fnc_client.sqf";
    _server = compile preprocessFileLineNumbers "dynamicweather\scripts\fnc_server.sqf";

    if hasInterface then {
        call _client;
    };

    call _server;

    [_client, {if (!isServer && {hasInterface}) then {call _this;};}] remoteExecCall ["call", -2, true];
};