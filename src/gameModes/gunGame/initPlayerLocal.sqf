player enableSimulationGlobal false;
0 fadesound 0;

if (!isServer && !didJIP) then {
    1012 cutText ["", "BLACK FADED", 999999, true];
    ["pease_reenter", true, 0, false, false] call BIS_fnc_endMission;
};

["Loading, please wait...", [safeZoneX, safeZoneW], [((safeZoneH / 2) + safezoneY), safeZoneH], 9999, 0, 0, 1011] spawn BIS_fnc_dynamicText;

waitUntil {!(isNull (findDisplay 46))};

cutText ["", "BLACK FADED", 9999, true];

{deleteVehicle _x;} forEach ((entities [["CAManBase"], [], true, false]) select {name _x == ""});

{
    _clientFilePath = "modsIntegrated\" + _x + "\scripts\fnc_client.sqf";
    _clientServerFilePath = "modsIntegrated\" + _x + "\scripts\fnc_clientServer.sqf";
    _serverFilePath = "modsIntegrated\" + _x + "\scripts\fnc_server.sqf";

    if (fileExists _clientServerFilePath) then {
        call (compile (preprocessFileLineNumbers _clientServerFilePath));
    };

    if (fileExists _clientFilePath) then {
        call (compile (preprocessFileLineNumbers _clientFilePath));
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

call (compile (preprocessFileLineNumbers "GG\clientFunctions.sqf"));
call (compile (preprocessFileLineNumbers "GG\clientLoops.sqf"));

onPreloadStarted {player setVariable ["GG_var_isLoading", true, true];};
onPreloadFinished {player setVariable ["GG_var_isLoading", false, true];};

waitUntil {!(isNull player) && !(isNil "GG_var_serverInitDone")};

[player] remoteExecCall ["GG_fnc_initPlayer", 2];

waitUntil {
    !(isNil {player getVariable "GG_var_isLoading"}) &&
    {!(player getVariable "GG_var_isLoading")} && 
    {({isNil "_x"} count (
        (["GG_var_weaponList", "GG_var_leaderBoard", "GG_var_maxZoneSize", "GG_var_mapScaleFactor"] apply {missionNameSpace getVariable _x}) +
        (["GG_var_weaponNum", "GG_var_deaths", "rankOnServer"] apply {player getVariable _x})
    )) == 0}
};

call (compile (preprocessFileLineNumbers "GG\clientPrepare.sqf"));