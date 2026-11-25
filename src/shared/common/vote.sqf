// Shared TDM/GunGame vote (CMN_, server and client): the server runs a vote between a few options (e.g. maps), players
// vote in the dialog CMN_voteDialog (common\vote.hpp). Needs the ui lib (ui\ui.sqf) for the accent color.

CMN_var_voteDialogInterval = 0.25;  // dialog refresh: vote counts and remaining time

// CMN_var_vote (public): [vote id, title, option names, end serverTime] while a vote runs, [] otherwise
if (isNil "CMN_var_vote") then {
    CMN_var_vote = [];
};

// [vote id, option index] of the player's own last vote
CMN_var_ownVote = [-1, -1];

// ---- server ----

/*
    Scheduled. Runs a vote for _duration seconds and returns the index of the winning option (most votes; a tie or no
    votes at all is decided at random). _openDialog: the dialog opens on every client. _endWhenAllVoted: ends as soon
    as every player voted. CMN_fnc_setVoteEnd can end it earlier. Publishes CMN_var_vote and CMN_var_voteCounts.
*/
CMN_fnc_runVote = {
    params ["_title", "_options", "_duration", ["_openDialog", false], ["_endWhenAllVoted", false]];

    CMN_var_voteId = (missionNamespace getVariable ["CMN_var_voteId", 0]) + 1;
    CMN_var_voteChoices = createHashMap;    // player UID -> option index
    CMN_var_voteCounts = _options apply {0};
    CMN_var_voteEndTime = time + _duration;
    CMN_var_vote = [CMN_var_voteId, _title, _options, serverTime + _duration];
    publicVariable "CMN_var_voteCounts";
    publicVariable "CMN_var_vote";

    if (_openDialog) then {
        [] remoteExecCall ["CMN_fnc_openVoteDialog", [0, -2] select isDedicated];
    };

    waitUntil {
        sleep 0.5;
        time >= CMN_var_voteEndTime ||
        {_endWhenAllVoted && {count CMN_var_voteChoices >= count (allPlayers - (allMissionObjects "HeadlessClient_F"))}}
    };

    CMN_var_vote = [];
    publicVariable "CMN_var_vote";

    private _maxVotes = selectMax CMN_var_voteCounts;
    private _winners = [];

    {
        if (_x == _maxVotes) then {
            _winners pushBack _forEachIndex;
        };
    } forEach CMN_var_voteCounts;

    selectRandom _winners
};

// ends the running vote in _seconds; only ever moves the end forward
CMN_fnc_setVoteEnd = {
    params ["_seconds"];

    if (CMN_var_vote isEqualTo [] || {time + _seconds >= CMN_var_voteEndTime}) exitWith {};

    CMN_var_voteEndTime = time + _seconds;
    CMN_var_vote set [3, serverTime + _seconds];
    publicVariable "CMN_var_vote";
};

// remoteExecCall by a client: one vote per player, a new vote replaces the old one
CMN_fnc_castVote = {
    params ["_player", "_voteId", "_index"];

    if (
        isNull _player ||
        {CMN_var_vote isEqualTo []} ||
        {_voteId != (CMN_var_vote select 0)} ||
        {_index < 0} ||
        {_index >= count CMN_var_voteCounts}
    ) exitWith {};

    CMN_var_voteChoices set [getPlayerUID _player, _index];
    CMN_var_voteCounts = CMN_var_voteCounts apply {0};

    {
        CMN_var_voteCounts set [_y, (CMN_var_voteCounts select _y) + 1];
    } forEach CMN_var_voteChoices;

    publicVariable "CMN_var_voteCounts";
};

// ---- client ----

// opens the vote dialog while a vote runs; it refreshes itself and closes when the vote ends
CMN_fnc_openVoteDialog = {
    if (!hasInterface || {CMN_var_vote isEqualTo []} || {!isNull (uiNamespace getVariable ["CMN_voteDialog", displayNull])}) exitWith {};

    createDialog "CMN_voteDialog";
    [] spawn CMN_fnc_voteDialogLoop;
};

CMN_fnc_voteDialogLoop = {
    disableSerialization;
    private _display = uiNamespace getVariable ["CMN_voteDialog", displayNull];
    if (isNull _display) exitWith {};

    private _titleCtrl = _display displayCtrl 7401;
    private _listCtrl = _display displayCtrl 7402;

    CMN_var_vote params ["_voteId", "_title", "_options"];

    {
        _listCtrl lbAdd _x;
    } forEach _options;

    _listCtrl lbSetCurSel 0;

    private _shownState = [];

    waitUntil {
        if (isNull _display) exitWith {true};

        if (CMN_var_vote isEqualTo [] || {(CMN_var_vote select 0) != _voteId}) exitWith {
            _display closeDisplay 2;
            true
        };

        private _ownVote = [-1, CMN_var_ownVote select 1] select ((CMN_var_ownVote select 0) == _voteId);
        private _state = [ceil (((CMN_var_vote select 3) - serverTime) max 0), +CMN_var_voteCounts, _ownVote];

        // texts only change with the counts, the own vote or the remaining seconds
        if (_state isNotEqualTo _shownState) then {
            _shownState = _state;
            _state params ["_seconds", "_counts"];

            _titleCtrl ctrlSetText format ["%1 (%2 s)", _title, _seconds];

            {
                _listCtrl lbSetText [_forEachIndex, format ["%1 (%2)", _x, _counts param [_forEachIndex, 0]]];
                _listCtrl lbSetColor [_forEachIndex, [[1, 1, 1, 1], ["accent"] call UI_fnc_color] select (_forEachIndex == _ownVote)];
            } forEach _options;
        };

        sleep CMN_var_voteDialogInterval;
        false
    };
};

// "Vote" button / double click: votes for the selected option
CMN_fnc_voteSelected = {
    private _display = uiNamespace getVariable ["CMN_voteDialog", displayNull];
    private _index = lbCurSel (_display displayCtrl 7402);

    if (_index < 0 || {CMN_var_vote isEqualTo []}) exitWith {};

    private _voteId = CMN_var_vote select 0;
    CMN_var_ownVote = [_voteId, _index];
    [player, _voteId, _index] remoteExecCall ["CMN_fnc_castVote", 2];
};
