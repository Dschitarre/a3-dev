// Group menu (key U, instead of the vanilla Dynamic Groups): the SC groups of the player's side with their players and
// AI, join / leave, and for the leader of a group its size, locks and kicks (client); the requests are checked and
// carried out by the server with the functions of SC\groups.sqf (server), the leader and the locks are read on both.

// ---- leader and locks (both) ----
// Modes can restrict team changes or enforce a hard player cap; SC keeps its existing policy.
SC_fnc_groupMenuCanManage = {true};
SC_fnc_groupMenuIsPlayer = {params ["_unit"];isPlayer _unit};
SC_fnc_groupMenuCanJoin = {true};

// Leader of an SC group (virtual, not the leader of an engine group): the first of its players (in the group's order)
// with the leader flag SC_var_isGroupLeader (public; set when a player starts a group, kept through respawns, the
// server's group loop gives it to the first player when the leader left), else its first player; objNull for a group
// without players (AI groups have no leader and no locks). _group: a unit of the group or the group's units.
SC_fnc_getGroupLeader = {
    params [["_group", objNull, [objNull, []]]];

    private _groupUnits = if (_group isEqualType objNull) then {[_group] call SC_fnc_getGroupUnits} else {_group};
    private _players = _groupUnits select {([_x] call SC_fnc_groupMenuIsPlayer)};

    if (_players isEqualTo []) exitWith {objNull};

    private _index = _players findIf {_x getVariable ["SC_var_isGroupLeader", false]};

    _players select (_index max 0)
};

// server: exactly one leader flag among the living players of an SC group (_players)
SC_fnc_updateGroupLeaderFlag = {
    params ["_players"];

    if (_players isEqualTo []) exitWith {};

    private _leader = [_players] call SC_fnc_getGroupLeader;

    {
        private _isLeader = _x isEqualTo _leader;

        if ((_x getVariable ["SC_var_isGroupLeader", false]) != _isLeader) then {
            _x setVariable ["SC_var_isGroupLeader", _isLeader, true];
        };
    } forEach _players;
};

// [locked for players, locked for AI] of an SC group: the locks of its leader. They are set on all its players (so they
// stay when the leadership changes), kept through respawns (SC_fnc_initGroupMenuServer) and reset when a player gets a
// new group of his own.
SC_fnc_getGroupLocks = {
    params [["_group", objNull, [objNull, []]]];

    private _leader = [_group] call SC_fnc_getGroupLeader;

    if (isNull _leader) exitWith {[false, false]};

    _leader getVariable ["SC_var_groupLocks", [false, false]]
};

// no player can join the group
SC_fnc_isGroupLockedForPlayers = {
    params [["_group", objNull, [objNull, []]]];

    ([_group] call SC_fnc_getGroupLocks) select 0
};

// no AI fills the group up (check of SC_fnc_aiGroupLoop); its AI stay unless they are kicked
SC_fnc_isGroupLockedForAi = {
    params [["_group", objNull, [objNull, []]]];

    ([_group] call SC_fnc_getGroupLocks) select 1
};

// [smallest, largest] size of a group: 1 - SC_var_squadMaxSize, but never less than its players
SC_fnc_groupMenuSizeRange = {
    params ["_groupUnits"];

    private _players = {([_x] call SC_fnc_groupMenuIsPlayer)} count _groupUnits;

    [1 max _players, SC_var_squadMaxSize max _players]
};

// server: a player customized his group (size, lock, joined it from the menu): the automatic squad sizes leave it as it
// is (SC_fnc_isGroupCustom, SC\groups.sqf) while he is in it; kept through respawns
SC_fnc_setGroupCustom = {
    params ["_player", "_custom"];

    _player setVariable ["SC_var_groupCustom", [nil, true] select _custom];
};

// ---- server ----

// seconds the server waits until it sees the engine group change of a player before it gives the request up
SC_var_groupMenuEngineGroupTimeout = 5;

// server init: the locks and the leader flag of a group stay with its players through respawns
SC_fnc_initGroupMenuServer = {
    addMissionEventHandler ["EntityRespawned", {
        params ["_newEntity", "_oldEntity"];

        private _locks = _oldEntity getVariable "SC_var_groupLocks";

        if (!(isNil "_locks") && {([_newEntity] call SC_fnc_groupMenuIsPlayer)}) then {
            _newEntity setVariable ["SC_var_groupLocks", _locks, true];
        };

        if ((_oldEntity getVariable ["SC_var_isGroupLeader", false]) && {([_newEntity] call SC_fnc_groupMenuIsPlayer)}) then {
            _newEntity setVariable ["SC_var_isGroupLeader", true, true];
        };

        if (_oldEntity getVariable ["SC_var_groupCustom", false]) then {
            _newEntity setVariable ["SC_var_groupCustom", true];
        };
    }];
};

// server: a request of a client only for its own player
SC_fnc_groupMenuIsSender = {
    params ["_player"];

    !(isNull _player) && {!isRemoteExecuted || {remoteExecutedOwner == (owner _player)}}
};

// server: no request of the unit in progress
SC_fnc_groupMenuIsFree = {
    params ["_unit"];

    (alive _unit) && {!(_unit getVariable ["SC_var_groupMenuBusy", false])}
};

