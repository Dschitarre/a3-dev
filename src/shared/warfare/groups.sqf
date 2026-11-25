// Groups: the SC groups (virtual squads) of players and AI, switching, respawn, group spawn, and the engine groups:
// players-only groups of the players of an SC group, one group per AI on foot, the watchdog (mostly server).

// ---- groups ----

SC_fnc_getGroupUnits = {
    params ["_unit"];

    _unit getVariable ["SC_var_groupUnits", [_unit]]
};

// broadcasts a unit's group array, but only when it changed since the last broadcast
SC_fnc_publishGroupUnits = {
    params ["_unit"];

    private _group = _unit getVariable ["SC_var_groupUnits", [_unit]];

    if (_group isNotEqualTo (_unit getVariable ["SC_var_publishedGroupUnits", []])) then {
        _unit setVariable ["SC_var_groupUnits", _group, true];
        _unit setVariable ["SC_var_publishedGroupUnits", +_group];
    };
};

SC_fnc_setGroupUnits = {
    params ["_units", "_group", ["_publish", false]];

    {
        _x setVariable ["SC_var_groupUnits", _group];

        if _publish then {
            [_x] call SC_fnc_publishGroupUnits;
        };
    } forEach _units;
};

SC_fnc_switchGroup = {
    params ["_unitToSwitch", "_unitToSwitchTo"];

    private _groupToSwitchFrom = (_unitToSwitch getVariable ["SC_var_groupUnits", [_unitToSwitch]]) - [_unitToSwitch];
    private _groupToSwitchTo = (_unitToSwitchTo getVariable ["SC_var_groupUnits", [_unitToSwitchTo]]) + [_unitToSwitch];
    _groupToSwitchTo = [_groupToSwitchTo, [], {name _x}, "DESCEND"] call BIS_fnc_sortBy;

    [_groupToSwitchFrom, _groupToSwitchFrom] call SC_fnc_setGroupUnits;
    [_groupToSwitchTo, _groupToSwitchTo] call SC_fnc_setGroupUnits;
};

SC_fnc_updateGroupAfterRespawn = {
    params ["_oldEntity", "_newEntity"];

    _newEntity setVariable ["SC_var_groupTargetSize", (_oldEntity getVariable "SC_var_groupTargetSize")];

    private _group = ((_oldEntity getVariable ["SC_var_groupUnits", [_oldEntity]]) - [_oldEntity]) + [_newEntity];
    _group = [_group, [], {name _x}, "DESCEND"] call BIS_fnc_sortBy;
    [[_oldEntity], [_oldEntity], true] call SC_fnc_setGroupUnits;
    [_group, _group, true] call SC_fnc_setGroupUnits;
};

SC_fnc_removeFromGroup = {
    params ["_unit"];

    _unit setVariable ["SC_var_groupTargetSize", nil];

    private _group = ((_unit getVariable ["SC_var_groupUnits", [_unit]]) - [_unit]);
    [[_unit], [_unit], true] call SC_fnc_setGroupUnits;
    [_group, _group, true] call SC_fnc_setGroupUnits;
};

