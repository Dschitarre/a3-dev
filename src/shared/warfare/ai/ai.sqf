// AI: identity of the AI units (names, ranks, pool init) and the main AI loop that drives the objective planning, the
// AI squads and the per-unit upkeep (server).

// ---- identity ----

// loadout of a fresh AI unit before SC_fnc_spawnAi equips it
SC_var_emptyLoadout = [[], [], [], [], [], [], "", "", [], ["", "", "", "", "", ""]];

// server: prepares the playable AI units (names, ranks, groups) and puts them into the suspended pools.
// Slots that are already controlled by a player (players connected when the mission starts) are left out,
// SC_fnc_playerServer turns them into player units.
SC_fnc_initAIUnitsServer = {
    private _aiUnits = playableUnits select {!(isPlayer _x)};
    SC_var_suspendedUnitsWest = _aiUnits select {(side _x) == west};
    SC_var_suspendedUnitsEast = _aiUnits select {(side _x) == east};
    SC_var_suspendedUnitsGuer = _aiUnits select {(side _x) == independent};

    // ids of units that become pool AI later (slots of players who disconnect) follow all initial ids
    SC_var_nextAiUnitId = count playableUnits;

    {
        private _side = [west, east, independent] select _forEachIndex;

        {
            // pool units stay invisible until they spawn (SC_fnc_spawnAi) or a player takes the slot (SC_fnc_initClient):
            // a late joiner saw the frozen pool units standing at their editor positions
            _x hideObjectGlobal true;
            // the editor units' engine names, for base-game units on maps with their own names (SC_var_worldNameSets)
            // one of those
            private _nameArr = if (isNil {SC_var_worldNameSets get toLowerANSI worldName} || {((typeOf _x) find "CUP_") == 0}) then {
                ((name _x) splitString " ") call SC_fnc_getAiNameArr
            } else {
                [_x] call SC_fnc_getRandomAiNameArr
            };
            [_x, _side, _forEachIndex, _nameArr] call SC_fnc_initPoolAi;
        } forEach _x;
    } forEach [SC_var_suspendedUnitsWest, SC_var_suspendedUnitsEast, SC_var_suspendedUnitsGuer];
};

// server: AI identity (name, rank, skill, unit id) and the single-unit group of a pool AI unit (a free AI, it joins or
// forms an SC group in SC_fnc_aiGroupLoop)
SC_fnc_initPoolAi = {
    params ["_unit", "_side", "_unitId", "_nameArr"];

    [_unit, _nameArr] remoteExecCall ["setName", 0, _unit];

    _unit setVariable ["SC_var_groupUnits", [_unit], true];
    _unit setVariable ["SC_var_groupTargetSize", nil];
    _unit setVariable ["SC_var_unitId", _unitId];
    _unit setVariable ["SC_var_aiSkill", 0.7 + random 0.3];
    _unit setVariable ["ais_side", _side, true];

    private _rank = call SC_fnc_getRandomAiRank;
    _unit setVariable ["SC_var_rank", _rank, true];

    private _newName = "[" + (str _rank) + "] " + (_nameArr select 0);
    _unit setVariable ["TDI_var_name", _newName, true];
    _unit setVariable ["MM_var_name", _newName, true];

    [_unit] call SC_fnc_leaveSquad;
};

// server: turns the slot unit of a player who disconnected back into a suspended pool AI (fresh loadout, AI name,
// rank, id and skill), so the AI pool keeps its size
SC_fnc_returnUnitToPool = {
    params ["_unit"];

    [_unit] call SC_fnc_resetUnitState;
    _unit setUnitLoadout SC_var_emptyLoadout;

    // the AIS damage handlers of an AI are only added while the unit is local to the server and no player
    if !(missionNamespace getVariable ["ais_ace_shutDown", false]) then {
        [_unit] call AIS_Core_fnc_aisInitHost;
    };

    [_unit, side (group _unit), SC_var_nextAiUnitId, ([_unit] call SC_fnc_getRandomAiNameArr)] call SC_fnc_initPoolAi;
    SC_var_nextAiUnitId = SC_var_nextAiUnitId + 1;

    [_unit, "player left"] call SC_fnc_suspendUnit;
};