// server (remoteExecCall of the client): the SC groups of the player's side, [[target size (-1: none yet), units], ...].
// Only groups with a living unit; pool AI (alone and in no formed group) are no group, a group with a player always is.
SC_fnc_groupMenuDataServer = {
    params ["_player"];

    if !([_player] call SC_fnc_groupMenuIsSender) exitWith {};

    private _listed = [];
    private _groups = [];

    {
        if (!(isNull _x) && {!(_x in _listed)}) then {
            private _groupUnits = ([_x] call SC_fnc_getGroupUnits) select {!(isNull _x)};
            private _targetSize = [_x] call SC_fnc_getGroupTargetSize;

            _listed pushBack _x;
            _listed append _groupUnits;

            if (
                ((_groupUnits findIf {alive _x}) != -1) &&
                {(_targetSize != -1) || {(_groupUnits findIf {([_x] call SC_fnc_groupMenuIsPlayer)}) != -1}}
            ) then {
                _groups pushBack [_targetSize, _groupUnits];
            };
        };
    } forEach ([_player getVariable ["SC_var_side", side (group _player)]] call SC_fnc_getSidesUnits);

    [_groups] remoteExecCall ["SC_fnc_groupMenuReceiveData", _player];
};

// server (scheduled): a player out of an engine group with other units into a new one of his own; true once the server
// sees the change (or when he was alone anyway), false after SC_var_groupMenuEngineGroupTimeout
SC_fnc_groupMenuLeaveEngineGroup = {
    params ["_player"];

    private _oldGroup = group _player;

    if ((units _oldGroup) isEqualTo [_player]) exitWith {true};

    [_player] joinSilent (createGroup [side _oldGroup, true]);

    private _timeout = time + SC_var_groupMenuEngineGroupTimeout;
    waitUntil {((group _player) isNotEqualTo _oldGroup) || {time > _timeout}};

    (group _player) isNotEqualTo _oldGroup
};

// server: AI leave a group that has more members than _targetSize (players always stay): first dead and suspended AI,
// then the ones furthest from _player; they become free AI that the group loop gives a new group
SC_fnc_groupMenuTrimGroup = {
    params ["_player", "_targetSize"];

    private _groupUnits = [_player] call SC_fnc_getGroupUnits;
    private _surplus = (count _groupUnits) - _targetSize;

    if (_surplus <= 0) exitWith {};

    private _ai = _groupUnits select {!(([_x] call SC_fnc_groupMenuIsPlayer))};
    private _order = [];

    {
        _order pushBack [[0, 1] select ((alive _x) && {simulationEnabled _x}), -(_x distance _player), _forEachIndex];
    } forEach _ai;

    _order sort true;

    {
        [_ai select (_x select 2)] call SC_fnc_removeFromGroup;
    } forEach (_order select [0, _surplus]);
};

// server: an AI that left a group becomes a free AI (the automatic squad sizes put it into a group with room, not the
// one it left: that one fills up with another AI first)
SC_fnc_groupMenuNewAiGroup = {
    params ["_unit"];

    [_unit] call SC_fnc_removeFromGroup;
};

// server (scheduled): a player leaves his SC group for a new automatic squad of his own (Leave, Kick) of the default
// size, no locks; the automatic squad sizes fill it with AI (they make room for it, SC_fnc_balanceGroupSizes). First out
// of the engine group shared with the other players of his old group. False if his engine group could not be changed.
SC_fnc_groupMenuNewGroup = {
    params ["_player"];
    if !([_player] call SC_fnc_groupMenuCanManage) exitWith {false};

    if !([_player] call SC_fnc_groupMenuLeaveEngineGroup) exitWith {false};
    if !([_player] call SC_fnc_groupMenuCanManage) exitWith {false};

    [_player] call SC_fnc_removeFromGroup;
    _player setVariable ["SC_var_groupLocks", nil, true];
    _player setVariable ["SC_var_isGroupLeader", true, true];
    [_player, false] call SC_fnc_setGroupCustom;
    [[_player], SC_var_squadSize] call SC_fnc_setGroupTargetSize;

    true
};