// a unit spawns at a group mate: in a free seat of his vehicle (an AI in its squad's vehicle also gets that seat
// assigned; an AI never in the driver seat of a spawn vehicle) or next to him
SC_fnc_groupSpawn = {
    params ["_unit", "_groupMate"];

    private _parGroupMate = objectParent _groupMate;
    private _freeSeats = [];

    if (!(isNull _parGroupMate) && {
        _freeSeats = (fullCrew [_parGroupMate, "", true]) select {isNull (_x select 0)};

        (_freeSeats isNotEqualTo [])
    }) then {
        {
            private _role = _x;
            private _pos = if (
                ((locked _parGroupMate) > 1) ||
                {(_role == "driver") && {!(isPlayer _unit)} && {_parGroupMate getVariable ["SC_var_spawnVehicle", false]}}
            ) then {-1} else {(_freeSeats apply {_x select 1}) find _role};

            if (_pos != -1) exitWith {
                private _seat = _freeSeats select _pos;
                _seat params ["", "", "_cargoIndex", "_turretPath", "_personTurret"];

                switch _role do {
                    case "driver": {[_unit, _parGroupMate] remoteExecCall ["moveInDriver", _unit];};
                    case "gunner": {[_unit, _parGroupMate] remoteExecCall ["moveInGunner", _unit];};
                    case "turret": {[_unit, [_parGroupMate, _turretPath]] remoteExecCall ["moveInTurret", _unit];};
                    case "commander": {[_unit, _parGroupMate] remoteExecCall ["moveInCommander", _unit];};
                    case "cargo": {[_unit, [_parGroupMate, _cargoIndex]] remoteExecCall ["moveInCargo", _unit];};
                };

                if (!(isPlayer _unit) && {(group _unit) isEqualTo (group _groupMate)}) then {
                    [_unit, _parGroupMate, _seat] call SC_fnc_aiAssignSeat;
                };

                if (isPlayer _groupMate) then {
                    private _groupMatesInVeh =(([_unit] call SC_fnc_getGroupUnits) -[_unit]) select {(alive
                        _x) && {(objectParent _x) isEqualTo _parGroupMate}};
                    ["groupMateSpawned",
                        [(_unit getVariable "SC_var_name"),
                        ("in your " +([(typeOf _parGroupMate)] call SC_fnc_getDisplayName))],
                        _groupMatesInVeh] call SC_fnc_notifyPlayers;
                };
            };
        } forEach ["driver", "gunner", "turret", "commander", "cargo"];
    } else {
        private _safePos = [0, 0];
        private _rad = 1;

        waitUntil {
            _pos = getPosWorld _groupMate;
            _pos set [2, 0];

            waitUntil {_pos findEmptyPositionReady [0, _rad]};
            _safePos = _pos findEmptyPosition [0, _rad, "B_soldier_F"];
            _rad = _rad + 1;

            (_safePos isNotEqualTo [])
        };

        _unit setPos _safePos;

        if (isPlayer _groupMate) then {
            ["groupMateSpawned", [(_unit getVariable "SC_var_name"), "on your position"]] remoteExec ["BIS_fnc_showNotification", _groupMate];
        };
    };
};

// ---- group sizes ----

// Every side is split into squads of SC_var_squadSize automatically: its units (its players and the AI it is filled
// with, SC_fnc_getWantedAiAmounts) without the members of the groups players customized (SC_fnc_isGroupCustom: they
// stay as they are) are partitioned into squads of 4, the rest into squads of 3 (n mod 4 = 3: one squad of 3; = 2: two
// of 3; = 1: three of 3 - never a squad of 5, user decision 2026-11-14; 5 units: 3 + 2; 1 - 4 units: one squad). The
// automatic groups get these sizes (groups
// with players first, then the ones with the most members), so units only move when the rule is broken: a group fills
// up to its size with free AI, surplus AI leave and fill other groups, a group that gets no size dissolves. Sizes kept
// by the units through respawns and suspends. The group menu allows sizes 1 - SC_var_squadMaxSize.
SC_var_squadSize = 4;
SC_var_squadMaxSize = 8;

// sizes (descending) of the squads of _n units
SC_fnc_squadSizes = {
    params ["_n"];

    if (_n <= 0) exitWith {[]};
    if (_n <= SC_var_squadSize) exitWith {[_n]};
    if (_n == 5) exitWith {[3, 2]};

    private _rest = _n % 4;
    private _sizes = [];

    // squads of 4 that give way to the squads of 3 of the rest: rest 1 takes two of them (9 = 3 + 3 + 3), rest 2 one
    // (6 = 3 + 3), rest 3 none
    for "_i" from 1 to ((floor (_n / 4)) - ([0, 2, 1, 0] select _rest)) do {
        _sizes pushBack 4;
    };

    switch _rest do {
        case 1: {_sizes append [3, 3, 3]};
        case 2: {_sizes append [3, 3]};
        case 3: {_sizes pushBack 3};
    };

    _sizes sort false;
    _sizes
};

