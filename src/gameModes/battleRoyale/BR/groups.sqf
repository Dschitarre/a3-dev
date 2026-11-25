// BR adapter for the shared U menu. Teams are virtual; only their real players share an engine group.

call compile preprocessFileLineNumbers "ui\groupMenu.sqf";
BR_fnc_isTeamPlayer = {
    params ["_unit"];

    isPlayer _unit
};

SC_fnc_groupMenuIsPlayer = {_this call BR_fnc_isTeamPlayer};

SC_fnc_groupMenuCanManage = {
    BR_var_teamSize > 1 && {BR_var_state == "warmup"} && {!(missionNamespace getVariable ["BR_var_groupsLocked", false])}
};

SC_fnc_getGroupUnits = {
    params ["_unit"];

    if (isNull _unit) exitWith {[]};

    if (!isServer) exitWith {_unit getVariable ["SC_var_groupUnits", [_unit]]};

    private _id = _unit getVariable ["BR_var_teamId", -1];
    if (BR_var_state != "warmup" && {!isNil "BR_var_teamRoster"}) exitWith {[_id] call BR_fnc_teamUnits};

    BR_var_slotUnits select {!isNull _x && {(_x getVariable ["BR_var_teamId", -2]) == _id} && {BR_var_aiFill || {[_x] call BR_fnc_isTeamPlayer}}}
};

SC_fnc_getGroupTargetSize = {
    params ["_unit"];

    private _leader = [[_unit] call SC_fnc_getGroupUnits] call SC_fnc_getGroupLeader;
    if (isNull _leader) exitWith {BR_var_teamSize};

    1 max (BR_var_teamSize min (_leader getVariable ["SC_var_groupTargetSize", BR_var_teamSize]))
};

SC_fnc_setGroupTargetSize = {
    params ["_units", "_size"];

    _size = 1 max (BR_var_teamSize min round _size);
    {_x setVariable ["SC_var_groupTargetSize", _size, true]} forEach _units;
};

SC_fnc_getSidesUnits = {BR_var_slotUnits select {!isNull _x && {BR_var_aiFill || {[_x] call BR_fnc_isTeamPlayer}}}};

SC_fnc_publishGroupUnits = {
    params ["_unit"];

    private _units = [_unit] call SC_fnc_getGroupUnits;
    {if ((_x getVariable ["SC_var_groupUnits", []]) isNotEqualTo _units) then {_x setVariable ["SC_var_groupUnits", _units, true]}} forEach _units;
};

SC_fnc_notifyPlayers = {
    params ["_template", "_arguments", "_units"];

    {if ([_x] call BR_fnc_isTeamPlayer) then {[_template, _arguments] remoteExecCall ["BIS_fnc_showNotification", _x]}} forEach _units
};

SC_fnc_getDisplayName = {
    params ["_type"];

    getText (configFile >> "CfgVehicles" >> _type >> "displayName")
};

SC_fnc_getRoleIcon = {"\A3\ui_f\data\map\vehicleicons\iconMan_ca.paa"};

BR_fnc_freeTeamId = {
    private _ids = BR_var_slotUnits apply {_x getVariable ["BR_var_teamId", -1]};
    private _id = 0;
    while {_id in _ids} do {_id = _id + 1};
    _id
};

SC_fnc_removeFromGroup = {
    params ["_unit"];

    if (!(call SC_fnc_groupMenuCanManage)) exitWith {};

    private _old = _unit getVariable ["BR_var_teamId", -1];
    if (!([_unit] call BR_fnc_isTeamPlayer)) then {_unit setVariable ["BR_var_avoidTeam", _old]};
    _unit setVariable ["BR_var_teamId", call BR_fnc_freeTeamId, true];
    _unit setVariable ["SC_var_groupTargetSize", BR_var_teamSize, true];
    [_unit] call SC_fnc_publishGroupUnits;
    {if ((_x getVariable ["BR_var_teamId", -1]) == _old) then {[_x] call SC_fnc_publishGroupUnits}} forEach BR_var_slotUnits;
};

SC_fnc_groupMenuCanJoin = {
    params ["_player", "_target"];

    if (!(call SC_fnc_groupMenuCanManage) || {isNull _target} || {_player == _target}) exitWith {false};

    if ((_player getVariable ["BR_var_slotId", -1]) < 0 || {(_target getVariable ["BR_var_teamId", -1]) < 0}) exitWith {false};

    if (isServer && {!(_player in BR_var_slotUnits) || {!(_target in BR_var_slotUnits)}}) exitWith {false};

    if ([_target] call SC_fnc_isGroupLockedForPlayers) exitWith {false};

    private _units = [_target] call SC_fnc_getGroupUnits;
    !(_player in _units) && {({[_x] call BR_fnc_isTeamPlayer} count _units) < BR_var_teamSize}
};

SC_fnc_switchGroup = {
    params ["_unit", "_target"];

    if (!([_unit, _target] call SC_fnc_groupMenuCanJoin)) exitWith {};

    _unit setVariable ["BR_var_teamId", _target getVariable "BR_var_teamId", true];
};

