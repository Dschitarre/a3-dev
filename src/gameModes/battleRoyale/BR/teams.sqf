// Battle Royale teams (server and client): slots and teams, hostility, team player groups and the team vehicle action.
// Everyone is a renegade (free for all, as in GunGame); each AI has its own group that ignores the AI's team mates.
// Players of a team share a group (group channel); AI never joins it, so it never becomes local to a player's machine.

BR_var_maxSlots = 150;                  // playable slots; editor leaders and other non-playable units never count
BR_var_renegadeRating = -100000;        // far below -2000: even many kill ratings cannot lift a unit out of it
BR_var_teamVehicleDistance = 7;         // the team vehicle action is offered this close to the vehicle

// ---- slots and teams (server) ----

/*
    Slot ids follow the playable units within the editor groups; no variable names are required.
    Team id = floor (slot id / team size): with squads the slots
    "Squad 1" form team 0, with duos each "Pair" is a team, solo every slot is its own team.
*/
BR_fnc_initTeamsServer = {
    BR_var_slotUnits = [];
    private _playable = playableUnits + switchableUnits;
    _playable = _playable select {_x isKindOf "CAManBase" && {!(_x isKindOf "HeadlessClient_F")}};
    {
        {
            if (_x in _playable && {count BR_var_slotUnits < BR_var_maxSlots}) then {
                BR_var_slotUnits pushBackUnique _x;
            };
        } forEach units _x;
    } forEach allGroups;
    {
        _x setVariable ["BR_var_slotId", _forEachIndex, true];
        _x setVariable ["BR_var_teamId", floor (_forEachIndex / BR_var_teamSize), true];
    } forEach BR_var_slotUnits;
    private _slotCount = count BR_var_slotUnits;
    BR_var_teamCount = ceil (_slotCount / BR_var_teamSize);

    // the editor's slot groups go once they are empty (every AI gets an own group): a side has at most 288 groups
    {
        if (!isNull _x) then {
            (group _x) deleteGroupWhenEmpty true;
        };
    } forEach BR_var_slotUnits;

    // team player groups only for teams with players (BR_fnc_teamPlayerGroup)
    BR_var_teamPlayerGroups = [];

    for "_i" from 1 to BR_var_teamCount do {
        BR_var_teamPlayerGroups pushBack grpNull;
    };

    publicVariable "BR_var_teamPlayerGroups";
};

// server: the group of the team's players, created for its first player and gone once the last one left
BR_fnc_teamPlayerGroup = {
    params ["_teamId"];
    while {count BR_var_teamPlayerGroups<=_teamId} do {BR_var_teamPlayerGroups pushBack grpNull};

    private _group = BR_var_teamPlayerGroups param [_teamId, grpNull];

    if (isNull _group) then {
        // players' teams are slot teams: their ids are below BR_var_teamCount
        _group = createGroup [independent, true];
        BR_var_teamPlayerGroups set [_teamId, _group];
        publicVariable "BR_var_teamPlayerGroups";
    };

    _group
};

/*
    Server: empty groups of the server go (groups made by joining grpNull are not deleted by themselves). Logs the
    groups per side with _log.
*/
BR_fnc_cleanUpGroups = {
    params [["_log", false]];

    {
        if (local _x && {(units _x) isEqualTo []} && {!(_x in BR_var_teamPlayerGroups)}) then {
            deleteGroup _x;
        };
    } forEach allGroups;

    if (_log) then {
        diag_log format ["BR groups per side: %1", [west, east, independent, civilian] apply {
            private _side = _x;
            format ["%1 %2", _side, {side _x isEqualTo _side} count allGroups]
        }];
    };
};

// ---- teams (server and client) ----

BR_fnc_isTeammate = {
    params ["_unitA", "_unitB"];

    (_unitA getVariable ["BR_var_teamId", -1]) == (_unitB getVariable ["BR_var_teamId", -2])
};

// the team's units of the roster (warmup: the planned roster, afterwards: the combatants, dead ones included; on the
// server from the team roster of BR_fnc_lockRoster - with up to 200 combatants the AI asks this all the time)
BR_fnc_teamUnits = {
    params ["_teamId"];

    if (!isNil "BR_var_teamRoster") exitWith {
        (BR_var_teamRoster getOrDefault [_teamId, []]) select {!isNull _x}
    };

    BR_var_rosterUnits select {!isNull _x && {(_x getVariable ["BR_var_teamId", -1]) == _teamId}}
};

// ---- hostility (where the unit is local) ----

BR_fnc_makeRenegade = {
    params ["_unit"];

    _unit addRating (BR_var_renegadeRating - rating _unit);
};

// server, AI tick: the AI's group ignores the unit's team mates; redone whenever the unit is in a new group
BR_fnc_applyTeamIgnores = {
    params ["_unit"];

    private _group = group _unit;

    if ((_unit getVariable ["BR_var_ignoresGroup", grpNull]) isEqualTo _group) exitWith {};

    _unit setVariable ["BR_var_ignoresGroup", _group];

    // "_group ignoreTarget [_x, true]" by name: the SQF checker (SQFLint) does not know this command yet
    {
        [_group, [_x, true]] remoteExecCall ["ignoreTarget", 2];
    } forEach (([_unit getVariable ["BR_var_teamId", -1]] call BR_fnc_teamUnits) - [_unit]);
};

// ---- team vehicles (client) ----
// Renegades cannot get into a vehicle that holds another renegade, team mates included, so team mates get an action.

BR_fnc_addTeamVehicleAction = {
    player addAction [
        "Get in (team vehicle)",
        {
            params ["", "_caller"];

            _caller moveInAny cursorObject;
        },
        nil,
        5,
        true,
        true,
        "",
        "[_this, cursorObject] call BR_fnc_canEnterTeamVehicle"
    ];
};

BR_fnc_canEnterTeamVehicle = {
    params ["_unit", "_vehicle"];

    isNull objectParent _unit &&
    {alive _vehicle} &&
    {_vehicle isKindOf "LandVehicle" || {_vehicle isKindOf "Ship"}} &&
    {_unit distance _vehicle < BR_var_teamVehicleDistance} &&
    {((crew _vehicle) findIf {alive _x && {[_x, _unit] call BR_fnc_isTeammate}}) != -1} &&
    {((fullCrew [_vehicle, "", true]) findIf {isNull (_x select 0)}) != -1}
};