// 20 % of the AI get a rank up to a random cutoff (1 - 35), the others a rank above it that is mostly close to it
SC_fnc_getRandomAiRank = {
    private _cutoff = ceil ((random 1) * 35);

    1 max (if ((random 1) < 0.2) then {
        ceil ((random 1) * _cutoff)
    } else {
        _cutoff + (ceil ((random (1000 - _cutoff))*(random 1)*(random 1)*(random 1)*(random 1)))
    })
};

SC_fnc_isUavAi = {
    params ["_unit"];

    "UAV_AI" in (typeOf _unit)
};

// [full name, first name, last name] of an AI: ["John", "Smith"] -> ["J. Smith (AI)", "J.", "Smith (AI)"],
// ["Jean-Luc", "Picard"] -> ["J.-L. Picard (AI)", "J.-L.", "Picard (AI)"]
SC_fnc_getAiNameArr = {
    params ["_firstName", ["_lastName", ""]];

    private _initials = (((_firstName splitString "-") select [0, 2]) apply {(_x select [0, 1]) + "."}) joinString "-";
    private _aiLastName = _lastName + " (AI)";

    [(_initials + " " + _aiLastName), _initials, _aiLastName]
};

// The name set (CfgWorlds >> GenericNames) of base-game AI on a map whose people have their own names (user 2026-11-25:
// CUP names on the CUP maps): CUP's Chernarus factions (civilians, CDF, ChDKZ, NAPA) all use CUP_Names_CzechMen. CUP
// units keep their faction's own CUP names (Russians CUP_Names_RussianMen - SC on Chernarus, probe sc01chern), other
// maps the unit's own set
SC_var_worldNameSets = createHashMapFromArray [
    ["cup_chernarus_a3", "CUP_Names_CzechMen"], ["chernarus", "CUP_Names_CzechMen"], ["chernarus_summer", "CUP_Names_CzechMen"],
    ["chernarus_winter", "CUP_Names_CzechMen"], ["utes", "CUP_Names_CzechMen"], ["takistan", "CUP_Names_TakistaniMen"],
    ["zargabad", "CUP_Names_TakistaniMen"], ["mountains_acr", "CUP_Names_TakistaniMen"], ["sara", "SahraniNames"],
    ["sara_dbe1", "SahraniNames"], ["saralite", "SahraniNames"], ["porto", "SahraniNames"]
];

// AI name of a random first and last name of the map's name set, else of the unit's nationality (the names the engine
// gives AI units)
SC_fnc_getRandomAiNameArr = {
    params ["_unit"];

    private _setName = getText ((configOf _unit) >> "genericNames");
    if (((typeOf _unit) find "CUP_") != 0) then {_setName = SC_var_worldNameSets getOrDefault [toLowerANSI worldName, _setName]};
    if !(isClass (configFile >> "CfgWorlds" >> "GenericNames" >> _setName)) then {_setName = getText ((configOf _unit) >> "genericNames")};
    private _genericNames = configFile >> "CfgWorlds" >> "GenericNames" >> _setName;
    private _firstNames = configProperties [(_genericNames >> "FirstNames"), "isText _x"];
    private _lastNames = configProperties [(_genericNames >> "LastNames"), "isText _x"];

    if ((_firstNames isEqualTo []) || {_lastNames isEqualTo []}) exitWith {
        ["John", "Smith"] call SC_fnc_getAiNameArr
    };

    [(getText (selectRandom _firstNames)), (getText (selectRandom _lastNames))] call SC_fnc_getAiNameArr
};

// ---- debug log ----

