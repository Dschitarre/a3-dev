// Loads this mod's scripts on the server (once per mission) and sends the client parts to every
// other machine, including JIP. Not shipped into missions (they load the fnc_*.sqf files directly).
if (!isServer || {!isNil "UF_var_modInitDone"}) exitWith {};
UF_var_modInitDone = true;

private _client = compile preprocessFileLineNumbers "unflip\scripts\fnc_client.sqf";
private _clientServer = compile preprocessFileLineNumbers "unflip\scripts\fnc_clientServer.sqf";
private _server = compile preprocessFileLineNumbers "unflip\scripts\fnc_server.sqf";

if (hasInterface) then {call _client;};
call _clientServer;
call _server;

// fnc_clientServer.sqf also goes to headless clients: vehicles of their AI are local there
[_client, {if (!isServer && {hasInterface}) then {call _this;};}] remoteExecCall ["call", -2, true];
[_clientServer, {if (!isServer) then {call _this;};}] remoteExecCall ["call", -2, true];
