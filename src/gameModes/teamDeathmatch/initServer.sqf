{
    _clientFilePath = "modsIntegrated\" + _x + "\scripts\fnc_client.sqf";
    _clientServerFilePath = "modsIntegrated\" + _x + "\scripts\fnc_clientServer.sqf";
    _serverFilePath = "modsIntegrated\" + _x + "\scripts\fnc_server.sqf";

    if (fileExists _serverFilePath) then {
        call (compile (preprocessFileLineNumbers _serverFilePath));
    };

    if (fileExists _clientServerFilePath) then {
        call (compile (preprocessFileLineNumbers _clientServerFilePath));
    };
} forEach [
    "allowdamageglobal",
    "killfeed",
    "dynamicweather",
    "tdicons",
    "disablestamina",
    "disabletacticalview",
    "holster",
    "jump",
    "killfeed",
    "lagswitchdetection",
    "mapmarker",
    "autoheal"
];

_functions = compile preprocessFileLineNumbers "TDM\serverFunctions.sqf";
_loops = compile preprocessFileLineNumbers "TDM\serverLoops.sqf";
_prepare = compile preprocessFileLineNumbers "TDM\serverPrepare.sqf";

call _functions;
call _loops;
call _prepare;