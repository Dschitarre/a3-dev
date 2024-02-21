{
    _clientFilePath = "modsIntegrated\" + _x + "\scripts\fnc_client.sqf";
    _clientServerFilePath = "modsIntegrated\" + _x + "\scripts\fnc_clientServer.sqf";
    _serverFilePath = "modsIntegrated\" + _x + "\scripts\fnc_server.sqf";

    if (isServer && {fileExists _serverFilePath}) then {
        call (compile (preprocessFileLineNumbers _serverFilePath));
    };

  if (fileExists _clientServerFilePath) then {
        call (compile (preprocessFileLineNumbers _clientServerFilePath));
    };

    if (hasInterface && {fileExists _clientFilePath}) then {
        call (compile (preprocessFileLineNumbers _clientFilePath));
    };
} forEach [
    "disabletacticalview",
    "earplugs"
];

call E_fnc_startEarplugsServer;

setViewDistance 1000;
setObjectViewDistance 835;
enableSentences false;

player allowdammage false;

player enableFatigue false;
player enableStamina false;
player setCustomAimCoef 0.35;

killScore = 0;

0 setOvercast 0;
0 setFog 0.04;
0 setRain 0;
setDate [2035,6,3,18,25];
forceWeatherChange;

sleep 0.1;

["Open",true] call BIS_fnc_arsenal;

sleep 1;

player addEventHandler ["HandleRating",{
  playSound ["kill", false];
  killScore = killScore + 1;
  (uiNamespace getVariable "ScoreDisplay" displayCtrl 1100) ctrlSetText "Score: " + Format ["%1", killScore];
}];

waitUntil {isnull(uinamespace getvariable "RSCDisplayArsenal")};

maxAmmo = player ammo primaryWeapon player;

player addEventHandler ["Fired",{
  player setAmmo [currentWeapon player,maxAmmo];
}];

currentPos = getpos player;

(["ScoreDisplay"] call BIS_fnc_rscLayer) cutRsc ["ScoreDisplay", "PLAIN", 0, true];

execVM "scripts\spawnGroups.sqf";

while {true} do {
  player setpos currentPos;
  sleep (1/60);
};