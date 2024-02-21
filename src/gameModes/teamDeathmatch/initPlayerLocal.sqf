player enableSimulationGlobal false;
0 fadesound 0;

if (!isServer && !didJIP) then {
    1012 cutText ["", "BLACK FADED", 999999, true];
    ["pease_reenter", true, 0, false, false] call BIS_fnc_endMission;
};

player setpos [0, 0, 100];
setplayerrespawntime 9999;

waitUntil {!(isNull (findDisplay 46))};
cutText ["", "BLACK FADED", 999999, true];
["Loading, please wait...", [safeZoneX, safeZoneW], [((safeZoneH / 2) + safezoneY), safeZoneH], 9999, 0, 0, 1011] spawn BIS_fnc_dynamicText;

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

[player, false] call ADG_fnc_allowDamage;
{deleteVehicle _x;} forEach ((entities [["CAManBase"], [], true, false]) select {name _x == ""});

onPreloadStarted {player setVariable ["DM_var_isLoading", true, true];};
onPreloadFinished {player setVariable ["DM_var_isLoading", false, true];};

_functions = compile preprocessFileLineNumbers "TDM\clientFunctions.sqf";
_loops = compile preprocessFileLineNumbers "TDM\clientLoops.sqf";
_prepare = compile preprocessFileLineNumbers "TDM\clientPrepare.sqf";

call _functions;
call _loops;

waitUntil {!(isNull player) && !(isNil "DM_var_serverInitDone")};

[player] remoteExec ["DM_fnc_initPlayerServer", 2];

waitUntil {
    !(isNull (findDisplay 46)) &&
    (
        (
            {isNil "_x"} count (
                (
                    [
                        "DM_var_maxZoneSize",
                        "DM_var_mapScaleFactor",
                        "DM_var_gameRunning",
                        "DM_var_respawnTime",
                        "DM_var_movingEnabled",
                        "DM_var_timerStr",
                        "DM_var_loadoutsRestricted",
                        "DM_var_eastPoints",
                        "DM_var_westPoints"
                    ] apply {missionNameSpace getVariable _x}
                ) +
                (
                    [
                        "DM_var_isLoading",
                        "DM_var_arsenalOpened"
                    ] apply {player getVariable _x}
                )
            )
        ) == 0
    )
};

call _prepare;