// Team Deathmatch AI (server): AI pool, filling the teams with AI players, suspending unused AI, AI movement.

DM_var_aiMagazines = 9;             // magazines an AI gets for its primary weapon (handgun: DM_var_aiHandgunMagazines)
DM_var_aiHandgunMagazines = 3;
DM_var_aiBalanceInterval = 1;       // AI balance loop before a round
DM_var_aiMoveInterval = 0.5;        // AI move loop
DM_var_aiArrivalDistance = 5;       // an AI this close to its destination gets the next one
DM_var_aiReorderDelay = 3;          // minimum time between two move orders of an AI
DM_var_aiEngageDistance = 150;      // an AI that knows an enemy this close keeps fighting instead of walking on

/*
    The playable AI units wait in the pools DM_var_suspendedUnitsWest/East and are activated to balance the teams.
    The behaviour script of an active AI is its unit variable CMN_var_aiScript (stopped when the unit is parked).
*/

DM_fnc_suspendUnit = {
    params ["_unit"];

    [
        _unit,
        "DM_var_suspendedUnits" + str (side group _unit),
        "DM_var_unitId",
        {params ["_unit"]; _unit in playableUnits},
        true
    ] call CMN_fnc_suspendUnit;
};

// "EntityRespawned" mission event handler
DM_fnc_entityRespawned = {
    params ["_newEntity"];

    if (_newEntity isKindOf "CAManBase" && {!isPlayer _newEntity}) then {
        [_newEntity] call DM_fnc_suspendUnit;
    };
};

// ---- balancing ----

// one balance loop at a time; it runs before a round (warmup, preparation and equip phase), AI gear of _relRoundNumber
DM_fnc_startAiBalance = {
    params ["_relRoundNumber"];

    call DM_fnc_stopAiBalance;
    DM_var_aiBalanceHdl = [_relRoundNumber] spawn DM_fnc_aiBalanceLoop;
};

DM_fnc_stopAiBalance = {
    if (!scriptDone DM_var_aiBalanceHdl) then {
        terminate DM_var_aiBalanceHdl;
    };
};

DM_fnc_aiBalanceLoop = {
    params ["_relRoundNumber"];

    waitUntil {
        // its own script: stopping the loop must not interrupt a unit between pool and activation
        private _balanceScript = [_relRoundNumber] spawn DM_fnc_balanceAi;
        waitUntil {scriptDone _balanceScript};
        sleep DM_var_aiBalanceInterval;
        false
    };
};

/*
    Activates or suspends AI so that each side has the wanted number of units: the ai param, but at least as many as
    the side with the most players has players, so the other side is filled up with AI. _fightersOnly (round start):
    only players who take part in the round count, not the ones still loading or spectating. New AI get the gear of
    _relRoundNumber (everything with unrestricted loadouts).
*/
DM_fnc_balanceAi = {
    params ["_relRoundNumber", ["_fightersOnly", false]];

    private _gearRelRoundNumber = [DM_var_maxRelRoundNumber, _relRoundNumber] select DM_var_loadoutsRestricted;
    private _sidesPlayers = [west, east] apply {
        private _side = _x;

        (allPlayers select {!(_x isKindOf "HeadlessClient_F")}) select {
            side (group _x) == _side &&
            {!_fightersOnly || {alive _x && {simulationEnabled _x} && {!(_x getVariable ["CMN_var_isLoading", false])}}}
        }
    };
    private _sidesAIs = [west, east] apply {([_x] call DM_fnc_unitsOfSide) select {!isPlayer _x}};

    // ai: 0 Fill to equalize unit count, 1 Fill to Map Size, 2..8 Fill upto N
    private _paramAmount = switch (DM_var_aiMode) do {
        case 0: {1};
        case 1: {8 min (1 max round (1.1 * (DM_var_zoneSize / 20000) ^ 0.93))};
        default {DM_var_aiMode};
    };
    private _wantedAmount = _paramAmount max selectMax (_sidesPlayers apply {count _x});

    {
        private _side = _x;
        private _sideAIs = _sidesAIs select _forEachIndex;
        private _poolVarName = "DM_var_suspendedUnits" + str _side;
        private _pool = missionNamespace getVariable _poolVarName;

        // on their way from the pool to the HQ (DM_fnc_aiPlayer): not simulated yet, but already part of the team
        private _activatingCount = {
            !isPlayer _x && {alive _x} && {!simulationEnabled _x} && {!(_x in _pool)}
        } count (playableUnits select {side (group _x) == _side});

        private _diff = _wantedAmount - (count (_sidesPlayers select _forEachIndex) + count _sideAIs + _activatingCount);

        for "_i" from 1 to _diff do {
            private _suspendedUnits = missionNamespace getVariable _poolVarName;
            private _unitIndex = _suspendedUnits findIf {!isNull _x && {!isPlayer _x}};
            if (_unitIndex == -1) exitWith {};

            private _unit = _suspendedUnits deleteAt _unitIndex;
            _unit setVariable ["CMN_var_aiScript", [_unit, _side, _gearRelRoundNumber] spawn DM_fnc_aiPlayer];
        };

        for "_i" from 1 to -_diff do {
            private _candidates = _sideAIs select {!isNull _x && {local _x}};
            if (_candidates isEqualTo []) exitWith {};

            private _unit = selectRandom _candidates;
            _sideAIs deleteAt (_sideAIs find _unit);
            [_unit] call DM_fnc_suspendUnit;
        };
    } forEach [west, east];
};