// true: decisions of the AI (objectives, states, vehicles, stuck, repairs, suspends) are written to the RPT as
// "AIDIAG|EV|<time>|<event>|<group>|<side>|..." lines
SC_var_aiDebug = false;

SC_fnc_aiLog = {
    params ["_event", "_group"];

    if !SC_var_aiDebug exitWith {};

    diag_log text (format ["AIDIAG|EV|%1|%2|%3|%4|", round time, _event,
        [netId _group, "-"] select (isNull _group), side _group] +((_this select [2]) joinString "|"));
};

// ---- main loop ----

// seconds of one pass over all AI squads, and between two objective plannings of a side
SC_var_aiCycleTime = 4;
SC_var_aiPlanInterval = 8;

// AI squads (engine groups of AI without players) and UAV crews of a side
SC_fnc_aiGetSquads = {
    params ["_side"];

    private _squads = [];
    private _uavGroups = [];

    {
        if (!(isNull _x) && {alive _x} && {simulationEnabled _x} && {!(isPlayer _x)}) then {
            private _group = group _x;

            if ([_x] call SC_fnc_isUavAi) then {
                _uavGroups pushBackUnique _group;
            } else {
                if (((units _group) findIf {isPlayer _x}) == -1) then {
                    _squads pushBackUnique _group;
                };
            };
        };
    } forEach (([_side] call SC_fnc_getSidesUnits) + ([_side] call SC_fnc_getSidesUavAiUnits));

    [_squads, _uavGroups]
};

SC_fnc_aiLoop = {
    call SC_fnc_aiUpdateSectorInfo;
    [] spawn SC_fnc_aiVehicleLoop;

    // land masses for the boat travel across the water (whole-map maps with harbours, SC\ai\boats.sqf)
    if SC_var_wholeMap then {
        SC_var_aiLandmassScript = [] spawn SC_fnc_aiBuildLandmasses;
    };

    private _nextPlanTimes = SC_var_sides apply {0};

    waitUntil {
        private _cycleStart = time;

        call SC_fnc_aiUpdateSectorInfo;

        // per-unit upkeep (copy: suspended units leave the registry)
        {
            {
                if !(isNull _x) then {
                    [_x] call SC_fnc_aiUpdateUnit;
                };
            } forEach ((+([_x] call SC_fnc_getSidesUnits)) + ([_x] call SC_fnc_getSidesUavAiUnits));
        } forEach SC_var_sides;

        // the squads are taken right before their side's turn (squads change while the other sides run)
        private _numSquads = 0;

        {
            _numSquads = _numSquads + (count (([_x] call SC_fnc_aiGetSquads) select 0));
        } forEach SC_var_sides;

        {
            private _side = _x;
            ([_side] call SC_fnc_aiGetSquads) params ["_squads", "_uavGroups"];

            // planned at once when a squad has no objective (new squad, objective done)
            if ((time >= (_nextPlanTimes select _forEachIndex)) || {(_squads findIf {(_x getVariable ["SC_var_aiTarget", ""]) == ""}) != -1}) then {
                [_side, _squads] call SC_fnc_aiPlanDeliveries;
                [_side, _squads] call SC_fnc_aiPlanSide;
                _nextPlanTimes set [_forEachIndex, time + SC_var_aiPlanInterval];
            };

            {
                if !(isNull _x) then {
                    [_x] call SC_fnc_aiUpdateSquad;
                };

                sleep (SC_var_aiCycleTime / (_numSquads max 1));
            } forEach _squads;

            {
                [_x, _side] call SC_fnc_aiUpdateUav;
            } forEach _uavGroups;
        } forEach SC_var_sides;

        // a cycle that takes much longer than SC_var_aiCycleTime means the scheduler is overloaded
        ["cycle", grpNull, (round ((time - _cycleStart) * 10)) / 10, _numSquads] call SC_fnc_aiLog;

        sleep (0.5 max (SC_var_aiCycleTime - (time - _cycleStart)));
        false
    };
};
