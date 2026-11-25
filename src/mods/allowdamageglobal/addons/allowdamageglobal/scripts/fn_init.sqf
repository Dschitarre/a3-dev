// Loads this mod's scripts on the server (once per mission) and sends the client parts to every
// other machine, including JIP. Not shipped into missions (they load the fnc_*.sqf files directly).
if (!isServer || {!isNil "ADG_var_modInitDone"}) exitWith {};
ADG_var_modInitDone = true;

private _clientServer = compile preprocessFileLineNumbers "allowdamageglobal\scripts\fnc_clientServer.sqf";
private _server = compile preprocessFileLineNumbers "allowdamageglobal\scripts\fnc_server.sqf";

call _clientServer;
call _server;

[_clientServer, {if (!isServer) then {call _this;};}] remoteExecCall ["call", -2, true];