// whether players customized a group (_groupUnits): one of its players set its size or a lock or joined it from the
// group menu (SC_var_groupCustom, SC\groupMenu.sqf); such a group keeps its size and members
SC_fnc_isGroupCustom = {
    params ["_groupUnits"];

    (_groupUnits findIf {(isPlayer _x) && {_x getVariable ["SC_var_groupCustom", false]}}) != -1
};

// server, every pass of the group loop for a side of _population units: the sizes of its automatic groups (see above).
// Returns the sizes no group got (free units start new groups with them).
SC_fnc_balanceGroupSizes = {
    params ["_side", "_sidesUnits", "_population"];

    private _seen = [];
    private _auto = [];
    private _customMembers = 0;

    {
        if (!(isNull _x) && {!(_x in _seen)}) then {
            private _groupUnits = ([_x] call SC_fnc_getGroupUnits) select {!(isNull _x)};
            private _targetSize = [_x] call SC_fnc_getGroupTargetSize;

            _seen pushBack _x;
            _seen append _groupUnits;

            if (_targetSize != -1) then {
                if ([_groupUnits] call SC_fnc_isGroupCustom) then {
                    _customMembers = _customMembers + (_targetSize max (count _groupUnits));
                } else {
                    // (the index is a unique sort key: the units after it are never compared)
                    _auto pushBack [[0, 1] select ((_groupUnits findIf {isPlayer _x}) != -1),
                        count _groupUnits, _targetSize, count _auto, _groupUnits];
                };
            };
        };
    } forEach _sidesUnits;

    private _sizes = [_population - _customMembers] call SC_fnc_squadSizes;
    _auto sort false;

    {
        _x params ["", "", "_targetSize", "", "_groupUnits"];

        private _newSize = (_sizes param [_forEachIndex, 0]) max ({isPlayer _x} count _groupUnits);

        if (_newSize != _targetSize) then {
            ["groupSize", grpNull, _side, _targetSize, _newSize, count _groupUnits] call SC_fnc_aiLog;

            if (_newSize == 0) then {
                {
                    [_x] call SC_fnc_removeFromGroup;
                } forEach _groupUnits;
            } else {
                [_groupUnits, _newSize] call SC_fnc_setGroupTargetSize;
            };
        };
    } forEach _auto;

    _sizes select [count _auto]
};

// size a unit's SC group is filled up to (-1: the unit is in no formed group yet)
SC_fnc_getGroupTargetSize = {
    params ["_unit"];

    _unit getVariable ["SC_var_groupTargetSize", -1]
};

// every unit of a group carries the group's size
SC_fnc_setGroupTargetSize = {
    params ["_groupUnits", "_targetSize"];

    {
        _x setVariable ["SC_var_groupTargetSize", _targetSize];
    } forEach _groupUnits;
};

// a free AI: alive, alone and in no formed group (from the pool at the start, or the slot of a player who left)
SC_fnc_isFreeAi = {
    params ["_unit"];

    !(isNull _unit) &&
    {alive _unit} &&
    {!(isPlayer _unit)} &&
    {([_unit] call SC_fnc_getGroupTargetSize) == -1} &&
    {(count (_unit getVariable ["SC_var_groupUnits", [_unit]])) == 1}
};

// ---- engine groups ----

// The SC groups (squads) are virtual: membership, size, leader and locks only live in the SC data (SC_var_groupUnits
// and the variables of SC\groupMenu.sqf). Players and AI never share an engine group, so that every AI stays local to
// the server (the engine makes the AI of a group local to the machine of its leader):
// - the players of an SC group share one engine group of players only (group chat, VON; SC_fnc_syncPlayerGroup),
// - on foot every AI is an engine group of its own: no formations, the AI logic coordinates the AI of an SC group
//   through it (one objective per SC group, SC\ai\objectives.sqf; own approaches and positions, SC\ai\fireTeams.sqf);
//   AI with the same or a neighbouring objective that ride one vehicle form one engine group of AI only for the ride and
//   split again after it (SC_fnc_aiJoinRide, SC_fnc_aiSplitFireTeam),
// - a watchdog moves AI out of every engine group with a player and gives AI groups back to the server
//   (SC_fnc_aiGroupWatchdog).

