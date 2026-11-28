// Round end: per-round player statistics, the end screen (camera circling the play area with an overlay: winner,
// duration, MVPs, leaderboard) and the vote for the next map (server collects and decides, client shows the screen).

// seconds of the map vote, and how long its result is shown before the mission ends
SC_var_mapVoteDuration = 30;
SC_var_mapVoteResultTime = 5;

// seconds the end screen camera needs for one circle around the play area
SC_var_roundEndCameraLapTime = 120;

// ---- round statistics ----

// SC_var_roundStats: player UID / "ai:" + AI name -> [name, side, kills, deaths, captures, revives, xp]
SC_var_roundStatIndices = createHashMapFromArray [["kills", 2], ["deaths", 3], ["captures", 4], ["revives", 5], ["xp", 6]];

// AI gets no real XP; for the leaderboard it is counted as a player would get it at least:
// a kill and a capture without vehicle, distance or perk bonus
SC_var_aiRoundStatKillXp = 100;
SC_var_aiRoundStatCaptureXp = 200;

// server: adds _amount to a round statistic ("kills", "deaths", "captures", "revives", "xp") of a player or an AI unit
// (an AI by its name, which it keeps over its respawns, shown with "(AI)" like in the killfeed)
SC_fnc_addRoundStat = {
    params ["_unit", "_stat", ["_amount", 1]];

    if (isNull _unit || {!(_unit isKindOf "CAManBase")}) exitWith {};

    private _isPlayer = isPlayer _unit;
    private _key = if (_isPlayer) then {getPlayerUID _unit} else {"ai:" + (name _unit)};

    if (_key in ["", "ai:", "ai:Error: No unit"]) exitWith {};

    if !(_key in SC_var_roundStats) then {
        SC_var_roundStats set [_key, ["", sideUnknown, 0, 0, 0, 0, 0]];
    };

    private _row = SC_var_roundStats get _key;
    private _index = SC_var_roundStatIndices get _stat;
    _row set [0, [(name _unit) + " (AI)", name _unit] select _isPlayer];
    _row set [_index, (_row select _index) + _amount];

    // the group of a dead unit can already be gone
    if (alive _unit) then {
        _row set [1, side (group _unit)];
    };
};

// [title, name, side, value] of the best player per category, categories nobody scored in are left out
SC_fnc_getRoundMvps = {
    params ["_rows"];

    private _mvps = [];

    {
        _x params ["_title", "_index"];

        private _bestRow = [];
        private _bestValue = 0;

        {
            if ((_x select _index) > _bestValue) then {
                _bestRow = _x;
                _bestValue = _x select _index;
            };
        } forEach _rows;

        if (_bestRow isNotEqualTo []) then {
            _mvps pushBack [_title, (_bestRow select 0), (_bestRow select 1), _bestValue];
        };
    } forEach [["MVP", 6], ["Most kills", 2], ["Most captures", 4], ["Most revives", 5]];

    _mvps
};

// ---- round end ----

// every machine: ends the mission at once, without the signature closing shot (its "<SIDE> WON" title would appear
// behind the end screen); players of the winning side get the victory debriefing
SC_fnc_endMissionLocal = {
    params ["_end", "_winner"];

    [_end, (!hasInterface) || {(side group player) == _winner}, false] call BIS_fnc_endMission;
};

// server (game mode loop): end screen with the round statistics and the map vote on every client, then the mission end
SC_fnc_endRound = {
    params ["_winner"];

    // nobody is killed any more (the respawn screen would cover the end screen)
    {
        [_x, false] call ADG_fnc_allowDamage;
    } forEach (allPlayers select {!(_x isKindOf "HeadlessClient_F")});

    private _rows = [(values SC_var_roundStats), [], {_x select 6}, "DESCEND"] call BIS_fnc_sortBy;

    // vote options: [MapName param value, name], value 0 is "Random"
    private _options = [];

    {
        _options pushBack [_forEachIndex, _x];
    } forEach (getArray (missionConfigFile >> "params" >> "MapName" >> "texts"));

    SC_var_mapVotes = createHashMap;
    SC_var_mapVoteCounts = _options apply {0};
    publicVariable "SC_var_mapVoteCounts";
    SC_var_mapVoteOpen = true;

    // the killfeed's kill info (longest kills, most kills in a row) on the end screen instead of over it
    private _killInfo = if (isNil "KF_fnc_formatKillInfo") then {""} else {call KF_fnc_formatKillInfo};

    [
        _winner,
        (time - SC_var_roundStartTime),
        _rows,
        ([_rows] call SC_fnc_getRoundMvps),
        _options,
        SC_var_mapVoteDuration,
        _killInfo
    ] remoteExecCall ["SC_fnc_showRoundEnd", 0];

    sleep SC_var_mapVoteDuration;
    SC_var_mapVoteOpen = false;

    private _nextMap = call SC_fnc_getMapVoteResult;
    [_nextMap] call SC_fnc_setVotedMap;
    [((_options select _nextMap) select 1)] remoteExecCall ["SC_fnc_showMapVoteResult", 0];
    call SC_fnc_saveProgressNow;

    sleep SC_var_mapVoteResultTime;
    [("end_" + (str _winner)), _winner] remoteExecCall ["SC_fnc_endMissionLocal", 0];
};