// server (scheduled): _player joins the SC group of _target. First out of an engine group shared with other players
// (see SC_fnc_groupMenuNewGroup), then into the SC group with its size and locks (surplus AI leave at once: a full
// group makes room), then into the engine group of the group's leader, if it has one (a player; the group loop keeps
// the players of an SC group in one engine group of players only, SC_fnc_syncPlayerGroup); the AI of an SC group stay
// in their fire teams, see SC_fnc_joinSquad.
SC_fnc_groupMenuMoveToGroup = {
    params ["_player", "_target"];

    // the groups can have changed while the engine group changed
    if (
        ([_player] call SC_fnc_groupMenuLeaveEngineGroup) &&
        {[_player,_target] call SC_fnc_groupMenuCanJoin} &&
        {alive _player} &&
        {!(isNull _target)} &&
        {!(_target in ([_player] call SC_fnc_getGroupUnits))}
    ) then {
        private _oldUnits = ([_player] call SC_fnc_getGroupUnits) - [_player];
        private _leader = [_target] call SC_fnc_getGroupLeader;
        private _locks = +([_target] call SC_fnc_getGroupLocks);
        private _targetSize = [_target] call SC_fnc_getGroupTargetSize;

        [_player, _target] call SC_fnc_switchGroup;
        _player setVariable ["SC_var_isGroupLeader", false, true];

        private _groupUnits = [_player] call SC_fnc_getGroupUnits;

        // a group without a size yet keeps its members; a group of players only can be larger than its size
        if (_targetSize == -1) then {
            _targetSize = count _groupUnits;
        };

        _targetSize = _targetSize max ({([_x] call SC_fnc_groupMenuIsPlayer)} count _groupUnits);
        [_groupUnits, _targetSize] call SC_fnc_setGroupTargetSize;
        _player setVariable ["SC_var_groupLocks", _locks, true];
        [_player, _targetSize] call SC_fnc_groupMenuTrimGroup;

        {
            [_x] call SC_fnc_publishGroupUnits;
        } forEach (_oldUnits + _groupUnits);

        // the players of an SC group share one engine group of players only (never one with AI)
        if (
            !(isNull _leader) &&
            {!(isNull (group _leader))} &&
            {((units (group _leader)) findIf {!(([_x] call SC_fnc_groupMenuIsPlayer))}) == -1}
        ) then {
            _player setVariable ["SC_var_engineGroupJoin", [group _leader, time]];
            [_player] joinSilent (group _leader);
        };

        private _playerName = _player getVariable ["SC_var_name", name _player];
        private _leaderName = _target getVariable ["SC_var_name", name _target];

        ["groupSystem", [format ["You joined the group of %1", _leaderName]]] remoteExec ["BIS_fnc_showNotification", _player];
        ["groupSystem", [format ["%1 joined your group", _playerName]], (([_player] call SC_fnc_getGroupUnits) - [_player])] call SC_fnc_notifyPlayers;
    };

    _player setVariable ["SC_var_groupMenuBusy", nil];
};

// server (remoteExecCall of the client): _player joins the SC group of _target (a unit of it): also a full group (an AI
// makes room), not a group locked for players
SC_fnc_groupMenuJoinServer = {
    params ["_player", "_target"];

    if (
        !([_player] call SC_fnc_groupMenuIsSender) ||
        {!([_player,_target] call SC_fnc_groupMenuCanJoin)} ||
        {isNull _target} ||
        {!([_player] call SC_fnc_groupMenuIsFree)} ||
        {_player getVariable ["ais_unconscious", false]} ||
        {(_target getVariable ["SC_var_side", sideUnknown]) != (_player getVariable ["SC_var_side", sideUnknown])} ||
        {_target in ([_player] call SC_fnc_getGroupUnits)}
    ) exitWith {};

    if ([_target] call SC_fnc_isGroupLockedForPlayers) exitWith {
        ["groupSystem", ["This group is locked for players"]] remoteExec ["BIS_fnc_showNotification", _player];
    };

    // a group joined from the menu is kept as it is by the automatic squad sizes
    [_player, true] call SC_fnc_setGroupCustom;
    _player setVariable ["SC_var_groupMenuBusy", true];
    [_player, _target] spawn SC_fnc_groupMenuMoveToGroup;
};

// server (remoteExecCall of the client): _player leaves his group for a new one of his own
SC_fnc_groupMenuLeaveServer = {
    params ["_player"];

    if (
        !([_player] call SC_fnc_groupMenuIsSender) ||
        {!([_player] call SC_fnc_groupMenuCanManage)} ||
        {!([_player] call SC_fnc_groupMenuIsFree)} ||
        {_player getVariable ["ais_unconscious", false]} ||
        {(count ([_player] call SC_fnc_getGroupUnits)) < 2}
    ) exitWith {};

    _player setVariable ["SC_var_groupMenuBusy", true];

    [_player] spawn {
        params ["_player"];

        private _oldUnits = ([_player] call SC_fnc_getGroupUnits) - [_player];

        if ([_player] call SC_fnc_groupMenuNewGroup) then {
            ["groupSystem", [format ["%1 left your group", _player getVariable ["SC_var_name", name _player]]], _oldUnits] call SC_fnc_notifyPlayers;
        };

        _player setVariable ["SC_var_groupMenuBusy", nil];
    };
};

// server (remoteExecCall of the client): the leader of a group kicks a member. A player (alive) gets a new group of his
// own, an AI starts a new group of its own (SC_fnc_groupMenuNewAiGroup); the group keeps its size and fills up with
// other AI unless it is locked for AI.
SC_fnc_groupMenuKickServer = {
    params ["_player", "_unit"];

    if (
        !([_player] call SC_fnc_groupMenuIsSender) ||
        {!([_player] call SC_fnc_groupMenuCanManage)} ||
        {isNull _unit} ||
        {_unit isEqualTo _player} ||
        {([_player] call SC_fnc_getGroupLeader) isNotEqualTo _player} ||
        {!(_unit in ([_player] call SC_fnc_getGroupUnits))}
    ) exitWith {};

    if !(([_unit] call SC_fnc_groupMenuIsPlayer)) exitWith {
        [_unit] call SC_fnc_groupMenuNewAiGroup;
    };

    if !([_unit] call SC_fnc_groupMenuIsFree) exitWith {};

    _unit setVariable ["SC_var_groupMenuBusy", true];

    [_player, _unit] spawn {
        params ["_player", "_unit"];

        if ([_unit] call SC_fnc_groupMenuNewGroup) then {
            ["groupSystem", [format ["%1 removed you from the group", _player getVariable ["SC_var_name", name _player]]]] remoteExec ["BIS_fnc_showNotification", _unit];
        };

        _unit setVariable ["SC_var_groupMenuBusy", nil];
    };
};