// AI per engine group on foot
SC_var_aiFireTeamSize = 1;

// seconds between two passes of the watchdog
SC_var_aiWatchdogInterval = 2;

// whether an engine group may hold AI of an SC group (_groupUnits): no players, only units of that SC group
SC_fnc_isAiGroupOf = {
    params ["_group", "_groupUnits"];

    ((units _group) findIf {(isPlayer _x) || {!(_x in _groupUnits)}}) == -1
};

// the active (alive, not suspended) units of an engine group
SC_fnc_getActiveUnits = {
    params ["_group"];

    (units _group) select {(alive _x) && {simulationEnabled _x}}
};

// Engine group an AI joins at its spawn (grpNull: none): the group of a mate of its SC group whose vehicle has the mate
// in it and a free seat (the AI spawns in the seat and rides along until the ride ends)
SC_fnc_getSquadGroup = {
    params ["_unit"];

    private _groupUnits = [_unit] call SC_fnc_getGroupUnits;
    private _ownGroup = group _unit;
    private _riding = grpNull;

    {
        private _mate = _x;
        private _group = group _mate;

        if (
            (isNull _riding) &&
            {_mate isNotEqualTo _unit} &&
            {alive _mate} &&
            {simulationEnabled _mate} &&
            {!(isPlayer _mate)} &&
            {_group isNotEqualTo _ownGroup} &&
            {((_group getVariable ["SC_var_aiDelivery", []]) isEqualTo [])} &&
            {[_group, _groupUnits] call SC_fnc_isAiGroupOf}
        ) then {
            private _vehicle = _group getVariable ["SC_var_aiVehicle", objNull];

            if (
                (alive _vehicle) &&
                {(_vehicle getVariable ["SC_var_aiVehicleGroup", grpNull]) isEqualTo _group} &&
                {(([_group] call SC_fnc_getActiveUnits) findIf {(objectParent _x) isEqualTo _vehicle}) != -1} &&
                {((fullCrew [_vehicle, "", true]) findIf {isNull (_x select 0)}) != -1}
            ) then {
                _riding = _group;
            };
        };
    } forEach _groupUnits;

    _riding
};

// An AI stays in an engine group of AI only with other active members: a ride (it can hold AI of several SC groups with
// neighbouring objectives; groups on foot are split by SC_fnc_aiSplitFireTeam). Otherwise it is alone: at its spawn it
// rides along with a mate if it can (SC_fnc_getSquadGroup), else it gets a group of its own (a new one if its group
// has other units).
SC_fnc_joinSquad = {
    params ["_unit", ["_spawning", false]];

    private _ownGroup = group _unit;
    private _valid = ((units _ownGroup) findIf {isPlayer _x}) == -1;
    private _mates = ([_ownGroup] call SC_fnc_getActiveUnits) - [_unit];

    if (_valid && {_mates isNotEqualTo []} && {!_spawning}) exitWith {};

    if _spawning then {
        private _ridingGroup = [_unit] call SC_fnc_getSquadGroup;

        if !(isNull _ridingGroup) exitWith {
            [_unit] joinSilent _ridingGroup;
        };
    };

    if ((group _unit) isNotEqualTo _ownGroup) exitWith {};

    if (!_valid || {((units _ownGroup) - [_unit]) isNotEqualTo []}) then {
        [_unit] call SC_fnc_leaveSquad;
    };
};

// a living AI leaves its engine group into a new group of its own (pool, start of a new squad); empty groups are
// deleted by the engine
SC_fnc_leaveSquad = {
    params ["_unit"];

    if !(alive _unit) exitWith {};

    [_unit] joinSilent (createGroup [side (group _unit), true]);
};