// ---- map vote ----

// server: the vote of a player (option index, see SC_fnc_endRound); votes can be changed until the vote ends
SC_fnc_castMapVote = {
    params [["_uid", "", [""]], ["_option", -1, [0]]];

    if (
        !(missionNamespace getVariable ["SC_var_mapVoteOpen", false]) ||
        {(_option < 0) || {_option >= (count SC_var_mapVoteCounts)}} ||
        {!([_uid] call SC_fnc_isRequestFromUid)}
    ) exitWith {};

    SC_var_mapVotes set [_uid, (floor _option)];

    private _counts = SC_var_mapVoteCounts apply {0};

    {
        _counts set [_x, (_counts select _x) + 1];
    } forEach (values SC_var_mapVotes);

    SC_var_mapVoteCounts = _counts;
    publicVariable "SC_var_mapVoteCounts";
};

// server: option with the most votes (a tie is decided randomly), 0 ("Random") without votes
SC_fnc_getMapVoteResult = {
    private _maxVotes = selectMax SC_var_mapVoteCounts;

    if (_maxVotes == 0) exitWith {0};

    private _bestOptions = [];

    {
        if (_x == _maxVotes) then {
            _bestOptions pushBack _forEachIndex;
        };
    } forEach SC_var_mapVoteCounts;

    selectRandom _bestOptions
};

// ---- end screen (client) ----

// every player sees it, dead or alive, until the mission ends: the respawn screen, spectator, bleed out camera and
// view loops are stopped, nobody respawns any more, and the overlay dialog blocks the inputs (Escape included)
SC_fnc_showRoundEnd = {
    if !hasInterface exitWith {};

    _this spawn {
        params ["_winner", "_duration", "_rows", "_mvps", "_options", "_voteDuration", ["_killInfo", ""]];

        disableSerialization;

        SC_var_roundEnded = true;
        SC_var_mapVoteOptions = _options;
        SC_var_mapVoteEndTime = time + _voteDuration;
        SC_var_nextMapName = "";

        if (isNil "SC_var_mapVoteCounts") then {
            SC_var_mapVoteCounts = [];
        };

        setPlayerRespawnTime 1e6;

        {
            terminate (missionNamespace getVariable [_x, scriptNull]);
        } forEach ["SC_var_cameraViewLoop", "SC_var_forceFPPLoopScript", "AIS_BleedoutCameraScript"];

        {
            (uiNamespace getVariable [_x, displayNull]) closeDisplay 1;
        } forEach ["SC_var_respawnMapDisplay", "SC_var_spectatorDisplay"];

        for "_i" from 1 to 5 do {
            if dialog then {
                closeDialog 2;
            };
        };

        openMap false;

        // the spectator ends with a camera switch of its own
        sleep 0.2;

        call SC_fnc_startRoundEndCamera;

        // a client that is still loading has no HUD yet
        if !(isNil "SC_var_settings") then {
            [false] call SC_fnc_setHud;
        };

        showHUD false;
        cutText ["", "PLAIN", 0];
        1 fadeSound 1;

        [_winner, _duration, _rows, _mvps, _options, _killInfo] call SC_fnc_openRoundEndDialog;
    };
};

// client: camera slowly circling the centre of the play area, radius and height scaled to its size
SC_fnc_startRoundEndCamera = {
    private _center = getMarkerPos "SC_var_playZone";
    _center set [2, 0];

    private _radius = 150 max ((0.6 * SC_var_maxZoneSize) min 2000);
    private _camera = "camera" camCreate (_center vectorAdd [0, _radius, 0.4 * _radius]);

    _camera cameraEffect ["internal", "back"];
    camUseNVG (call SC_fnc_isNight);
    showCinemaBorder false;

    SC_var_roundEndCamera = [_camera, _center, _radius, (0.4 * _radius), diag_tickTime];
    addMissionEventHandler ["EachFrame", {call SC_fnc_updateRoundEndCamera}];
};