// server (remoteExecCall of the client): the leader sets his group's size (SC_fnc_groupMenuSizeRange); surplus AI leave
// at once, the group loop fills up a larger group
SC_fnc_groupMenuSetSizeServer = {
    params ["_player", ["_size", 1, [0]]];

    if(!([_player] call SC_fnc_groupMenuIsSender) || {!([_player] call SC_fnc_groupMenuCanManage)} ||
        {([_player] call SC_fnc_getGroupLeader) isNotEqualTo _player}) exitWith {};

    private _groupUnits = [_player] call SC_fnc_getGroupUnits;
    ([_groupUnits] call SC_fnc_groupMenuSizeRange) params ["_minSize", "_maxSize"];
    _size = ((round _size) max _minSize) min _maxSize;

    [_groupUnits, _size] call SC_fnc_setGroupTargetSize;
    [_player, true] call SC_fnc_setGroupCustom;
    [_player, _size] call SC_fnc_groupMenuTrimGroup;
};

// server (remoteExecCall of the client): the leader locks / unlocks his group for players (_index 0) or AI (_index 1)
SC_fnc_groupMenuSetLockServer = {
    params ["_player", ["_index", 0, [0]], ["_locked", false, [false]]];

    if (
        !([_player] call SC_fnc_groupMenuIsSender) ||
        {!([_player] call SC_fnc_groupMenuCanManage)} ||
        {!(_index in [0, 1])} ||
        {([_player] call SC_fnc_getGroupLeader) isNotEqualTo _player}
    ) exitWith {};

    private _groupUnits = [_player] call SC_fnc_getGroupUnits;
    private _locks = +([_groupUnits] call SC_fnc_getGroupLocks);
    _locks set [_index, _locked];

    {
        _x setVariable ["SC_var_groupLocks", _locks, true];
    } forEach (_groupUnits select {([_x] call SC_fnc_groupMenuIsPlayer)});

    [_player, true] call SC_fnc_setGroupCustom;
};

// server (scheduled, from SC_fnc_playerServer): a joining player goes into an automatic squad (SC group) of his side
// that isn't locked for players and has room (fewer members than its size) - the squad of the unit he took over counts
// too, as long as there are others in it -, else into any such squad (like a Join of the menu: an AI makes room);
// without any he starts a new squad of the default size (SC_fnc_groupMenuNewGroup)
SC_fnc_assignJoiningPlayer = {
    params ["_player"];

    // the group loop forms the squads of a new round first
    waitUntil {sleep 0.5; (isNull _player) || {!(isNil "SC_var_groupsFormed")}};

    if ((isNull _player) || {!(alive _player)}) exitWith {};

    // nothing of the group choices of a former player of this slot stays
    [_player, false] call SC_fnc_setGroupCustom;

    private _side = _player getVariable ["SC_var_side", side (group _player)];
    private _ownUnits = [_player] call SC_fnc_getGroupUnits;
    private _seen = [];
    private _squads = [];
    private _withRoom = [];

    // one unit per squad (its first unit stands for it)
    {
        private _groupUnits = [_x] call SC_fnc_getGroupUnits;
        private _first = _groupUnits param [0, _x];
        private _targetSize = [_x] call SC_fnc_getGroupTargetSize;

        if (
            !(_first in _seen) &&
            {_x isNotEqualTo _player} &&
            {alive _x} &&
            {simulationEnabled _x} &&
            {_targetSize != -1} &&
            {!([_x] call SC_fnc_isGroupLockedForPlayers)} &&
            {!([_groupUnits] call SC_fnc_isGroupCustom)}
        ) then {
            _seen pushBack _first;
            _squads pushBack _x;

            if ((count (_groupUnits - [_player])) < _targetSize) then {
                _withRoom pushBack _x;
            };
        };
    } forEach (([_side] call SC_fnc_getSidesUnits) select {!(isNull _x)});

    if (_squads isEqualTo []) exitWith {
        if ([_player] call SC_fnc_groupMenuNewGroup) then {
            [_player] call SC_fnc_publishGroupUnits;
        };
    };

    private _target = selectRandom ([_withRoom, _squads] select (_withRoom isEqualTo []));

    // drawn his own squad: he stays
    if (_target in _ownUnits) exitWith {};

    _player setVariable ["SC_var_groupMenuBusy", true];
    [_player, _target] call SC_fnc_groupMenuMoveToGroup;
};

// ---- client: key ----

// seconds between two updates of the open menu
SC_var_groupMenuRefreshInterval = 0.5;

// seconds after the menu was closed by its key in which the key doesn't open it again
SC_var_groupMenuReopenDelay = 0.3;