// start of a round: every active AI goes back into its pool
DM_fnc_despawnAi = {
    {
        [_x] call DM_fnc_suspendUnit;
    } forEach ((entities [["CAManBase"], [], true, false]) select {simulationEnabled _x && {!isPlayer _x} && {local _x}});
};

/*
    A JIP player took over a fighting AI during a round (he spectates until the next round): a pool unit of the side
    takes over the AI's position, gear and health, so the team keeps its strength. _state: see DM_fnc_initPlayerServer.
*/
DM_fnc_replaceAi = {
    params ["_side", "_state"];

    _state params ["_posATL", "_dir", "_loadout", "_damage", "_vehicle"];

    private _suspendedUnits = missionNamespace getVariable ["DM_var_suspendedUnits" + str _side, []];
    private _unitIndex = _suspendedUnits findIf {!isNull _x && {!isPlayer _x}};
    if (_unitIndex == -1) exitWith {};

    private _unit = _suspendedUnits deleteAt _unitIndex;

    _unit enableSimulationGlobal true;
    _unit setUnitLoadout _loadout;
    _unit setDamage _damage;
    _unit setDir _dir;
    _unit setPosATL _posATL;

    if (!isNull _vehicle && {alive _vehicle}) then {
        _unit moveInAny _vehicle;
    };

    _unit addPlayerScores [0, 0, 0, 0, 0];
    _unit setSkill ([_unit] call CMN_fnc_aiSkill);
    [_unit, true] call ADG_fnc_allowDamage;
    _unit setVariable ["CMN_var_aiScript", [_unit] spawn DM_fnc_aiFight];
};

// ---- AI players ----

// spawns a pool unit at its HQ with the gear of the round and lets it fight once the round runs
DM_fnc_aiPlayer = {
    params ["_unit", "_side", "_relRoundNumber"];

    if (isNull _unit || {isPlayer _unit}) exitWith {};

    _unit disableAI "ALL";
    _unit addPlayerScores [0, 0, 0, 0, 0];
    _unit setSkill ([_unit] call CMN_fnc_aiSkill);
    _unit setDamage 0;      // zone damage or wounds from before it was parked
    [_unit, false] call ADG_fnc_allowDamage;

    private _spawnPos = [getMarkerPos ([_side] call DM_fnc_hqMarker), "B_Soldier_F", 2] call DM_fnc_findSpawnPos;

    // a player may take the unit over (or it may be deleted) while this script waits
    if (isNull _unit || {isPlayer _unit}) exitWith {};

    _unit enableSimulationGlobal true;
    _unit setPos _spawnPos;
    [_unit, _side, _relRoundNumber] call DM_fnc_equipAi;

    if (isNull _unit || {isPlayer _unit}) exitWith {};

    waitUntil {alive _unit || {isNull _unit}};

    // spawn protection until 3 s after spawning and the round has started
    [_unit] spawn {
        params ["_unit"];

        sleep 3;
        waitUntil {DM_var_movingEnabled};

        if (!isNull _unit) then {
            [_unit, true] call ADG_fnc_allowDamage;
        };
    };

    waitUntil {DM_var_movingEnabled};

    [_unit] call DM_fnc_aiFight;
};

