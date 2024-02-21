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
    "disablestamina",
    "disabletacticalview",
    "holster",
    "jump",
    "killfeed",
    "lagswitchdetection",
    "autoheal"
];

call (compile preprocessFileLineNumbers "GG\serverFunctions.sqf");
call (compile preprocessFileLineNumbers "GG\serverLoops.sqf");
call (compile preprocessFileLineNumbers "GG\serverPrepare.sqf");