SC_var_groupMenuOwnGroupIcon = "\A3\ui_f\data\IGUI\Cfg\IslandMap\iconPlayer_ca.paa";
SC_var_groupMenuLockIcon = "\A3\ui_f\data\GUI\Rsc\RscDisplayDynamicGroups\Lock.paa";
SC_var_groupMenuDeadIcon = "\A3\ui_f\data\IGUI\Cfg\Revive\overlayIcons\d100_ca.paa";
SC_var_groupMenuUnconsciousIcon = "\A3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa";

SC_fnc_groupMenuIsKey = {
    params ["_key", "_ctrl"];

    !_ctrl && {_key in (actionKeys "TeamSwitch")}
};

// display 46, KeyDown: the TeamSwitch key (U, the key of the vanilla group menu) does nothing else. The first key press
// also starts the custom waypoint loop of the client (an AI of the player's group that drives him follows it).
SC_fnc_groupMenuMainKeyDown = {
    params ["", "_key", "", "_ctrl"];

    if (isNil "SC_var_customWaypointScript") then {
        SC_var_customWaypointScript = [] spawn SC_fnc_customWaypointLoop;
    };

    [_key, _ctrl] call SC_fnc_groupMenuIsKey
};

// ---- custom waypoint ----

// client (scheduled): the player's custom waypoint (Shift + click on the map) goes to the server whenever it changes
// (also for a new player unit after a respawn), [] when it is removed
SC_fnc_customWaypointLoop = {
    private _lastPlayer = objNull;
    private _lastPos = [];

    waitUntil {
        sleep 1;

        private _pos = customWaypointPosition;

        if (!(isNull player) && {(_pos isNotEqualTo _lastPos) || {player isNotEqualTo _lastPlayer}}) then {
            _lastPos = _pos;
            _lastPlayer = player;
            [player, _pos] remoteExecCall ["SC_fnc_setCustomWaypointServer", 2];
        };

        false
    };
};

// server (remoteExecCall of the client): the custom waypoint of a player, read by an AI that drives him
// (SC_fnc_aiDoChauffeur, SC\ai\squads.sqf)
SC_fnc_setCustomWaypointServer = {
    params ["_player", ["_pos", [], [[]]]];

    if !([_player] call SC_fnc_groupMenuIsSender) exitWith {};

    _player setVariable ["SC_var_customWaypoint", _pos];
};

// display 46, KeyUp: the key opens the menu when it is released (a held key repeats its KeyDown)
SC_fnc_groupMenuMainKeyUp = {
    params ["", "_key", "", "_ctrl"];

    if !([_key, _ctrl] call SC_fnc_groupMenuIsKey) exitWith {false};

    if (
        (alive player) &&
        {isNull (uiNamespace getVariable ["SC_var_groupMenuDialog", displayNull])} &&
        {(diag_tickTime - (missionNamespace getVariable ["SC_var_groupMenuClosedAt", -1])) > SC_var_groupMenuReopenDelay} &&
        {!(missionNamespace getVariable ["SC_var_roundEnded", false])}
    ) then {
        createDialog "groupMenuDialog";
    };

    true
};

// the menu's KeyDown / KeyUp: the key closes it when it is released
SC_fnc_groupMenuKeyDown = {
    params ["", "_key", "", "_ctrl"];

    [_key, _ctrl] call SC_fnc_groupMenuIsKey
};

SC_fnc_groupMenuKeyUp = {
    params ["_display", "_key", "", "_ctrl"];

    if !([_key, _ctrl] call SC_fnc_groupMenuIsKey) exitWith {false};

    SC_var_groupMenuClosedAt = diag_tickTime;
    _display closeDisplay 2;

    true
};

// ---- client: menu ----

// onLoad of groupMenuDialog
SC_fnc_groupMenuOpened = {
    SC_var_groupMenuGroups = [];            // last answer of the server
    SC_var_groupMenuRows = [];              // groups in the list's order: [units, target size, shown leader]
    SC_var_groupMenuMembers = [];           // members of the selected group in the list's order
    SC_var_groupMenuSelected = player;      // a unit of the selected group (the shown leader when chosen)
    SC_var_groupMenuSelectedMember = objNull;
    SC_var_groupMenuUpdating = false;       // the lists are being filled: their selection events are ignored
    SC_var_groupMenuBlockedUntil = 0;       // Join / Leave / Kick wait for the server's answer to the last click
    SC_var_groupMenuPending = createHashMap;    // changes not yet in the server's answer: key -> [value, until]
    SC_var_groupMenuSizeRange = [];

    call SC_fnc_groupMenuUpdate;
    [] spawn SC_fnc_groupMenuLoop;
};

// client (scheduled): asks the server for the groups while the menu is open (its answer updates the menu); closes the
// menu when the player dies or the round ends
SC_fnc_groupMenuLoop = {
    disableSerialization;

    private _display = uiNamespace getVariable ["SC_var_groupMenuDialog", displayNull];

    while {!(isNull _display)} do {
        if (!(alive player) || {missionNamespace getVariable ["SC_var_roundEnded", false]}) exitWith {
            _display closeDisplay 2;
        };

        [player] remoteExecCall ["SC_fnc_groupMenuDataServer", 2];
        uiSleep SC_var_groupMenuRefreshInterval;
    };
};

