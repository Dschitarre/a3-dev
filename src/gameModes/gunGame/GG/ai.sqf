// GunGame AI (server): AI pool and AI players, keeping the number of alive units balanced (per team in team mode).

GG_var_aiPollInterval = 0.25;       // AI balance loop (scans all units)
GG_var_spawnSearchTimeout = 5;      // after this the first dry, open-sky spot in the zone is taken
GG_var_watcherUpdateInterval = 0.2; // spawn search: refresh of the units that could see a spawn
GG_var_minTravelRatio = 0.38;       // "far away" as a share of the zone size (spawns)
GG_var_aiMoveInterval = 1;          // AI move loop
GG_var_aiArrivalDistance = 10;      // an AI this close to its destination gets the next one
GG_var_aiRetargetInterval = 20;     // targets move: a new destination at least this often
GG_var_aiDestinationSpread = 25;    // destinations are random spots this close to the chosen target
GG_var_aiMaxOutsideDistance = 30;   // hard fallback: an AI this far from its last spot in the zone is put back there

/*
    The playable AI units wait in GG_var_suspendedUnits and are activated so that GG_var_wantedUnitAmount units are
    alive. The behaviour script of an active AI is its unit variable CMN_var_aiScript (stopped when it is parked).
*/

// AI-only setup of a pool unit, also of a unit a player left (undone by GG_fnc_initPlayer)
GG_fnc_initAiUnit = {
    params ["_unit"];

    _unit setVariable ["GG_var_lastSpawnPos", [0, 0, 0]];
    [_unit] call CMN_fnc_initAiUnit;

    // endless ammo, grenade refill and the end of the spawn protection; only for the AI (players: GG_fnc_setupPlayer)
    if ((_unit getVariable ["GG_var_firedEh", -1]) == -1) then {
        _unit setVariable ["GG_var_firedEh", _unit addEventHandler ["FiredMan", {
            params ["_unit"];

            if (!isPlayer _unit) then {
                _this call GG_fnc_firedMan;
            };
        }]];
    };
};

GG_fnc_suspendUnit = {
    params ["_unit"];

    [
        _unit,
        "GG_var_suspendedUnits",
        "GG_var_unitId",
        {params ["_unit"]; _unit in (entities [["CAManBase"], [], true, false])}
    ] call CMN_fnc_suspendUnit;
};

// "EntityRespawned" mission event handler
GG_fnc_entityRespawned = {
    params ["_newEntity", "_oldEntity"];

    [_newEntity] call GG_fnc_setRating;

    if (!isPlayer _newEntity) then {
        deleteVehicle _oldEntity;
        [_newEntity] call GG_fnc_suspendUnit;
    };
};

// units taking part: players (also dead or loading) and simulated living AI; parked pool units do not count
GG_fnc_activeUnits = {
    (entities [["CAManBase"], [], true, false]) select {isPlayer _x || {alive _x && {simulationEnabled _x}}}
};

// lowest stage of the active units except _unit, 0 if there are none
GG_fnc_lowestWeaponNum = {
    params ["_unit"];

    private _weaponNums = ((call GG_fnc_activeUnits) - [_unit]) apply {_x getVariable ["GG_var_weaponNum", 0]};

    if (_weaponNums isEqualTo []) exitWith {0};

    selectMin _weaponNums
};

// ---- balancing ----

// ai: 0 Auto (zone size), 1 Off, N >= 2 fill up to N units
GG_fnc_updateWantedUnitAmount = {
    GG_var_wantedUnitAmount = switch (GG_var_aiMode) do {
        case 0: {GG_var_maxUnits min round (1.25 * sqrt sqrt GG_var_mapArea)};
        case 1: {0};
        default {GG_var_maxUnits min GG_var_aiMode};
    };
};

// suspends surplus AI and spawns pool units while units are missing; pauses while a round end runs
GG_fnc_suspendAiLoop = {
    waitUntil {
        if (!GG_var_ended) then {
            {
                _x call GG_fnc_balanceAi;
            } forEach (call GG_fnc_aiTargets);
        };

        sleep GG_var_aiPollInterval;
        false
    };
};

/*
    [[team, wanted alive units], ...]: free for all one entry for everyone (team sideUnknown); team mode one per team,
    each with half the AI amount but at least as many as the team with the most players has players.
*/
GG_fnc_aiTargets = {
    if (!GG_var_teamMode) exitWith {[[sideUnknown, GG_var_wantedUnitAmount]]};

    private _perTeam = 0;

    if (GG_var_wantedUnitAmount > 0) then {
        private _playerCounts = GG_var_teamSides apply {
            private _side = _x;
            {([_x] call GG_fnc_teamOf) == _side} count (allPlayers select {!(_x isKindOf "HeadlessClient_F")})
        };

        _perTeam = ceil (GG_var_wantedUnitAmount / 2) max selectMax _playerCounts;
    };

    GG_var_teamSides apply {[_x, _perTeam]}
};

