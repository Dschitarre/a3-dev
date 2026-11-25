// Loads this mod's scripts on the server (once per mission) and sends the client parts to every
// other machine, including JIP. Not shipped into missions (they load the fnc_*.sqf files directly).
if (!isServer || {!isNil "H_var_modInitDone"}) exitWith {};
H_var_modInitDone = true;

private _client = compile preprocessFileLineNumbers "holster\scripts\fnc_client.sqf";
private _server = compile preprocessFileLineNumbers "holster\scripts\fnc_server.sqf";

if (hasInterface) then {call _client;};
call _server;

[_client, {if (!isServer && {hasInterface}) then {call _this;};}] remoteExecCall ["call", -2, true];