SC_fnc_groupMenuReceiveData = {
    params ["_groups"];

    SC_var_groupMenuGroups = _groups;
    call SC_fnc_groupMenuUpdate;
};

SC_fnc_groupMenuUpdate = {
    private _display = uiNamespace getVariable ["SC_var_groupMenuDialog", displayNull];

    if (isNull _display) exitWith {};

    SC_var_groupMenuUpdating = true;
    [_display] call SC_fnc_groupMenuUpdateGroups;
    [_display] call SC_fnc_groupMenuUpdateMembers;
    [_display] call SC_fnc_groupMenuUpdateControls;
    SC_var_groupMenuUpdating = false;
};

// shown leader of an SC group: its leader (a player), else the leader of its AI squad, else its first unit
SC_fnc_groupMenuShownLeader = {
    params ["_groupUnits"];

    private _leader = [_groupUnits] call SC_fnc_getGroupLeader;

    if (isNull _leader) then {
        _leader = _groupUnits select ((_groupUnits findIf {(alive _x) && {(leader (group _x)) isEqualTo _x}}) max 0);
    };

    _leader
};

// distance from the player to the nearest living unit of _units: "350 m", "1.2 km"; "" if there is none
SC_fnc_groupMenuDistanceText = {
    params ["_units"];

    private _distances = (_units select {(alive _x) && {simulationEnabled _x}}) apply {player distance _x};

    if (_distances isEqualTo []) exitWith {""};

    private _distance = selectMin _distances;

    if (_distance < 1000) exitWith {format ["%1 m", round _distance]};

    format ["%1 km", (round (_distance / 100)) / 10]
};

// value the player changed that the server's answer doesn't show yet (for up to 2 s), else the server's value
SC_fnc_groupMenuShownValue = {
    params ["_key", "_serverValue"];

    private _pending = SC_var_groupMenuPending getOrDefault [_key, []];

    if (_pending isEqualTo []) exitWith {_serverValue};

    _pending params ["_value", "_until"];

    if ((time > _until) || {_value isEqualTo _serverValue}) exitWith {
        SC_var_groupMenuPending deleteAt _key;
        _serverValue
    };

    _value
};

// rows are added or removed at the end only, so that the list keeps its scroll position
SC_fnc_groupMenuSetRowCount = {
    params ["_list", "_count"];

    private _rows = (lnbSize _list) select 0;

    for "_i" from _rows to (_count - 1) do {
        _list lnbAddRow ["", "", "", "", ""];
    };

    for "_i" from (_rows - 1) to _count step -1 do {
        _list lnbDeleteRow _i;
    };
};

SC_fnc_groupMenuSetRow = {
    params ["_list", "_row", "_texts", "_color"];

    {
        _list lnbSetText [[_row, _forEachIndex], _x];
        _list lnbSetColor [[_row, _forEachIndex], _color];
    } forEach _texts;
};

// groups: the own group, then the groups with a player as leader, then the AI groups, each by the leader's name
SC_fnc_groupMenuUpdateGroups = {
    params ["_display"];

    private _entries = [];
    private _keys = [];

    {
        _x params ["_targetSize", "_groupUnits"];

        private _leader = [_groupUnits] call SC_fnc_groupMenuShownLeader;

        _entries pushBack [_groupUnits, _targetSize, _leader];
        _keys pushBack [
            [1, 0] select (player in _groupUnits),
            [1, 0] select (([_leader] call SC_fnc_groupMenuIsPlayer)),
            toLowerANSI (_leader getVariable ["SC_var_name", name _leader]),
            _forEachIndex
        ];
    } forEach SC_var_groupMenuGroups;

    _keys sort true;
    SC_var_groupMenuRows = _keys apply {_entries select (_x select 3)};

    private _list = _display displayCtrl 1500;
    private _youColor = ["you"] call UI_fnc_color;

    [_list, count SC_var_groupMenuRows] call SC_fnc_groupMenuSetRowCount;

    {
        _x params ["_groupUnits", "_targetSize", "_leader"];

        private _isOwn = player in _groupUnits;
        ([_groupUnits] call SC_fnc_getGroupLocks) params ["_lockedForPlayers", "_lockedForAi"];
        private _lockText = ["", "Players", "AI", "Both"] select (([0, 1] select _lockedForPlayers) + ([0, 2] select _lockedForAi));

        [_list, _forEachIndex, [
            "",
            _leader getVariable ["SC_var_name", name _leader],
            format ["%1 / %2", count _groupUnits, [str _targetSize, "-"] select (_targetSize == -1)],
            _lockText,
            [_groupUnits - [player]] call SC_fnc_groupMenuDistanceText
        ], [[1, 1, 1, 1], _youColor] select _isOwn] call SC_fnc_groupMenuSetRow;

        _list lnbSetPicture [[_forEachIndex, 0], ["", SC_var_groupMenuOwnGroupIcon] select _isOwn];
        _list lnbSetPictureColor [[_forEachIndex, 0], _youColor];
        _list lnbSetPicture [[_forEachIndex, 3], ["", SC_var_groupMenuLockIcon] select (_lockText != "")];
    } forEach SC_var_groupMenuRows;

    // the selection stays on the group of the unit chosen last, else the own group
    private _selectedRow = SC_var_groupMenuRows findIf {SC_var_groupMenuSelected in (_x select 0)};

    if (_selectedRow == -1) then {
        _selectedRow = SC_var_groupMenuRows findIf {player in (_x select 0)};
        SC_var_groupMenuSelected = player;
    };

    if ((_selectedRow != -1) && {(lnbCurSelRow _list) != _selectedRow}) then {
        _list lnbSetCurSelRow _selectedRow;
    };
};