// The players of an SC group (_players: its living players) in one engine group of players only, its leader's if
// that has only players of the group, else the first such one, else a new one of the first player; everybody else out
// of it (other players into a group of their own, AI by the watchdog). A lone player only leaves a group with others.
// Also keeps exactly one leader flag among them (SC_fnc_updateGroupLeaderFlag, SC\groupMenu.sqf).
SC_fnc_syncPlayerGroup = {
    params ["_players"];

    if (_players isEqualTo []) exitWith {};

    [_players] call SC_fnc_updateGroupLeaderFlag;

    private _isOwn = {
        params ["_group"];
        ((units _group) findIf {(alive _x) && {!(_x in _players)}}) == -1
    };

    private _leader = [_players] call SC_fnc_getGroupLeader;
    private _target = grpNull;

    if ([group _leader] call _isOwn) then {
        _target = group _leader;
    } else {
        private _index = _players findIf {[group _x] call _isOwn};

        if (_index != -1) then {
            _target = group (_players select _index);
        };
    };

    // (the server sees the group change of a remote player only a moment later: a join in progress is kept)
    if (isNull _target) then {
        ((_players select 0) getVariable ["SC_var_engineGroupJoin", [grpNull, -1]]) params ["_pendingGroup", "_since"];

        _target = if (!(isNull _pendingGroup) && {(time - _since) < 5} && {[_pendingGroup] call _isOwn}) then {
            _pendingGroup
        } else {
            createGroup [side (group (_players select 0)), true]
        };
    };

    {
        if ((group _x) isNotEqualTo _target) then {
            (_x getVariable ["SC_var_engineGroupJoin", [grpNull, -1]]) params ["_pendingGroup", "_since"];

            if ((_pendingGroup isNotEqualTo _target) || {(time - _since) > 5}) then {
                _x setVariable ["SC_var_engineGroupJoin", [_target, time]];
                [_x] joinSilent _target;
            };
        };
    } forEach _players;
};

// server: one pass of the watchdog over all engine groups of the sides. AI in a group with a player go into a new
// group of AI only; a group of AI that isn't local to the server (a player led it, controlled its UAV, ...) is given
// back to the server, a UAV crew only once no player controls the UAV any more. Every move is logged (SC_fnc_aiLog).
SC_fnc_aiWatchdogPass = {
    {
        private _group = _x;
        private _side = side _group;

        if (_side in SC_var_sides) then {
            private _living = (units _group) select {alive _x};
            private _ai = _living select {!(isPlayer _x)};

            if (_ai isNotEqualTo []) then {
                if ((_living findIf {isPlayer _x}) != -1) then {
                    private _newGroup = createGroup [_side, true];
                    _ai joinSilent _newGroup;
                    ["watchdog", _newGroup, "AI out of a group with players", count _ai, netId _group] call SC_fnc_aiLog;
                    _group = _newGroup;
                };

                // (0: not known yet, e.g. a group that was just created; checked again at the next pass)
                private _owner = groupOwner _group;

                if (
                    ((_owner != clientOwner) && {_owner != 0}) ||
                    {(_ai findIf {!((owner _x) in [clientOwner, 0])}) != -1}
                ) then {
                    private _uav = objectParent (_ai select 0);
                    private _uavControlled = !(isNull _uav) && {unitIsUAV _uav} &&
                        {((UAVControl _uav) findIf {(_x isEqualType objNull) && {isPlayer _x}}) != -1};

                    if !_uavControlled then {
                        private _done = _group setGroupOwner clientOwner;
                        ["watchdog", _group, "back to the server", _owner, _done, count _ai, [typeOf _uav, "-"] select (isNull _uav)] call SC_fnc_aiLog;
                    };
                };
            };
        };
    } forEach allGroups;
};

SC_fnc_aiGroupWatchdog = {
    waitUntil {
        sleep SC_var_aiWatchdogInterval;
        call SC_fnc_aiWatchdogPass;
        false
    };
};