// parks surplus AI of _team (sideUnknown: everyone), preferably units no player can see; activates pool units for it
GG_fnc_balanceAi = {
    params ["_team", "_wantedAmount"];

    private _aliveUnits = (entities [["CAManBase"], [], true, true]) select {
        simulationEnabled _x && {_team == sideUnknown || {([_x] call GG_fnc_teamOf) == _team}}
    };
    private _unitCount = count _aliveUnits;

    if (_unitCount > _wantedAmount) exitWith {
        private _surplusAis = _aliveUnits select {!isPlayer _x && {local _x}};
        private _watchers = (allPlayers select {!(_x isKindOf "HeadlessClient_F")}) select {alive _x};
        private _hiddenAis = _surplusAis select {[getPosATL _x, _watchers] call GG_fnc_isHiddenFrom};

        {
            if (alive _x && {!isPlayer _x}) then {
                [_x] call GG_fnc_suspendUnit;
                sleep (1 / 3);
            };
        } forEach ((_hiddenAis + (_surplusAis - _hiddenAis)) select [0, _unitCount - _wantedAmount]);
    };

    for "_i" from _unitCount + 1 to _wantedAmount do {
        private _index = GG_var_suspendedUnits findIf {!isNull _x && {local _x} && {!isPlayer _x} && {!simulationEnabled _x}};
        if (_index == -1) exitWith {};

        private _spawnScript = [GG_var_suspendedUnits deleteAt _index, _team] spawn GG_fnc_spawnAi;

        waitUntil {
            sleep (1 / 3);
            scriptDone _spawnScript
        };
    };
};

// ---- AI players ----

/*
    Spawns a pool unit at a hidden spot with the weapon of its stage: free for all at least the lowest stage in the
    game (like a joining player), in team mode it joins _team and its stage.
*/
GG_fnc_spawnAi = {
    params ["_unit", ["_team", sideUnknown]];

    if (_team == sideUnknown) then {
        [_unit, (_unit getVariable ["GG_var_weaponNum", 0]) max ([_unit] call GG_fnc_lowestWeaponNum)] call GG_fnc_setWeaponNum;
    } else {
        [_unit, _team] call GG_fnc_joinTeam;
    };

    private _spawnPos = [_unit getVariable ["GG_var_lastSpawnPos", [0, 0, 0]], _unit] call GG_fnc_findSpawnPos;

    if (isPlayer _unit) exitWith {};

    _unit setVariable ["GG_var_lastSpawnPos", _spawnPos];
    _unit setPos _spawnPos;
    _unit setDamage 0;
    [_unit] call GG_fnc_applyWeapon;
    [_unit] call GG_fnc_startSpawnProtection;
    _unit enableSimulationGlobal true;
    _unit addPlayerScores [0, 0, 0, 0, 0];
    _unit setSkill ([_unit] call CMN_fnc_aiSkill);
    (group _unit) setCombatBehaviour "COMBAT";
    _unit setCombatBehaviour "COMBAT";
    (group _unit) setCombatMode "RED";
    _unit setUnitCombatMode "RED";
    _unit enableAI "ALL";

    // ended up under a roof after all: back into the pool
    if (!([getPosATL _unit] call CMN_fnc_isUnderOpenSky)) exitWith {
        [_unit] call GG_fnc_suspendUnit;
    };

    _unit setVariable ["CMN_var_aiScript", [_unit] spawn GG_fnc_aiMoveLoop];
};

/*
    Walks towards known enemies or enemy players until the unit dies, is parked or a player takes it over. At the zone
    border it gets a new destination inside and turns around; only a unit far outside is put back.
*/
GG_fnc_aiMoveLoop = {
    params ["_unit"];

    private _destination = [];
    private _lastOrder = 0;
    private _lastInsidePos = getPosATL _unit;

    waitUntil {
        sleep GG_var_aiMoveInterval;

        if (isNull _unit || {isPlayer _unit} || {!alive _unit} || {!simulationEnabled _unit}) exitWith {true};

        private _isInside = _unit inArea "GG_var_playZone";

        if (_isInside) then {
            _lastInsidePos = getPosATL _unit;
        } else {
            if (_unit distance2D _lastInsidePos > GG_var_aiMaxOutsideDistance) then {
                _unit setPosATL _lastInsidePos;
            };
        };

        private _sinceOrder = time - _lastOrder;

        if (
            _destination isEqualTo [] ||
            {_sinceOrder >= GG_var_aiRetargetInterval} ||
            {_unit distance2D _destination < GG_var_aiArrivalDistance} ||
            {_sinceOrder >= 3 && {!_isInside || {unitReady _unit}}}
        ) then {
            _destination = [_unit] call GG_fnc_aiDestination;
            [_unit, _destination] remoteExecCall ["doMove", groupOwner (group _unit)];
            _lastOrder = time;
        };

        false
    };
};

// a spot near the nearest known enemy, otherwise near a random enemy player, otherwise anywhere in the zone
GG_fnc_aiDestination = {
    params ["_unit"];

    private _target = _unit findNearestEnemy _unit;

    if (isNull _target) then {
        private _team = [_unit] call GG_fnc_teamOf;
        private _players = (allPlayers select {!(_x isKindOf "HeadlessClient_F")}) select {
            alive _x &&
            {simulationEnabled _x} &&
            {_x inArea "GG_var_playZone"} &&
            {_team == sideUnknown || {([_x] call GG_fnc_teamOf) != _team}}
        };

        if (_players isNotEqualTo []) then {
            _target = selectRandom _players;
        };
    };

    if (isNull _target) exitWith {"GG_var_playZone" call BIS_fnc_randomPosTrigger};

    private _targetPos = getPosATL _target;
    private _destination = _targetPos getPos [random GG_var_aiDestinationSpread, random 360];

    [_targetPos, _destination] select (_destination inArea "GG_var_playZone")
};