// [icon, status, icon / status color] of a member: dead (also a suspended AI, as in the group overview), unconscious,
// else its role and vehicle
SC_fnc_groupMenuMemberState = {
    params ["_unit"];

    if (!(alive _unit) || {!(simulationEnabled _unit)}) exitWith {
        [SC_var_groupMenuDeadIcon, "Dead", [1, 1, 1, 0.5]]
    };

    if (_unit getVariable ["ais_unconscious", false]) exitWith {
        if (_unit getVariable ["ais_stabilized", false]) then {
            [SC_var_groupMenuUnconsciousIcon, "Stabilized", ["warning"] call UI_fnc_color]
        } else {
            [SC_var_groupMenuUnconsciousIcon, "Unconscious", ["error"] call UI_fnc_color]
        }
    };

    private _vehicle = objectParent _unit;
    private _status = if (isNull _vehicle) then {"Alive"} else {[typeOf _vehicle] call SC_fnc_getDisplayName};
    private _list = (uiNamespace getVariable ["SC_var_groupMenuDialog", displayNull]) displayCtrl 1501;

    // cut to the status column (SC\dialogs.hpp, SC_Members columns[] 0.4749 - 0.8659 of the list width) so it never
    // runs into the distance
    if !(isNull _list) then {
        _status = [_status, 0.95 * (0.8659 - 0.4749) * ((ctrlPosition _list) select 2)] call UI_fnc_fitText;
    };

    [[_unit] call SC_fnc_getRoleIcon, _status, [1, 1, 1, 1]]
};

// members of the selected group: its leader, then the players, then the AI, each by name
SC_fnc_groupMenuUpdateMembers = {
    params ["_display"];

    private _selectedRow = SC_var_groupMenuRows findIf {SC_var_groupMenuSelected in (_x select 0)};
    private _members = [];

    if (_selectedRow != -1) then {
        (SC_var_groupMenuRows select _selectedRow) params ["_groupUnits", "", "_leader"];

        private _keys = [];

        {
            _keys pushBack [
                [1, 0] select (_x isEqualTo _leader),
                [1, 0] select (([_x] call SC_fnc_groupMenuIsPlayer)),
                toLowerANSI (_x getVariable ["SC_var_name", name _x]),
                _forEachIndex
            ];
        } forEach _groupUnits;

        _keys sort true;
        _members = _keys apply {_groupUnits select (_x select 3)};
    };

    SC_var_groupMenuMembers = _members;

    private _list = _display displayCtrl 1501;
    private _youColor = ["you"] call UI_fnc_color;

    [_list, count _members] call SC_fnc_groupMenuSetRowCount;

    {
        ([_x] call SC_fnc_groupMenuMemberState) params ["_icon", "_status", "_stateColor"];

        private _color = switch true do {
            case (_x isEqualTo player): {_youColor};
            case (!(alive _x) || {!(simulationEnabled _x)}): {[1, 1, 1, 0.5]};
            default {[1, 1, 1, 1]};
        };

        [_list, _forEachIndex, [
            "",
            str (_x getVariable ["SC_var_rank", 1]),
            _x getVariable ["SC_var_name", name _x],
            _status,
            [[_x] - [player]] call SC_fnc_groupMenuDistanceText
        ], _color] call SC_fnc_groupMenuSetRow;

        _list lnbSetColor [[_forEachIndex, 3], _stateColor];
        _list lnbSetPicture [[_forEachIndex, 0], _icon];
        _list lnbSetPictureColor [[_forEachIndex, 0], _stateColor];
    } forEach _members;

    private _memberRow = _members find SC_var_groupMenuSelectedMember;

    if (_memberRow == -1) then {
        SC_var_groupMenuSelectedMember = objNull;
    };

    if ((lnbCurSelRow _list) != _memberRow) then {
        _list lnbSetCurSelRow _memberRow;
    };
};

