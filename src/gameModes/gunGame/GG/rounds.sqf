// GunGame rounds (server, clients react): end of a round with the podium and the kill info, the map vote and the next
// round on the new map without a mission restart (endless rotation).

GG_var_podiumDuration = 15;         // seconds of podium and kill info
GG_var_mapVoteDuration = 15;
GG_var_mapVoteOptions = 3;
GG_var_podiumLayer = 1013;          // cut layer of the podium (ui\ui.sqf screen text)

// ---- server ----

/*
    Scheduled: _winnerName (a unit's or a team's name) reached the end of the ladder. Kills no longer count
    (GG_var_ended), the AI is parked and the players are frozen behind the podium; then the next map is voted (Map param
    Random) and a new round starts on it with everyone back at the first weapon.
*/
GG_fnc_endRound = {
    params ["_winnerName"];

    GG_var_ended = true;
    publicVariable "GG_var_ended";
    call GG_fnc_refreshLeaderBoardServer;

    private _podium = call GG_fnc_podiumData;

    {
        [_x] call GG_fnc_suspendUnit;
    } forEach ((entities [["CAManBase"], [], true, true]) select {!isPlayer _x && {local _x} && {simulationEnabled _x}});

    [_winnerName, _podium] remoteExecCall ["GG_fnc_endRoundClient", [0, -2] select isDedicated];

    if (!isNil "KF_fnc_displayKillInfo") then {
        call KF_fnc_displayKillInfo;
    };

    sleep GG_var_podiumDuration;

    private _mapIndex = call GG_fnc_nextMapIndex;

    call GG_fnc_resetRound;
    [_mapIndex] call GG_fnc_applyMap;

    GG_var_ended = false;
    publicVariable "GG_var_ended";
    call GG_fnc_refreshLeaderBoardServer;

    [] remoteExecCall ["GG_fnc_startRoundClient", [0, -2] select isDedicated];
};

// the best three of the round: [name, team (sideUnknown in free for all), stage, kills, deaths, best streak]
GG_fnc_podiumData = {
    ((call GG_fnc_rankedUnits) select [0, 3]) apply {
        [
            name _x,
            [_x] call GG_fnc_teamOf,
            _x getVariable ["GG_var_weaponNum", 0],
            _x getVariable ["GG_var_kills", 0],
            _x getVariable ["GG_var_deaths", 0],
            _x getVariable ["GG_var_bestStreak", 0]
        ]
    }
};

/*
    Map param Random: the players vote between GG_var_mapVoteOptions other maps of the wanted size (mapSize param; any
    other map if there is none), a fixed map is played again.
*/
GG_fnc_nextMapIndex = {
    if (("Map" call BIS_fnc_getParamValue) != 0) exitWith {GG_var_mapIndex};

    private _candidates = (call GG_fnc_mapsOfWantedSize) - [GG_var_mapIndex];

    if (_candidates isEqualTo []) then {
        for "_i" from 0 to (count (getArray (missionConfigFile >> "mapData")) - 1) do {
            if (_i != GG_var_mapIndex) then {
                _candidates pushBack _i;
            };
        };
    };

    if (_candidates isEqualTo []) exitWith {GG_var_mapIndex};

    _candidates = _candidates call BIS_fnc_arrayShuffle;
    _candidates resize (GG_var_mapVoteOptions min count _candidates);

    // Map param texts: value v > 0 is row v - 1 of mapData[]
    private _mapNames = getArray (missionConfigFile >> "Params" >> "Map" >> "texts");
    private _options = _candidates apply {_mapNames select (_x + 1)};

    _candidates select (["Next map", _options, GG_var_mapVoteDuration, true, true] call CMN_fnc_runVote)
};

// everyone (pool units too) back to the first weapon with empty stats, team ladders and the kill info reset
GG_fnc_resetRound = {
    {
        [_x] call GG_fnc_resetLadderStats;
        _x setVariable ["GG_var_lastSpawnPos", [0, 0, 0]];
    } forEach ((entities [["CAManBase"], [], true, true]) select {_x getVariable ["GG_var_unitId", -1] != -1});

    {
        private _scores = getPlayerScores _x;

        if (_scores isNotEqualTo []) then {
            _x addPlayerScores ((_scores select [0, 5]) apply {-_x});
        };
    } forEach playableUnits;

    GG_var_playerStats = createHashMap;
    call GG_fnc_resetTeams;

    if (!isNil "KF_fnc_resetKillInfo") then {
        call KF_fnc_resetKillInfo;
    };
};

// ---- client ----

// the round is over: the player stops fighting and sees the podium on a dark screen
GG_fnc_endRoundClient = {
    params ["_winnerName", "_podium"];

    if (!hasInterface || {isNil "GG_var_playerSetUp"}) exitWith {};

    // at once, whenever the public variable arrives: closes an open respawn screen
    GG_var_ended = true;

    {
        if (!isNull _x) then {
            terminate _x;
        };
    } forEach [GG_var_spawnPlayerScript, GG_var_playZoneLoopScript];

    call CMN_fnc_stopCameraViewLoop;
    call CMN_fnc_hideCenterText;
    [player, false] call CMN_fnc_setSimulationGlobal;
    cutText ["", "BLACK OUT", 1, true];
    [_winnerName, _podium] call GG_fnc_showPodium;
};

GG_fnc_showPodium = {
    params ["_winnerName", "_podium"];

    private _accent = ["accent"] call UI_fnc_colorHtml;
    private _lines = [];

    {
        _x params ["_name", "_team", "_weaponNum", "_kills", "_deaths", "_bestStreak"];

        private _nameColor = [_accent, [_team] call UI_fnc_sideColorHtml] select (_team != sideUnknown);
        private _kd = if (_deaths == 0) then {_kills} else {[_kills / _deaths, 1] call BIS_fnc_cutDecimals};

        _lines pushBack format [
            "%1. <t color='%2'>%3</t>   %4/%5   %6 kills, %7 deaths, K/D %8, best streak %9",
            _forEachIndex + 1,
            _nameColor,
            [_name] call CMN_fnc_escapeText,
            _weaponNum,
            count GG_var_weaponList - 1,
            _kills,
            _deaths,
            _kd,
            _bestStreak
        ];
    } forEach _podium;

    private _text = format [
        "<t align='center' font='%1' size='1.4' color='%2'>%3 won the round</t><br/><br/><t align='center'>%4</t>",
        CMN_var_fontBold,
        _accent,
        [_winnerName] call CMN_fnc_escapeText,
        _lines joinString "<br/>"
    ];

    // a screen text (ui\ui.sqf) in the middle of the screen, without a block
    [
        GG_var_podiumLayer,
        _text,
        [safeZoneX + safeZoneW / 2, safeZoneY + 0.3 * safeZoneH, 0.5, 0],
        GG_var_podiumDuration,
        -1,
        false
    ] call UI_fnc_showTextBlocks;
};

// the next round runs: the player spawns into the (new) zone with the first weapon
GG_fnc_startRoundClient = {
    if (!hasInterface || {isNil "GG_var_playerSetUp"}) exitWith {};

    GG_var_ended = false;
    [GG_var_podiumLayer] call UI_fnc_hideTextBlocks;
    GG_var_lastSpawnPos = [0, 0, 0];
    call GG_fnc_refreshNextWeapon;
    call GG_fnc_openRespawnScreen;
};
