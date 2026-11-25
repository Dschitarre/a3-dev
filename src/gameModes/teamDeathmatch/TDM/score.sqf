// Team Deathmatch teams and score (server and client): team counts, points, win condition, match point and the match
// end with the final score and the best players.

DM_var_matchEndDuration = 18;       // seconds of final score, best players and kill info before the mission ends
DM_var_topPlayerCount = 5;
DM_var_matchResultLayer = 1013;     // cut layer of the match result (ui\ui.sqf screen text)

// simulated units of a side (suspended AI excluded); UAV AI never counts as a team member
DM_fnc_unitsOfSide = {
    params ["_side", ["_aliveOnly", true]];

    (entities [["CAManBase"], [], true, _aliveOnly]) select {
        simulationEnabled _x && {side (group _x) == _side} && {!([_x] call KF_fnc_isUavAi)}
    }
};

DM_fnc_oneTeamDead = {
    ({([_x] call DM_fnc_unitsOfSide) isEqualTo []} count [west, east]) != 0
};

// the side with more survivors (one team dead or time limit reached); sideUnknown on a draw, e.g. both teams dead
DM_fnc_getWinSide = {
    ([west, east] apply {count ([_x] call DM_fnc_unitsOfSide)}) params ["_westCount", "_eastCount"];

    if (_westCount == _eastCount) exitWith {sideUnknown};

    [east, west] select (_westCount > _eastCount)
};

DM_fnc_increaseSidesScore = {
    params ["_winSide"];

    private _varName = "DM_var_" + toLowerANSI str _winSide + "Points";

    missionNamespace setVariable [_varName, (missionNamespace getVariable _varName) + 1];
    publicVariable _varName;
};

// sides that win the match by winning the coming round (same rule as DM_fnc_finishRound)
DM_fnc_matchPointSides = {
    [west, east] select {
        private _points = missionNamespace getVariable ("DM_var_" + toLowerANSI str _x + "Points");
        private _otherPoints = DM_var_westPoints + DM_var_eastPoints - _points;

        _points + 1 >= DM_var_minPointsToWin && {!DM_var_requireLeadOfTwoPoints || {_points + 1 - _otherPoints >= 2}}
    }
};

// ---- match end ----

/*
    Server, scheduled: everyone frozen, the final score with the best players (MVP first) and the killfeed's kill info
    for DM_var_matchEndDuration seconds; the caller then ends the mission.
*/
DM_fnc_runMatchEnd = {
    params ["_winSide"];

    [false] call DM_fnc_movement;
    [_winSide, DM_var_westPoints, DM_var_eastPoints, call DM_fnc_topPlayers] remoteExecCall ["DM_fnc_showMatchResult", [0, -2] select isDedicated];

    if (!isNil "KF_fnc_displayKillInfo") then {
        KF_var_killInfoDuration = DM_var_matchEndDuration;
        call KF_fnc_displayKillInfo;
    };

    sleep DM_var_matchEndDuration;
};

// the best players and AI of the match by kills, fewer deaths first on a tie: [[name, side, kills, deaths], ...]
DM_fnc_topPlayers = {
    private _units =(playableUnits +(allPlayers select {!(_x isKindOf "HeadlessClient_F")})) arrayIntersect (
        playableUnits +(allPlayers select {!(_x isKindOf "HeadlessClient_F")}));
    private _sortKeys = [];

    {
        private _scores = getPlayerScores _x;

        if (_scores isNotEqualTo []) then {
            _scores params ["_infantryKills", "_softKills", "_armorKills", "_airKills", "_deaths"];

            private _kills = _infantryKills + _softKills + _armorKills + _airKills;

            if (_kills + _deaths > 0) then {
                _sortKeys pushBack [-_kills, _deaths, _forEachIndex];
            };
        };
    } forEach _units;

    _sortKeys sort true;

    (_sortKeys select [0, DM_var_topPlayerCount]) apply {
        private _unit = _units select (_x select 2);
        [name _unit, side group _unit, -(_x select 0), _x select 1]
    }
};

// client: final score and best players in the middle of the screen (names escaped, colors of the player's settings)
DM_fnc_showMatchResult = {
    params ["_winSide", "_westPoints", "_eastPoints", "_topPlayers"];

    if (!hasInterface) exitWith {};

    private _lines = [];

    {
        _x params ["_name", "_side", "_kills", "_deaths"];

        _lines pushBack format [
            "%1<t color='%2'>%3</t>   %4 kills, %5 deaths",
            ["", "MVP: "] select (_forEachIndex == 0),
            [_side] call UI_fnc_sideColorHtml,
            [_name] call CMN_fnc_escapeText,
            _kills,
            _deaths
        ];
    } forEach _topPlayers;

    private _text = format [
        "<t align='center' font='%1' size='1.4' color='%2'>%3 won the match</t><br/><t align='center' font='%1' size='1.2'><t color='%4'>%5</t> : <t color='%6'>%7</t></t><br/><br/><t align='center'>%8</t>",
        CMN_var_fontBold,
        [_winSide] call UI_fnc_sideColorHtml,
        [_winSide] call DM_fnc_getSideString,
        [west] call UI_fnc_sideColorHtml,
        _westPoints,
        [east] call UI_fnc_sideColorHtml,
        _eastPoints,
        _lines joinString "<br/>"
    ];

    // a screen text (ui\ui.sqf) in the middle of the screen, without a block
    [
        DM_var_matchResultLayer,
        _text,
        [safeZoneX + safeZoneW / 2, safeZoneY + 0.3 * safeZoneH, 0.5, 0],
        DM_var_matchEndDuration,
        -1,
        false
    ] call UI_fnc_showTextBlocks;
};

DM_fnc_resetPlayerScores = {
    {
        private _scores = getPlayerScores _x;

        if (_scores isNotEqualTo []) then {
            _x addPlayerScores ((_scores select [0, 5]) apply {-_x});
        };
    } forEach playableUnits;
};

DM_fnc_getSideString = {
    params ["_side"];

    switch (_side) do {
        case west: {"Blufor"};
        case east: {"Opfor"};
        case independent: {"Independent"};
    };
};

// each side has a simulated unit (alive or dead)
DM_fnc_bothSidesHaveUnits = {
    ([west, east] findIf {([_x, false] call DM_fnc_unitsOfSide) isEqualTo []}) == -1
};

// true when every player is ready (DM_fnc_playerReady)
DM_fnc_allPlayersReady = {
    params ["_includeArsenal"];

    ((allPlayers select {!(_x isKindOf "HeadlessClient_F")}) findIf {!([_x, _includeArsenal] call DM_fnc_playerReady)}) == -1
};

// alive, simulated and done loading (with _includeArsenal: also out of the arsenal); a state not synced yet counts as ready
DM_fnc_playerReady = {
    params ["_player", "_includeArsenal"];

    if (!simulationEnabled _player || {!alive _player}) exitWith {false};

    private _busyStates = [_player getVariable "CMN_var_isLoading"];

    if (_includeArsenal) then {
        _busyStates pushBack (_player getVariable "DM_var_arsenalOpened");
    };

    if ((_busyStates findIf {isNil "_x"}) != -1) exitWith {true};

    (_busyStates findIf {_x}) == -1
};
