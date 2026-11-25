// Battle Royale results (server and client): kills, team eliminations with their placement, the end of the match when
// one team is left and the results screen (BR_dialogResults) with placement and kills per combatant.

BR_var_endDelay = 30;                   // seconds the results show before the mission ends

// ---- kills and eliminations (server) ----

// "EntityKilled" mission event handler
BR_fnc_entityKilled = {
    params ["_unit", "_killer", "_instigator"];

    if (!(_unit getVariable ["BR_var_inMatch", false]) || {BR_var_state in ["warmup", "ended"]}) exitWith {};

    if (isNull _instigator) then {
        _instigator = _killer;
    };

    // a vehicle (run over): its commander gets the kill
    if (!isNull _instigator && {!(_instigator isKindOf "CAManBase")}) then {
        _instigator = effectiveCommander _instigator;
    };

    // died downed without a killer (bled out, zone, team out): who downed it (BR\downed.sqf)
    if (isNull _instigator || {_instigator isEqualTo _unit}) then {
        _instigator = _unit getVariable ["BR_var_downedBy", objNull];
    };

    if (
        !isNull _instigator &&
        {_instigator != _unit} &&
        {_instigator getVariable ["BR_var_inMatch", false]} &&
        {!([_instigator, _unit] call BR_fnc_isTeammate)}
    ) then {
        _instigator setVariable ["BR_var_kills", (_instigator getVariable ["BR_var_kills", 0]) + 1, true];
    };

    [_unit getVariable ["BR_var_teamId", -1]] call BR_fnc_checkTeamEliminated;
    call BR_fnc_publishAliveCounts;
    call BR_fnc_checkMatchEnd;
};

// team ids with a living combatant
BR_fnc_aliveTeams = {
    private _teams = [];

    {
        if (alive _x) then {
            _teams pushBackUnique (_x getVariable ["BR_var_teamId", -1]);
        };
    } forEach BR_var_rosterUnits;

    _teams
};

BR_fnc_publishAliveCounts = {
    private _counts = [{alive _x} count BR_var_rosterUnits, count (call BR_fnc_aliveTeams)];

    if (_counts isNotEqualTo BR_var_aliveCounts) then {
        BR_var_aliveCounts = _counts;
        publicVariable "BR_var_aliveCounts";
    };
};

// a team whose last combatant died gets its placement: the number of teams still alive + 1
BR_fnc_checkTeamEliminated = {
    params ["_teamId"];

    if (isNil "BR_var_teamPlacements") then {
        BR_var_teamPlacements = createHashMap;
    };

    private _teamUnits = [_teamId] call BR_fnc_teamUnits;

    if (_teamId in BR_var_teamPlacements || {(_teamUnits findIf {alive _x}) != -1}) exitWith {};

    private _placement = count (call BR_fnc_aliveTeams) + 1;
    BR_var_teamPlacements set [_teamId, _placement];

    private _players = _teamUnits select {isPlayer _x};

    if (_players isNotEqualTo []) then {
        ["brEliminated", [str _placement, str count BR_var_matchTeams]] remoteExecCall ["BIS_fnc_showNotification", _players];
    };
};

// one team left (with only one team in the match: none left) ends the match
BR_fnc_checkMatchEnd = {
    if (BR_var_state in ["warmup", "ended"]) exitWith {};

    private _aliveTeams = call BR_fnc_aliveTeams;

    if (count _aliveTeams > 1 || {count _aliveTeams == 1 && {count BR_var_matchTeams < 2}}) exitWith {};

    [_aliveTeams param [0, -1]] spawn BR_fnc_endMatch;
};

// scheduled: results to everyone, then the mission ends
BR_fnc_endMatch = {
    params ["_winnerTeam"];

    if (BR_var_state == "ended") exitWith {};

    ["ended"] call BR_fnc_setState;

    if (isNil "BR_var_teamPlacements") then {
        BR_var_teamPlacements = createHashMap;
    };

    if (_winnerTeam != -1) then {
        BR_var_teamPlacements set [_winnerTeam, 1];
    };

    // [[placement, team id, [[name, kills, alive], ...]], ...] sorted by placement
    BR_var_results = BR_var_matchTeams apply {
        [
            BR_var_teamPlacements getOrDefault [_x, 1],
            _x,
            ([_x] call BR_fnc_teamUnits) apply {
                [_x getVariable ["BR_var_name", name _x], _x getVariable ["BR_var_kills", 0], alive _x]
            }
        ]
    };
    BR_var_results sort true;
    publicVariable "BR_var_results";

    [] remoteExecCall ["BR_fnc_showResults", [0, -2] select isDedicated];

    if (!isNil "KF_fnc_displayKillInfo") then {
        call KF_fnc_displayKillInfo;
    };

    sleep BR_var_endDelay;

    "BR_matchEnd" call BIS_fnc_endMissionServer;
};

// ---- results screen (client) ----

BR_fnc_showResults = {
    if (!hasInterface) exitWith {};

    [] spawn {
        disableSerialization;

        waitUntil {!isNil "BR_var_results"};

        createDialog "BR_dialogResults";

        private _display = uiNamespace getVariable "BR_dialogResults";
        private _ranking = _display displayCtrl 1500;
        private _myTeam = player getVariable ["BR_var_teamId", -1];
        private _myName = player getVariable ["BR_var_name", profileName];
        private _youColor = ["you"] call UI_fnc_color;
        private _teamColor = [independent] call UI_fnc_sideColor;
        private _dim = [1, 1, 1, 0.5];
        private _myPlacement = 0;

        {
            _x params ["_placement", "_teamId", "_members"];

            if (_teamId == _myTeam) then {
                _myPlacement = _placement;
            };

            {
                _x params ["_name", "_kills", "_alive"];

                private _row = _ranking lnbAddRow [format ["#%1", _placement], format ["Team %1", _teamId + 1], _name, str _kills];
                private _color = switch (true) do {
                    case (_teamId == _myTeam && {_name == _myName}): {_youColor};
                    case (_teamId == _myTeam): {_teamColor};
                    case (!_alive && {_placement != 1}): {_dim};
                    default {[1, 1, 1, 1]};
                };

                for "_column" from 0 to 3 do {
                    _ranking lnbSetColor [[_row, _column], _color];
                };
            } forEach _members;
        } forEach BR_var_results;

        private _winners = BR_var_results select {(_x select 0) == 1};
        private _winnerNames = if (_winners isEqualTo []) then {
            "nobody"
        } else {
            (((_winners select 0) select 2) apply {_x select 0}) joinString ", "
        };
        private _summary = format ["<t size='1.2' font='%1'>Winner: %2</t>", CMN_var_fontBold, _winnerNames];

        if (_myPlacement > 0) then {
            _summary = _summary + format [
                "<br/>Your team placed <t color='%1'>#%2</t> of %3",
                ["you"] call UI_fnc_colorHtml,
                _myPlacement,
                count BR_var_results
            ];
        };

        (_display displayCtrl 1501) ctrlSetStructuredText parseText _summary;
    };
};