// Refill customized player teams first, then form the remaining AI into full teams of the configured size.
BR_fnc_balanceGroups = {
    if (BR_var_state != "warmup" || {!isNil "BR_var_teamRoster"}) exitWith {};

    private _pool = BR_var_slotUnits select {!isNull _x};
    SC_var_squadMaxSize = BR_var_teamSize;
    SC_var_squadSize = BR_var_teamSize;
    private _players = _pool select {[_x] call BR_fnc_isTeamPlayer};
    private _ids = [];
    {_ids pushBackUnique (_x getVariable "BR_var_teamId")} forEach _players;

    {
        private _id = _x;
        private _members = _pool select {(_x getVariable ["BR_var_teamId", -1]) == _id};
        private _humans = _members select {[_x] call BR_fnc_isTeamPlayer};
        [_humans] call SC_fnc_updateGroupLeaderFlag;
        private _leader = [_humans] call SC_fnc_getGroupLeader;
        private _size = (([_leader] call SC_fnc_getGroupTargetSize) max count _humans) min BR_var_teamSize;
        private _ai = _members - _humans;
        private _keep = if (BR_var_aiFill) then {(_size - count _humans) max 0} else {0};
        {_x setVariable ["BR_var_teamId", -1, true]} forEach (_ai select [_keep]);
    } forEach _ids;

    private _free = _pool select {!([_x] call BR_fnc_isTeamPlayer) && {!((_x getVariable ["BR_var_teamId", -1]) in _ids)}};

    if (BR_var_aiFill) then {
        {
            private _id = _x;
            private _leader = (_players select {(_x getVariable "BR_var_teamId") == _id}) select 0;
            private _members = [_leader] call SC_fnc_getGroupUnits;
            private _size = [_leader] call SC_fnc_getGroupTargetSize;

            if (!([_leader] call SC_fnc_isGroupLockedForAi)) then {
                while {count _members < _size} do {
                    private _index = _free findIf {(_x getVariable ["BR_var_avoidTeam", -2]) != _id};
                    if (_index < 0) exitWith {};

                    private _unit = _free deleteAt _index;
                    _unit setVariable ["BR_var_teamId", _id, true];
                    _members pushBack _unit;
                };
            };
        } forEach _ids;
    };

    private _id = 0;
    private _count = 0;

    {
        if (_count == 0) then {while {_id in _ids} do {_id = _id + 1}};
        if ((_x getVariable ["BR_var_teamId", -1]) != _id) then {_x setVariable ["BR_var_teamId", _id, true]};
        _count = _count + 1;

        if (_count == BR_var_teamSize) then {
            _count = 0;
            _id = _id + 1
        };
    } forEach _free;

    private _allIds = [];
    {_allIds pushBackUnique (_x getVariable "BR_var_teamId")} forEach _pool;
    BR_var_teamCount = 1 + selectMax _allIds;
    BR_var_aiTeamOrder = (BR_var_aiTeamOrder arrayIntersect _allIds) + (_allIds - BR_var_aiTeamOrder);

    {
        private _group = [_x getVariable "BR_var_teamId"] call BR_fnc_teamPlayerGroup;
        if (group _x != _group) then {[_x] joinSilent _group};
    } forEach _players;

    private _published = [];
    {private _id = _x getVariable "BR_var_teamId";
        if (!(_id in _published)) then {
            _published pushBack _id;
            [_x] call SC_fnc_publishGroupUnits
        }} forEach _pool;
};

BR_fnc_assignJoiningGroup = {
    params ["_player"];

    if (!(call SC_fnc_groupMenuCanManage)) exitWith {};

    _player setVariable ["SC_var_isGroupLeader", false, true];
    _player setVariable ["SC_var_groupLocks", nil, true];
    _player setVariable ["SC_var_groupCustom", nil];
    private _own = ([_player] call SC_fnc_getGroupUnits)-[_player];
    if ((_own findIf {[_x] call BR_fnc_isTeamPlayer}) >= 0 && {!([_own] call SC_fnc_isGroupLockedForPlayers)}) exitWith {};

    if ((_own findIf {[_x] call BR_fnc_isTeamPlayer}) >= 0) then {[_player] call SC_fnc_removeFromGroup};

    private _possible = BR_var_slotUnits select {
        _x != _player && {[_x] call BR_fnc_isTeamPlayer} &&
            {!(_x getVariable ["SC_var_groupCustom", false])} &&
            {!([_x] call SC_fnc_isGroupLockedForPlayers)} && {
            private _members = [_x] call SC_fnc_getGroupUnits;
            ({[_x] call BR_fnc_isTeamPlayer} count _members) < ([_x] call SC_fnc_getGroupTargetSize)
        }
    };

    if (_possible isNotEqualTo []) then {
        private _target = selectRandom _possible;
        [_player, _target] call SC_fnc_switchGroup;
        _player setVariable ["SC_var_groupLocks", [_target] call SC_fnc_getGroupLocks, true];
        _player setVariable ["SC_var_groupTargetSize", [_target] call SC_fnc_getGroupTargetSize, true];
    };
};

BR_var_scGroupMenuData = SC_fnc_groupMenuDataServer;
SC_fnc_groupMenuDataServer = {
    params ["_player"];

    if (!([_player] call SC_fnc_groupMenuIsSender)) exitWith {};

    if (BR_var_state == "warmup") exitWith {_this call BR_var_scGroupMenuData};

    [[[[ _player] call SC_fnc_getGroupTargetSize, [_player] call SC_fnc_getGroupUnits]]] remoteExecCall ["SC_fnc_groupMenuReceiveData", _player];
};

BR_fnc_initGroupsClient = {
    SC_var_squadMaxSize = BR_var_teamSize;
    SC_var_squadSize = BR_var_teamSize;
    if (BR_var_teamSize <= 1 || {!isNil "BR_var_groupMenuKeys"}) exitWith {};

    BR_var_groupMenuKeys = true;

    (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["", "_key", "", "_ctrl"];

        [_key, _ctrl] call SC_fnc_groupMenuIsKey
    }];

    (findDisplay 46) displayAddEventHandler ["KeyUp", {_this call SC_fnc_groupMenuMainKeyUp}];
};
