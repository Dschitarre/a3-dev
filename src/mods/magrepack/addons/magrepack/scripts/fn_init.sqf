// Loads this mod's scripts on the server (once per mission) and sends the client parts to every
// other machine, including JIP. Not shipped into missions (they load the fnc_*.sqf files directly).
if (!isServer || {!isNil "MR_var_modInitDone"}) exitWith {};
MR_var_modInitDone = true;

private _client = compile preprocessFileLineNumbers "magrepack\scripts\fnc_client.sqf";
private _clientServer = compile preprocessFileLineNumbers "magrepack\scripts\fnc_clientServer.sqf";
private _server = compile preprocessFileLineNumbers "magrepack\scripts\fnc_server.sqf";

// the part for every machine first (as in missions that integrate the mod): the client part uses it
call _clientServer;

if (hasInterface) then {call _client;};
call _server;

[_clientServer, {if (!isServer) then {call _this;};}] remoteExecCall ["call", -2, true];
[_client, {if (!isServer && {hasInterface}) then {call _this;};}] remoteExecCall ["call", -2, true];