// combat settings, then the AI walks through the zone until it dies, is parked or a player takes it over
DM_fnc_aiFight = {
    params ["_unit"];

    if (isNull _unit || {isPlayer _unit}) exitWith {};

    (group _unit) setCombatBehaviour "COMBAT";
    _unit setCombatBehaviour "COMBAT";
    (group _unit) setCombatMode "RED";
    _unit setUnitCombatMode "RED";
    _unit enableAI "ALL";

    [_unit] call DM_fnc_aiMoveLoop;
};

// random gear of the round: side uniform, vest, backpack, helmet, NVG, primary weapon with optic, maybe a handgun
DM_fnc_equipAi = {
    params ["_unit", "_side", "_relRoundNumber"];

    ([_relRoundNumber] call DM_fnc_calculateItems) params ["_weapons", "_items", "", "_backpacks"];

    removeUniform _unit;
    removeVest _unit;
    removeBackpack _unit;
    removeHeadgear _unit;
    removeGoggles _unit;
    _unit removeItem (binocular _unit);
    private _oldNvg = hmd _unit;
    _unit unassignItem _oldNvg;
    _unit removeItem _oldNvg;

    private _uniformPrefix = ["U_B_", "U_O_"] select (_side == east);

    _unit forceAddUniform selectRandom (_items select {_x find "Wetsuit" == -1 && {_x select [0, 4] == _uniformPrefix}});
    _unit addVest selectRandom (_items select {(_x find "vest" != -1 || {_x select [0, 2] == "V_"}) && {_x find "Rebreather" == -1}});
    _unit addBackpack selectRandom _backpacks;
    _unit addHeadgear selectRandom (_items select {_x find "helmet" != -1 || {_x select [0, 2] == "H_"}});

    if (isPlayer _unit) exitWith {};

    [_unit, _relRoundNumber] call DM_fnc_addMedicalItems;

    private _nvg = selectRandom (_items select {_x find "NVGoggles" != -1});
    _unit addItem _nvg;
    _unit assignItem _nvg;

    removeAllWeapons _unit;

    private _primaryWeapon = selectRandom (_weapons select {(_x call BIS_fnc_itemType) select 1 != "Handgun"});
    [_unit, _primaryWeapon, DM_var_aiMagazines] call DM_fnc_addWeaponWithMagazines;
    _unit addPrimaryWeaponItem selectRandom (_items select {_x select [0, 6] == "optic_" || {_x find "_o_" != -1}});

    private _handguns = _weapons select {(_x call BIS_fnc_itemType) select 1 == "Handgun"};

    if (_handguns isNotEqualTo []) then {
        [_unit, selectRandom _handguns, DM_var_aiHandgunMagazines] call DM_fnc_addWeaponWithMagazines;
    };
};

// random compatible magazines first, so the weapon is loaded
DM_fnc_addWeaponWithMagazines = {
    params ["_unit", "_weapon", "_magazineCount"];

    private _magazines = getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines");

    for "_i" from 1 to _magazineCount do {
        _unit addMagazine selectRandom _magazines;
    };

    _unit addWeapon _weapon;
};

/*
    Walks between random free spots in the zone until the unit dies, is parked or a player takes it over. While it
    knows an enemy nearby it gets no new order, so it fights instead of running on.
*/
DM_fnc_aiMoveLoop = {
    params ["_unit"];

    private _destination = [0, 0];
    private _lastOrder = 0;

    waitUntil {
        sleep DM_var_aiMoveInterval;

        if (isNull _unit || {isPlayer _unit} || {!alive _unit} || {!simulationEnabled _unit}) exitWith {true};

        private _enemy = _unit findNearestEnemy _unit;
        if (!isNull _enemy && {_unit distance _enemy < DM_var_aiEngageDistance}) exitWith {false};

        private _canReorder = time - _lastOrder >= DM_var_aiReorderDelay;
        private _arrived = _unit distance2D _destination < DM_var_aiArrivalDistance || {_canReorder && {unitReady _unit}};

        if (_arrived || {!(_destination inArea "DM_mrk_playZone")}) exitWith {
            private _newDestination = [("DM_mrk_playZone" call BIS_fnc_randomPosTrigger), "B_Soldier_F", 2] call DM_fnc_findSpawnPos;

            if (alive _unit) then {
                _destination = _newDestination;
                _unit doMove _destination;
                _lastOrder = time;
            };

            false
        };

        // repeat the order when the unit got stuck or left the zone
        if (_canReorder && {speed _unit < 2 || {!(_unit inArea "DM_mrk_playZone")}}) then {
            _unit doMove _destination;
            _lastOrder = time;
        };

        false
    };
};
