// AI fill and suspension: pool of suspended (hidden, inactive) AI units; the AI of every side are suspended or
// brought back so that players and AI fill the sides evenly (server).

// pool of suspended playable AI units per side, sorted by unit id; modified in place so references stay valid
SC_fnc_addSuspendedUnit = {
    params ["_unit", "_side"];

    isNil {
        private _suspendedUnits = missionNamespace getVariable [("SC_var_suspendedUnits" + (str _side)), []];
        [_suspendedUnits] call SC_fnc_removeNullsInPlace;
        _suspendedUnits pushBackUnique _unit;

        private _sorted = [_suspendedUnits, [], {_x getVariable "SC_var_unitId"}, "ASCEND"] call BIS_fnc_sortBy;
        _suspendedUnits resize 0;
        _suspendedUnits append _sorted;
    };
};

// Takes an AI unit out of the game into the pool (hidden at [0, 0, 10], no simulation); dead bodies are deleted.
// It leaves its squad (an AI squad keeps its vehicle), _reason is for the AI debug log.
SC_fnc_suspendUnit = {
    params ["_unit", ["_reason", ""]];

    if (isPlayer _unit) exitWith {};

    ["suspend", group _unit, _reason, name _unit, alive _unit] call SC_fnc_aiLog;

    unassignVehicle _unit;
    [_unit] call SC_fnc_leaveSquad;
    [_unit] call SC_fnc_deregisterEntityServer;

    [_unit] spawn {
        params ["_unit"];

        waitUntil {
            if (
                [_unit] call {
                    params ["_unit"];

                    if (isNull _unit) exitWith {false};
                    _unit setPos [0, 0, 10];

                    if ((_unit distance [0, 0, 0]) > 100) then {
                        true
                    } else {
                        while {simulationEnabled _unit} do {
                            _unit enableSimulationGlobal false;
                        };
                        _unit hideObjectGlobal true;

                        // dead bodies never go into the pool (a playable unit comes back via respawn)
                        if ((alive _unit) && {_unit in playableUnits}) then {
                            [_unit, side (group _unit)] call SC_fnc_addSuspendedUnit;
                        } else {
                            [_unit] call SC_fnc_removeFromGroup;
                            [_unit] remoteExecCall ["deleteVehicle", _unit];
                        };
                        false
                    }
                }
            ) then {
                sleep 1;
                false
            } else {
                true
            }
        };
    };
};

// ---- AI fill ----

// Every side is filled with AI up to the same target strength: SC_var_wantedUnitAmount, or the largest player count
// of a side (plus SC_var_aiFillPlayerBuffer) if that is higher, at most the playable slots of the side. Connected
// players (also dead ones) take the place of AI, so AI leave when players join and come back when players leave.
SC_var_aiFillPlayerBuffer = 0;

// AI of a side brought back per pass of the fill loop (SC_fnc_activateSuspendedAi starts them together): 1, so only one
// unit spawns at a time and the sides take turns. Several parallel spawns starved the AI planning, which shares the
// scheduler (squads stood until the fill ended), and their unscheduled unit setups in the same frame made the server
// FPS jump; one spawn is fast since the unit setup runs in one go (SC_fnc_spawnAi).
SC_var_aiActivationBatch = 1;

// pause (s) after a side's pass of the fill loop
SC_var_aiFillSidePause = 0.1;

// server FPS below which the fill waits (the AI planning gets the time)
SC_var_aiFillMinFps = 20;

// number of connected players per side (order of SC_var_sides)
SC_fnc_getPlayerCounts = {
    // a dead player's group can already be gone; his side is still known from the unit registry
    private _playerSides = (allPlayers select {!(_x isKindOf "HeadlessClient_F")}) apply {
        private _group = group _x;

        if (isNull _group) then {_x getVariable ["SC_var_side", sideUnknown]} else {side _group}
    };

    SC_var_sides apply {
        private _side = _x;

        {_x == _side} count _playerSides
    }
};

// number of active AI wanted per side (order of SC_var_sides)
SC_fnc_getWantedAiAmounts = {
    private _playerCounts = call SC_fnc_getPlayerCounts;
    private _targetStrength = SC_var_wantedUnitAmount max ((selectMax _playerCounts) + SC_var_aiFillPlayerBuffer);
    private _wantedAiAmounts = [];

    {
        // playableSlotsNumber is 0 outside of multiplayer
        private _slots = playableSlotsNumber _x;
        private _sidesTargetStrength = [_targetStrength, (_targetStrength min _slots)] select (_slots > 0);

        _wantedAiAmounts pushBack (0 max (_sidesTargetStrength - (_playerCounts select _forEachIndex)));
    } forEach SC_var_sides;

    _wantedAiAmounts
};