// Join (another group that is open for players), Leave (the own group has other members); Kick, size and locks show
// the selected group and can be changed by the leader of the own group
SC_fnc_groupMenuUpdateControls = {
    params ["_display"];

    private _selectedRow = SC_var_groupMenuRows findIf {SC_var_groupMenuSelected in (_x select 0)};
    private _groupUnits = [];
    private _targetSize = -1;

    if (_selectedRow != -1) then {
        (SC_var_groupMenuRows select _selectedRow) params ["_rowUnits", "_rowSize"];
        _groupUnits = _rowUnits;
        _targetSize = _rowSize;
    };

    private _isOwn = player in _groupUnits;
    private _locks = [_groupUnits] call SC_fnc_getGroupLocks;
    private _canAct =(alive player) && {[player] call SC_fnc_groupMenuCanManage} &&
        {!(player getVariable ["ais_unconscious", false])} && {time > SC_var_groupMenuBlockedUntil};
    private _isLeader = _canAct && {_isOwn} && {([_groupUnits] call SC_fnc_getGroupLeader) isEqualTo player};
    private _member = SC_var_groupMenuSelectedMember;

    if _isOwn then {
        _targetSize = ["size", _targetSize] call SC_fnc_groupMenuShownValue;
        _locks = [
            ["lock0", _locks select 0] call SC_fnc_groupMenuShownValue,
            ["lock1", _locks select 1] call SC_fnc_groupMenuShownValue
        ];
    };

    (_display displayCtrl 1600) ctrlEnable (_canAct && {_groupUnits isNotEqualTo []} && {!_isOwn} &&
        {!(_locks select 0)} && {[player, _groupUnits select 0] call SC_fnc_groupMenuCanJoin});
    (_display displayCtrl 1601) ctrlEnable (_canAct && {(count ([player] call SC_fnc_getGroupUnits)) > 1});
    (_display displayCtrl 1602) ctrlEnable (
        _isLeader &&
        {!(isNull _member)} &&
        {_member isNotEqualTo player} &&
        {!(([_member] call SC_fnc_groupMenuIsPlayer)) || {alive _member}}
    );

    // group size: the entries change with the number of players of the group
    private _combo = _display displayCtrl 2100;
    private _range = [_groupUnits] call SC_fnc_groupMenuSizeRange;
    _range params ["_minSize", "_maxSize"];

    if (SC_var_groupMenuSizeRange isNotEqualTo _range) then {
        SC_var_groupMenuSizeRange = _range;
        lbClear _combo;

        for "_size" from _minSize to _maxSize do {
            _combo lbSetValue [_combo lbAdd (str _size), _size];
        };
    };

    _combo lbSetCurSel ([-1, _targetSize - _minSize] select ((_targetSize >= _minSize) && {_targetSize <= _maxSize}));
    _combo ctrlEnable _isLeader;

    {
        (_display displayCtrl (2800 + _forEachIndex)) cbSetChecked _x;
        (_display displayCtrl (2800 + _forEachIndex)) ctrlEnable _isLeader;
    } forEach _locks;
};

// ---- client: controls ----

SC_fnc_groupMenuOnGroupSelected = {
    params ["", "_row"];

    if (SC_var_groupMenuUpdating || {_row < 0} || {_row >= (count SC_var_groupMenuRows)}) exitWith {};

    SC_var_groupMenuSelected = (SC_var_groupMenuRows select _row) select 2;
    SC_var_groupMenuSelectedMember = objNull;
    call SC_fnc_groupMenuUpdate;
};

SC_fnc_groupMenuOnMemberSelected = {
    params ["", "_row"];

    if (SC_var_groupMenuUpdating || {_row < 0} || {_row >= (count SC_var_groupMenuMembers)}) exitWith {};

    SC_var_groupMenuSelectedMember = SC_var_groupMenuMembers select _row;
    call SC_fnc_groupMenuUpdate;
};

SC_fnc_groupMenuOnSizeSelected = {
    params ["_combo", "_index"];

    if (SC_var_groupMenuUpdating || {_index < 0}) exitWith {};

    private _size = _combo lbValue _index;
    SC_var_groupMenuPending set ["size", [_size, time + 2]];
    [player, _size] remoteExecCall ["SC_fnc_groupMenuSetSizeServer", 2];
};

// _index 0: lock for players (checkbox 2800), 1: lock for AI (2801)
SC_fnc_groupMenuOnLockChanged = {
    params ["_index"];

    if SC_var_groupMenuUpdating exitWith {};

    private _locked = cbChecked ((uiNamespace getVariable ["SC_var_groupMenuDialog", displayNull]) displayCtrl (2800 + _index));
    SC_var_groupMenuPending set ["lock" + (str _index), [_locked, time + 2]];
    [player, _index, _locked] remoteExecCall ["SC_fnc_groupMenuSetLockServer", 2];
};

// the buttons wait a second for the server's answer
SC_fnc_groupMenuJoin = {
    private _row = SC_var_groupMenuRows findIf {SC_var_groupMenuSelected in (_x select 0)};

    if (_row == -1) exitWith {};

    SC_var_groupMenuBlockedUntil = time + 1;
    [player, (SC_var_groupMenuRows select _row) select 2] remoteExecCall ["SC_fnc_groupMenuJoinServer", 2];
    call SC_fnc_groupMenuUpdate;
};

SC_fnc_groupMenuLeave = {
    SC_var_groupMenuBlockedUntil = time + 1;
    [player] remoteExecCall ["SC_fnc_groupMenuLeaveServer", 2];
    call SC_fnc_groupMenuUpdate;
};

SC_fnc_groupMenuKick = {
    private _member = SC_var_groupMenuSelectedMember;

    if (isNull _member) exitWith {};

    SC_var_groupMenuBlockedUntil = time + 1;
    SC_var_groupMenuSelectedMember = objNull;
    [player, _member] remoteExecCall ["SC_fnc_groupMenuKickServer", 2];
    call SC_fnc_groupMenuUpdate;
};
