// Battle Royale AI fill (server): every slot without a player is an AI. Until the flight the roster follows joining and
// leaving players: teams with players get AI team mates, then whole AI teams up to the wanted number of combatants; the
// rest waits parked. More combatants than slots: at the flight extra AI teams are created on the server (each AI in
// its own group). From the flight on the roster is fixed and the AI takes over the units of players who leave.

BR_var_extraAiSpawnDelay = 0.02; // s between two created extra AI (no hitch when creating 160 units)

// ---- pool and roster ----

// AI name and skill, an own group (CMN_fnc_initAiUnit) that goes once it is empty (a side has at most 288 groups)
BR_fnc_initAiUnit = {
    params ["_unit"];

    [_unit] call CMN_fnc_initAiUnit;

    if (local (group _unit)) then {
        (group _unit) deleteGroupWhenEmpty true;
    };
};

BR_fnc_initPoolServer = {
    BR_var_rosterUnits = [];

    // AI-only teams are added in a random order that stays the same during the warmup
    BR_var_aiTeamOrder = [];

    for "_i" from 0 to BR_var_teamCount - 1 do {
        BR_var_aiTeamOrder pushBack _i;
    };

    BR_var_aiTeamOrder = BR_var_aiTeamOrder call BIS_fnc_arrayShuffle;

    {
        if (!isNull _x && {!isPlayer _x}) then {
            [_x] call BR_fnc_initAiUnit;
            [_x] call BR_fnc_parkUnit;
        };
    } forEach BR_var_slotUnits;

    // published even if empty: clients wait for it
    call BR_fnc_balanceRoster;
    publicVariable "BR_var_rosterUnits";
};

// the planned combatants (BR_var_rosterUnits, published on change); AI stays parked until the flight
BR_fnc_balanceRoster = {
    if (!isNil "BR_var_teamRoster") exitWith {};

    call BR_fnc_balanceGroups;
    private _slotUnits = BR_var_slotUnits select {!isNull _x};
    private _playerTeams = [];

    {
        if (isPlayer _x) then {
            _playerTeams pushBackUnique (_x getVariable "BR_var_teamId");
        };
    } forEach _slotUnits;

    // teams with players: the players, plus AI team mates if the fill is on
    private _roster = _slotUnits select {
        ((_x getVariable "BR_var_teamId") in _playerTeams) && {isPlayer _x || BR_var_aiFill}
    };

    if (BR_var_aiFill) then {
        {
            if (count _roster >= BR_var_targetCombatants) exitWith {};

            private _teamId = _x;
            _roster append (_slotUnits select {(_x getVariable "BR_var_teamId") == _teamId});
        } forEach (BR_var_aiTeamOrder - _playerTeams);
    };

    if (_roster isNotEqualTo BR_var_rosterUnits) then {
        BR_var_rosterUnits = _roster;
        publicVariable "BR_var_rosterUnits";
    };
};

// scheduled, start of the flight: the roster becomes the fixed list of combatants (extra AI teams included), all of them
// board the aircraft (parked); BR_var_teamRoster: team id -> its combatants
BR_fnc_lockRoster = {
    BR_var_groupsLocked = true;
    publicVariable "BR_var_groupsLocked";
    private _until = time + 5.5;

    waitUntil {
        sleep 0.01;
        (BR_var_slotUnits findIf {_x getVariable ["SC_var_groupMenuBusy", false]}) < 0 || {time > _until}
    };

    call BR_fnc_balanceRoster;

    BR_var_rosterUnits = BR_var_rosterUnits select {alive _x};
    call BR_fnc_createExtraAi;
    BR_var_rosterUnits append BR_var_extraUnits;

    // a unit without a team (its creation went wrong) is no combatant
    BR_var_rosterUnits = BR_var_rosterUnits select {!isNull _x && {alive _x} && {(_x getVariable ["BR_var_teamId", -1]) >= 0}};
    BR_var_matchTeams = [];
    BR_var_teamRoster = createHashMap;

    {
        private _teamId = _x getVariable "BR_var_teamId";

        BR_var_matchTeams pushBackUnique _teamId;
        (BR_var_teamRoster getOrDefaultCall [_teamId, {[]}, true]) pushBack _x;

        _x setVariable ["BR_var_inMatch", true, true];
        _x setVariable ["BR_var_aboard", true, true];
        _x setVariable ["BR_var_kills", 0, true];

        if (!isPlayer _x) then {
            _x setVariable ["BR_var_name", name _x, true];
            [_x] call BR_fnc_prepareAi;
            [_x] call BR_fnc_initDownedAi;
        };

        [_x] call BR_fnc_parkUnit;
    } forEach BR_var_rosterUnits;

    publicVariable "BR_var_rosterUnits";
    [true] call BR_fnc_cleanUpGroups;
    diag_log format ["BR roster: %1 combatants in %2 teams", count BR_var_rosterUnits, count BR_var_matchTeams];
};