// suspends _amount active AI of a side: first AI that no player sees and that are neither in a group with players nor
// in a vehicle, AI in a group with players last
SC_fnc_suspendSurplusAi = {
    params ["_side", "_amount"];

    private _isActiveAi = {!(isPlayer _this) && {alive _this} && {simulationEnabled _this}};
    private _candidates = ([_side] call SC_fnc_getSidesUnits) select {_x call _isActiveAi};
    private _priorities = _candidates apply {
        ([0, 4] select ((([_x] call SC_fnc_getGroupUnits) findIf {isPlayer _x}) != -1)) +
        ([0, 2] select ([_x, SC_var_aiSeenDistance] call SC_fnc_aiIsSeenByPlayers)) +
        ([0, 1] select !(isNull (objectParent _x)))
    };

    for "_i" from 1 to _amount do {
        if (_candidates isEqualTo []) exitWith {};

        private _idx = _priorities find (selectMin _priorities);
        private _unit = _candidates deleteAt _idx;
        _priorities deleteAt _idx;

        // the unit can have been taken over by a player or have died since the candidates were chosen
        if (_unit call _isActiveAi) then {
            [_unit, "surplus"] call SC_fnc_suspendUnit;
            sleep (1/3);
        };
    };
};

// brings _amount suspended AI of a side back into the game, units of a group with players first
SC_fnc_activateSuspendedAi = {
    params ["_side", "_amount"];

    private _suspendedUnits = missionNamespace getVariable [("SC_var_suspendedUnits" + (str _side)), []];
    private _isSuspended = {!(isNull _this) && {!(isPlayer _this)} && {local _this} && {!(simulationEnabled _this)}};

    // the units spawn at the same time (their spawn positions are found one after the other, SC_fnc_spawnAi); a unit
    // stays suspended until its spawn enables it, so the ones picked in this pass are skipped
    private _picked = [];
    private _handles = [];

    for "_i" from 1 to _amount do {
        private _pos = _suspendedUnits findIf {!(_x in _picked) && {_x call _isSuspended} &&
            {(([_x] call SC_fnc_getGroupUnits) findIf {isPlayer _x}) != -1}};

        if (_pos == -1) then {
            _pos = _suspendedUnits findIf {!(_x in _picked) && {_x call _isSuspended}};
        };

        if (_pos == -1) exitWith {};

        private _unit = _suspendedUnits select _pos;

        _picked pushBack _unit;

        // the unit stays in the pool (sorted by unit id), active units are skipped via simulationEnabled
        [_unit, _side] call SC_fnc_addSuspendedUnit;
        _handles pushBack ([_unit] spawn SC_fnc_spawnAi);
    };

    waitUntil {
        sleep 0.1;
        (_handles findIf {!(scriptDone _x)}) == -1
    };
};

SC_fnc_suspendAiLoop = {
    // spawning uses the AI distances and the sector picture of SC_fnc_aiLoop
    waitUntil {sleep 0.5; !(isNil "SC_var_aiSectorInfo")};

    waitUntil {
        private _wantedAiAmounts = call SC_fnc_getWantedAiAmounts;

        {
            private _side = _x;
            private _wantedAiAmount = _wantedAiAmounts select _forEachIndex;
            private _numActiveAi = {!(isPlayer _x) && {alive _x}} count ([_side] call SC_fnc_getSidesUnits);

            if (_numActiveAi > _wantedAiAmount) then {
                [_side, (_numActiveAi - _wantedAiAmount)] call SC_fnc_suspendSurplusAi;
            };

            // the sides take turns, so that they fill up at the same pace; nothing while the server is slow
            if ((_numActiveAi < _wantedAiAmount) && {diag_fps >= SC_var_aiFillMinFps}) then {
                [_side, ((_wantedAiAmount - _numActiveAi) min SC_var_aiActivationBatch)] call SC_fnc_activateSuspendedAi;
            };

            sleep SC_var_aiFillSidePause;
        } forEach SC_var_sides;

        false
    };
};