// client (each frame): next camera position on the circle, at the same height above sea level all around but at least
// 30 m above the ground below it, looking at the centre
SC_fnc_updateRoundEndCamera = {
    SC_var_roundEndCamera params ["_camera", "_center", "_radius", "_height", "_startTime"];

    private _angle = 360 * (diag_tickTime - _startTime) / SC_var_roundEndCameraLapTime;
    private _pos = _center vectorAdd [(_radius * (sin _angle)), (_radius * (cos _angle)), 0];
    _pos set [2, (30 max (((getTerrainHeightASL _center) + _height) - (getTerrainHeightASL _pos)))];

    _camera camSetPos _pos;
    _camera camSetTarget _center;
    _camera camCommit 0;
};

// client: overlay with the round result, MVPs, leaderboard and the map vote
SC_fnc_openRoundEndDialog = {
    params ["_winner", "_duration", "_rows", "_mvps", "_options", ["_killInfo", ""]];

    disableSerialization;

    createDialog "roundEndDialog";
    private _display = uiNamespace getVariable ["SC_var_roundEndDialog", displayNull];

    if (isNull _display) exitWith {};

    (_display displayCtrl 1101) ctrlSetStructuredText parseText format [
        "<t align='center' font='RobotoCondensedBold' size='1.2'><t color='%1'>%2</t> won</t><br/><t align='center'>Round duration: %3</t>",
        ([_winner] call UI_fnc_sideColorHtml),
        ([_winner] call SC_fnc_getSideString),
        ([_duration] call SC_fnc_secondsToMinSec)
    ];

    (_display displayCtrl 1102) ctrlSetStructuredText parseText ((_mvps apply {
        _x params ["_title", "_name", "_side", "_value"];

        format ["%1: <t color='%2'>%3</t> (%4%5)", _title, ([_side] call UI_fnc_sideColorHtml), _name, (round _value), (["", " XP"] select (_title == "MVP"))]
    }) joinString "     ");

    // the colors of the killfeed's text are filled in by its client part
    if ((_killInfo != "") && {!(isNil "KF_fnc_colorize")}) then {
        (_display displayCtrl 1103) ctrlSetStructuredText parseText ([format ["<t align='center'>%1</t>", _killInfo]] call KF_fnc_colorize);
    };

    private _statsList = _display displayCtrl 1500;
    _statsList lnbAddRow ["Name", "Kills", "Deaths", "Captures", "Revives", "XP"];

    for "_column" from 0 to 5 do {
        _statsList lnbSetColor [[0, _column], [1, 1, 1, 0.5]];
    };

    {
        _x params ["_name", "_side", "_kills", "_deaths", "_captures", "_revives", "_xp"];

        private _row = _statsList lnbAddRow [_name, str _kills, str _deaths, str _captures, str _revives, str (round _xp)];
        _statsList lnbSetColor [[_row, 0], ([_side] call UI_fnc_sideColor)];
    } forEach _rows;

    if (_rows isEqualTo []) then {
        _statsList lnbAddRow ["No statistics", "", "", "", "", ""];
    };

    private _voteList = _display displayCtrl 1501;

    {
        _voteList lbSetValue [(_voteList lbAdd (_x select 1)), _forEachIndex];
    } forEach _options;

    [] spawn SC_fnc_roundEndDialogLoop;
};

// client: vote counts and countdown / result of the open end screen
SC_fnc_roundEndDialogLoop = {
    disableSerialization;

    waitUntil {
        private _display = uiNamespace getVariable ["SC_var_roundEndDialog", displayNull];

        if !(isNull _display) then {
            private _voteList = _display displayCtrl 1501;

            {
                _voteList lbSetText [_forEachIndex, format ["%1 (%2)", (_x select 1), (SC_var_mapVoteCounts param [_forEachIndex, 0])]];
            } forEach SC_var_mapVoteOptions;

            (_display displayCtrl 1104) ctrlSetText (if (SC_var_nextMapName == "") then {
                format ["Vote ends in %1 s", (0 max (ceil (SC_var_mapVoteEndTime - time)))]
            } else {
                "Next map: " + SC_var_nextMapName
            });
        };

        sleep 0.5;

        (isNull _display)
    };
};

// client: list selection of the map vote
SC_fnc_onMapVoteSelected = {
    params ["_voteList", "_index"];

    if (_index < 0) exitWith {};

    [(getPlayerUID player), (_voteList lbValue _index)] remoteExecCall ["SC_fnc_castMapVote", 2];
};

SC_fnc_showMapVoteResult = {
    params ["_mapName"];

    SC_var_nextMapName = _mapName;
};