/*
    Scheduled, end of the warmup (BR_fnc_prepareMatch) and roster lock (the rest, if any), with AI fill: AI-only teams
    beyond the mission's slots up to the wanted number of combatants (BR_var_extraUnits, parked until the flight),
    created on the server (each AI in its own group, local to the server), team ids after the slot teams. They are no
    slots: players never take them over, and they do not respawn as spares.
*/
BR_fnc_createExtraAi = {
    if (isNil "BR_var_extraUnits") then {
        BR_var_extraUnits = [];
    };

    BR_var_extraUnits = BR_var_extraUnits select {alive _x};

    private _missing = BR_var_targetCombatants - count BR_var_rosterUnits - count BR_var_extraUnits;

    if (!BR_var_aiFill || {_missing <= 0}) exitWith {};

    private _unitType = typeOf ((BR_var_slotUnits select {!isNull _x}) select 0);

    // empty groups first: every extra AI takes a group of a side's 288
    call BR_fnc_cleanUpGroups;

    for "_i" from 0 to _missing - 1 do {
        private _group = createGroup [independent, true];

        if (isNull _group) exitWith {
            diag_log format ["BR AI fill: group limit reached, %1 of %2 extra AI created", _i, _missing];
        };

        private _unit = _group createUnit [_unitType, BR_var_parkPos, [], 0, "CAN_COLLIDE"];

        if (isNull _unit) exitWith {
            deleteGroup _group;
            diag_log format ["BR AI fill: unit creation failed, %1 of %2 extra AI created", _i, _missing];
        };

        _unit setVariable ["BR_var_teamId", BR_var_teamCount + floor ((count BR_var_extraUnits) / BR_var_teamSize), true];
        [_unit] call BR_fnc_initAiUnit;
        [_unit] call BR_fnc_parkUnit;
        BR_var_extraUnits pushBack _unit;
        sleep BR_var_extraAiSpawnDelay;
    };
};

// ---- respawns and disconnects ----

// "EntityRespawned" mission event handler: the new unit keeps the slot; respawned AI is a parked spare, never a combatant
BR_fnc_entityRespawned = {
    params ["_newEntity", "_oldEntity"];

    private _slotId = _oldEntity getVariable ["BR_var_slotId", -1];

    if (_slotId == -1) exitWith {};

    _newEntity setVariable ["BR_var_slotId", _slotId, true];
    _newEntity setVariable ["BR_var_teamId", _oldEntity getVariable "BR_var_teamId", true];
    private _size = _oldEntity getVariable "SC_var_groupTargetSize";
    if (!isNil "_size") then {_newEntity setVariable ["SC_var_groupTargetSize", _size, true]};
    BR_var_slotUnits set [_slotId, _newEntity];

    if (!isPlayer _newEntity) then {
        [_newEntity] call BR_fnc_initAiUnit;
        [_newEntity] call BR_fnc_parkUnit;
    };
};

/*
    "HandleDisconnect" mission event handler (returns true: the unit stays as AI). Before the flight the unit goes back
    into the pool (the warmup rebalances the roster); afterwards the AI takes over a living combatant.
*/
BR_fnc_handleDisconnect = {
    params ["_unit"];

    if (isNull _unit) exitWith {};

    [_unit] spawn {
        params ["_unit"];

        waitUntil {
            sleep 0.25;
            isNull _unit || {!isPlayer _unit}
        };

        if (isNull _unit || {!alive _unit}) exitWith {};

        // AI name, skill and an own group: the unit then is local to the server, not to the player who leads the group
        [_unit] call BR_fnc_initAiUnit;
        private _timeout = time + 5;

        waitUntil {
            sleep 0.25;
            isNull _unit || {local _unit} || {time > _timeout}
        };

        if (isNull _unit || {!local _unit}) exitWith {};

        if (BR_var_state != "warmup" && {_unit getVariable ["BR_var_inMatch", false]}) exitWith {

            // a downed player who left dies (nobody would bleed him out); else the AI goes down from now on as well
            if (_unit getVariable ["ais_unconscious", false]) exitWith {
                [_unit, _unit getVariable ["BR_var_downedBy", objNull]] call BR_fnc_killDowned;
            };

            [_unit] call BR_fnc_initDownedAi;
            [_unit] call BR_fnc_aiTakeOver;
        };

        [_unit] call BR_fnc_parkUnit;
    };
};