SC_fnc_aiGroupLoop = {
    SC_var_aiWatchdogScript = [] spawn SC_fnc_aiGroupWatchdog;

    waitUntil {
        private _wantedAiAmounts = call SC_fnc_getWantedAiAmounts;

        {
            _side = _x;

            [_side, _wantedAiAmounts select _forEachIndex] call {
                params ["_side", "_wantedAi"];

                private _sidesUnits = [_side] call SC_fnc_getSidesUnits;

                // the sizes of the automatic groups (SC_fnc_balanceGroupSizes); the ones no group has yet are for
                // free units that start a new group
                private _openSizes = [_side, _sidesUnits, _wantedAi + ({isPlayer _x} count _sidesUnits)] call SC_fnc_balanceGroupSizes;

                {
                    private _unit = _x;

                    if !(isNull _unit) then {
                        private _group = _unit getVariable ["SC_var_groupUnits", [_unit]];

                        if ((_group find objNull) != -1) then {
                            _group = _group - [objNull];
                            [_group, _group] call SC_fnc_setGroupUnits;
                        };

                        private _targetSize = [_unit] call SC_fnc_getGroupTargetSize;

                        // a free AI or a player in no group yet starts a new group with a size no group has yet;
                        // without one it stays free until a group with room takes it
                        if ((_targetSize == -1) && {alive _unit} && {_openSizes isNotEqualTo []}) then {
                            _targetSize = _openSizes deleteAt 0;
                            [_group, _targetSize] call SC_fnc_setGroupTargetSize;
                        };

                        // more units than its size (players joined it, a smaller size): one of its AI leaves per pass
                        // (a suspended one first) and goes into another group (players always stay)
                        if ((_targetSize != -1) && {(count _group) > _targetSize}) then {
                            private _surplusIndex = _group findIf {!(isPlayer _x) && {!(simulationEnabled _x) || {!(alive _x)}}};

                            if (_surplusIndex == -1) then {
                                _surplusIndex = _group findIf {!(isPlayer _x)};
                            };

                            if (_surplusIndex != -1) then {
                                [_group select _surplusIndex] call SC_fnc_removeFromGroup;
                                _group = _unit getVariable ["SC_var_groupUnits", [_unit]];
                            };
                        };

                        // filled with free AI (not while the group is locked for AI, SC\groupMenu.sqf); a player also
                        // takes AI from AI groups if there are none, never from groups locked for AI. Dead members
                        // that are AI don't hold a place (the surplus check above removes them first), dead players do.
                        for "_i" from (({(alive _x) || {isPlayer _x} ||
                            {(getPlayerUID _x) != ""}} count _group) + 1) to ([_targetSize,
                            0] select ([_unit] call SC_fnc_isGroupLockedForAi)) do {
                            private _pos = _sidesUnits findIf {!(_x in _group) && {[_x] call SC_fnc_isFreeAi}};

                            if ((_pos == -1) && {isPlayer _unit}) then {
                                _pos = _sidesUnits findIf {
                                    !(isNull _x) &&
                                    {alive _x} &&
                                    {!(isPlayer _x)} &&
                                    {!(_x in _group)} &&
                                    {!([_x] call SC_fnc_isGroupLockedForAi)}
                                };
                            };

                            if (_pos == -1) exitWith {};

                            [(_sidesUnits select _pos), _unit] call SC_fnc_switchGroup;
                            _group = _unit getVariable ["SC_var_groupUnits", [_unit]];
                            [_group, _targetSize] call SC_fnc_setGroupTargetSize;
                        };

                        _unit setVariable ["SC_var_groupUnits", _group];
                    };
                } forEach _sidesUnits;

                // engine groups: AI into fire teams of their SC group, the players of an SC group into one group of
                // players only (once per SC group)
                private _syncedPlayers = [];

                {
                    if (!(isNull _x) && {alive _x}) then {
                        if (isPlayer _x) then {
                            if !(_x in _syncedPlayers) then {
                                private _players = ([_x] call SC_fnc_getGroupUnits) select {(alive _x) && {isPlayer _x}};
                                _syncedPlayers append _players;
                                [_players] call SC_fnc_syncPlayerGroup;
                            };
                        } else {
                            if (simulationEnabled _x) then {
                                [_x] call SC_fnc_joinSquad;
                            };
                        };
                    };

                    [_x] call SC_fnc_publishGroupUnits;
                } forEach _sidesUnits;
            };

            sleep 1;
        } forEach SC_var_sides;

        // the squads of the round have formed (SC_fnc_assignJoiningPlayer waits for it)
        SC_var_groupsFormed = true;

        false
    };
};
