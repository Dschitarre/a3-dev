// AI objectives: the commander of every side rates the sectors (attack, defend) and distributes them over the AI
// squads of the side, so that the squads push the front forward together instead of each one walking off to a random
// sector (server).

// ---- sector picture ----

// enemies within this distance of a sector's edge count as a threat to it (and as resistance when attacking it)
SC_var_aiThreatMargin = 150;

// an own sector without a threat stays a defend objective for this long (seconds), so defenders don't run off and
// straight back in a fight that pauses
SC_var_aiDefendCalmTime = 30;

// per sector: [center, radius, owner, holder, flag, men near per side (hashmap)]; men are counted within
// SC_var_aiThreatMargin of the edge (crews of vehicles included, suspended and unconscious units not)
SC_fnc_aiUpdateSectorInfo = {
    private _info = createHashMap;

    {
        private _sectorInd = _x;
        private _marker = "SC_var_sector" + _sectorInd;
        private _center = getMarkerPos _marker;
        private _radius = selectMax (getMarkerSize _marker);
        private _menNear = createHashMapFromArray (SC_var_sides apply {[_x, 0]});

        {
            {
                if ((alive _x) && {simulationEnabled _x} && {!(_x getVariable ["AIS_unconscious", false])}) then {
                    private _side = side (group _x);

                    if (_side in _menNear) then {
                        _menNear set [_side, (_menNear get _side) + 1];
                    };
                };
            } forEach ([crew _x, [_x]] select (_x isKindOf "CAManBase"));
        } forEach (_center nearEntities [["CAManBase", "LandVehicle", "Air"], _radius + SC_var_aiThreatMargin]);

        _info set [_sectorInd, [
        _center,
        _radius,
        missionNamespace getVariable ("SC_var_owner" + _sectorInd),
        missionNamespace getVariable ("SC_var_holder" + _sectorInd),
        missionNamespace getVariable ("SC_var_flag" + _sectorInd),
        _menNear
        ]];
    } forEach SC_var_sectors;

    SC_var_aiSectorInfo = _info;
};

// number of enemy men of _side near a sector (from the sector picture)
SC_fnc_aiEnemiesNear = {
    params ["_side", "_menNear"];

    private _enemies = 0;

    {
        if (_x != _side) then {
            _enemies = _enemies + _y;
        };
    } forEach _menNear;

    _enemies
};

// ---- objectives ----

// The commander counts in men (able members of the squads), not in squads: SC groups have 1 - SC_var_squadMaxSize
// members; the demand of an objective is one full squad (SC_var_aiFullSquadSize men) per 3 enemies near it.

// for every this many men of a side (a squad) one sector of the front is attacked (at least 2), so the squads spread
// over the front instead of several going for the same sector
SC_var_aiMenPerFrontSector = 4;

// every this many men more than an objective needs halve its rating
SC_var_aiOverloadMen = 4;

// every full squad (SC_var_aiFullSquadSize men) of the side that already goes for an objective or is near it lowers
// its rating to this share, so the squads spread over the objectives instead of all going for the same one
SC_var_aiCrowdFactor = 0.75;
SC_var_aiRebalanceDefenders = false;

// whether an own sector is threatened: enemies near, flag not full or held by another side
SC_fnc_aiIsThreatened = {
    params ["_side", "_sectorInfo"];

    _sectorInfo params ["", "", "", "_holder", "_flag", "_menNear"];

    (([_side, _menNear] call SC_fnc_aiEnemiesNear) > 0) || {_flag < 100} || {_holder != _side}
};

// Objectives of a side: [sector, kind, value, demand (men), enemies near]. "defend": an own threatened sector.
// "attack": a sector the side doesn't own, but only those of the front (the ones closest to the own sectors and base,
// one per SC_var_aiMenPerFrontSector men), so the squads push the front forward together instead of spreading over
// the whole map. The value rates the importance, the demand grows with the enemies; men that are left over raise the
// demand of the attacks evenly.
SC_fnc_aiGetObjectives = {
    params ["_side", "_strength"];

    private _territory = [getMarkerPos ("SC_var_" + (toLower (str _side)) + "Respawn")];

    {
        if ((_y select 2) == _side) then {
            _territory pushBack (_y select 0);
        };
    } forEach SC_var_aiSectorInfo;

    private _defend = [];
    private _attack = [];

    {
        _y params ["_center", "_radius", "_owner", "_holder", "_flag", "_menNear"];

        private _enemies = [_side, _menNear] call SC_fnc_aiEnemiesNear;

        if (_owner == _side) then {
            if ([_side, _y] call SC_fnc_aiIsThreatened) then {
                _defend pushBack [_x, "defend",
                    ([1.5, 2] select (_flag < 100)) +(0.1 *(_enemies min 8)),
                    SC_var_aiFullSquadSize *(1 max (4 min (ceil (_enemies / 3)))), _enemies];
            };
        } else {

            // a capture of the side that is under way is finished first, a neutral sector is quicker to take
            private _value = switch true do {
                case ((_holder == _side) && {_flag > 0}): {1.4};
                case (_owner == civilian): {1.15};
                default {1};
            };

            private _frontDistance = selectMin (_territory apply {_x distance2D _center});

            // (the count is a unique second sort key: the arrays after it are never compared)
            _attack pushBack [_frontDistance, count _attack,
                [_x, "attack", _value, SC_var_aiFullSquadSize *(4 min (1 +(floor (_enemies / 3)))),
                _enemies]];
        };
    } forEach SC_var_aiSectorInfo;

    _attack sort true;
    _attack = (_attack select [0, 2 max (ceil (_strength / SC_var_aiMenPerFrontSector))]) apply {_x select 2};

    private _totalDemand = 0;

    {
        _totalDemand = _totalDemand + (_x select 3);
    } forEach (_defend + _attack);

    if ((_totalDemand < _strength) && {_attack isNotEqualTo []}) then {
        private _extraDemand = ceil ((_strength - _totalDemand) / (count _attack));

        {
            _x set [3, (_x select 3) + _extraDemand];
        } forEach _attack;
    };

    _defend + _attack
};

// objective of a sector that isn't one of the side's objectives (an attack outside the front that a squad keeps)
SC_fnc_aiSectorObjective = {
    params ["_side", "_sectorInd"];

    private _sectorInfo = SC_var_aiSectorInfo get _sectorInd;
    private _enemies = [_side, (_sectorInfo select 5)] call SC_fnc_aiEnemiesNear;

    if ((_sectorInfo select 2) == _side) exitWith {[_sectorInd, "defend", 1.5, SC_var_aiFullSquadSize, _enemies]};

    [_sectorInd, "attack", 1, SC_var_aiFullSquadSize, _enemies]
};

// whether the objective of a squad still makes sense: an attack until the side owns the sector (then it becomes a
// defense while the sector is threatened), a defense until the sector was safe for SC_var_aiDefendCalmTime
SC_fnc_aiIsObjectiveValid = {
    params ["_group", "_side"];

    private _target = _group getVariable ["SC_var_aiTarget", ""];

    if (_target == "") exitWith {false};

    private _sectorInfo = SC_var_aiSectorInfo get _target;

    if ((_sectorInfo select 2) != _side) exitWith {
        _group setVariable ["SC_var_aiTargetKind", "attack"];
        true
    };

    if ([_side, _sectorInfo] call SC_fnc_aiIsThreatened) exitWith {
        if ((_group getVariable ["SC_var_aiTargetKind", ""]) != "defend") then {
            _group setVariable ["SC_var_aiTargetKind", "defend"];
            ["objective", _group, _target, "defend", "captured, still threatened"] call SC_fnc_aiLog;
        };

        _group setVariable ["SC_var_aiCalmSince", -1];
        true
    };

    // the sector is safe now; defenders stay a little while
    private _calmSince = _group getVariable ["SC_var_aiCalmSince", -1];

    if (_calmSince < 0) then {
        _group setVariable ["SC_var_aiCalmSince", time];
        _calmSince = time;
    };

    ((_group getVariable ["SC_var_aiTargetKind", ""]) == "defend") && {(time - _calmSince) < SC_var_aiDefendCalmTime}
};

// Rating of an objective for a squad of _strength men: value per estimated travel time (vehicle or on foot), lowered
// by the men of the side that already go for it or are near it (_ownNear, without the squad) and much more when it
// already has as many men as it needs; a squad's current objective gets a bonus (no flip-flopping), AI squads of a
// player's group prefer the objective closest to their player. Small squads (fewer men than a full squad) prefer
// defending and close objectives and rather avoid attacking a sector with enemies.
SC_fnc_aiRateObjective = {
    params ["_objective", "_squadPos", "_speed", "_load", "_strength", "_currentTarget", "_playerPos", ["_ownNear", 0]];

    ([_objective, _squadPos, _speed, _strength, _currentTarget, _playerPos] call SC_fnc_aiRateObjectiveBase) *
    ([_load, _ownNear, _strength, _objective select 3] call SC_fnc_aiLoadFactor)
};

// the part of the rating that doesn't depend on the men already going for the objective
SC_fnc_aiRateObjectiveBase = {
    params ["_objective", "_squadPos", "_speed", "_strength", "_currentTarget", "_playerPos"];

    _objective params ["_sectorInd", "_kind", "_value", "_demand", "_enemies"];

    private _sectorInfo = SC_var_aiSectorInfo get _sectorInd;
    private _center = _sectorInfo select 0;
    private _distance = 0 max ((_squadPos distance2D _center) - (_sectorInfo select 1));
    private _missing = 0 max (SC_var_aiFullSquadSize - _strength);
    private _rating = _value / (60 + ((_distance / _speed) * (1 + (_missing / 6))));

    if (_kind == "defend") then {
        _rating = _rating * (1 + (0.25 * _missing));
    } else {

        if (_enemies > 0) then {
            _rating = _rating * (1 - (_missing / 8));
        };
    };

    if (_sectorInd == _currentTarget) then {
        _rating = _rating * 1.3;
    };

    if ((_playerPos isNotEqualTo []) && {(_playerPos distance2D _center) < ((_sectorInfo select 1) + 300)}) then {
        _rating = _rating * 2;
    };

    _rating
};

// the factor of the rating by the men already going for the objective (_load) or near it (_ownNear)
SC_fnc_aiLoadFactor = {
    params ["_load", "_ownNear", "_strength", "_demand"];

    private _factor = SC_var_aiCrowdFactor ^ ((_load max _ownNear) / SC_var_aiFullSquadSize);
    private _overload = _load + _strength - _demand;

    if (_overload > 0) then {
        _factor = _factor * (0.5 ^ (_overload / SC_var_aiOverloadMen));
    };

    _factor
};

// key of the SC group of an AI squad (fire team): the net id of the group's first unit
SC_fnc_aiSquadKey = {
    params ["_group"];

    private _units = ([leader _group] call SC_fnc_getGroupUnits) select {!(isNull _x)};

    netId (_units param [0, leader _group])
};

// strength of a squad: its able members (alive, active, conscious), at least 1
SC_fnc_aiSquadStrength = {
    params ["_group"];

    1 max ({(alive _x) && {simulationEnabled _x} && {!(_x getVariable ["AIS_unconscious", false])}} count (units _group))
};

// position of a living player of the squad's SC group ([] if none): his AI group mates support him
SC_fnc_aiGetSquadPlayerPos = {
    params ["_group"];

    private _players = ([leader _group] call SC_fnc_getGroupUnits) select {(isPlayer _x) && {alive _x}};

    if (_players isEqualTo []) exitWith {[]};

    getPosWorld (_players select 0)
};

// Commander pass of a side (per SC group, see below): squads with a valid objective keep it (their men count as load),
// the others get objectives that still have room for them, the best pairs of squad and objective first (greedy with a
// hard cap per objective: the squads spread over the objectives by their demand). A squad that is still far from its
// objective after 2 minutes only switches to a defense that is clearly better (an own sector nearby is attacked), so
// squads don't turn around halfway.
SC_fnc_aiPlanSide = {
    params ["_side", "_squads"];

    _squads = _squads select {!(isNull _x) && {((units _x) findIf {alive _x}) != -1}};

    // The fire teams of an SC group plan as one: its lead (a fire team with an objective, else the first) stands for
    // it with the strength of all of them; afterwards the others take the lead's objective. (Groups can't be hashmap
    // keys: the teams, leads and strengths are arrays in the same order.)
    private _keys = [];
    private _teams = [];

    {
        private _key = [_x] call SC_fnc_aiSquadKey;
        private _index = _keys find _key;

        if (_index == -1) then {
            _keys pushBack _key;
            _teams pushBack [_x];
        } else {

            (_teams select _index) pushBack _x;
        };
    } forEach _squads;

    private _leads = _teams apply {
        private _withTarget = _x select {(_x getVariable ["SC_var_aiTarget", ""]) != ""};
        ([_withTarget, _x] select (_withTarget isEqualTo [])) select 0
    };

    private _strengths = _teams apply {
        private _sum = 0;

        {
            _sum = _sum + ([_x] call SC_fnc_aiSquadStrength);
        } forEach _x;

        _sum
    };

    private _totalStrength = 0;

    {
        _totalStrength = _totalStrength + _x;
    } forEach _strengths;

    private _objectives = [_side, _totalStrength] call SC_fnc_aiGetObjectives;

    if (_objectives isEqualTo []) exitWith {
        {
            _x setVariable ["SC_var_aiTarget", ""];
        } forEach _squads;
    };

    _squads = _leads;
    private _loads = createHashMap;
    private _toPlan = [];
    private _committed = [];

    {
        private _group = _x;

        if ([_group, _side] call SC_fnc_aiIsObjectiveValid) then {
            private _target = _group getVariable "SC_var_aiTarget";
            _loads set [_target, (_loads getOrDefault [_target, 0]) + (_strengths select _forEachIndex)];

            // committed squads (near the objective or on their way for less than 2 minutes) keep it
            private _sectorInfo = SC_var_aiSectorInfo get _target;
            private _distance = ((leader _group) distance2D (_sectorInfo select 0)) - (_sectorInfo select 1);

            if ((_distance > 300) && {(time - (_group getVariable ["SC_var_aiTargetTime", time])) > 120}) then {
                _toPlan pushBack _group;
                _committed pushBack _group;
            };
        } else {

            if ((_group getVariable ["SC_var_aiTarget", ""]) != "") then {
                ["objective", _group, (_group getVariable "SC_var_aiTarget"), "", "done"] call SC_fnc_aiLog;
            };

            _group setVariable ["SC_var_aiTarget", ""];
            _toPlan pushBack _group;
        };
    } forEach _squads;

    private _offensiveReserve = [];

    if (SC_var_aiRebalanceDefenders) then {
        private _attacks = _objectives select {(_x select 1) == "attack"};
        private _needed = 0;
        {_needed = _needed + (0 max ((_x select 3) - (_loads getOrDefault [_x select 0, 0])))} forEach _attacks;
        private _available = 0;
        {if ((_x getVariable ["SC_var_aiTarget", ""]) == "") then {_available = _available + (_strengths select (_squads find _x))}} forEach _toPlan;

        {
            if (_available >= _needed) exitWith {};

            private _group = _x;
            private _target = _group getVariable ["SC_var_aiTarget", ""];

            if (_target != "" && {(_group getVariable ["SC_var_aiTargetKind", ""]) == "defend"}) then {
                private _index = _objectives findIf {(_x select 0) == _target};
                private _demand = if (_index < 0) then {0} else {(_objectives select _index) select 3};
                private _load = _loads getOrDefault [_target, 0];
                private _strength = _strengths select _forEachIndex;

                // Whole virtual squads move together; tolerate half a squad of rounding in the garrison.
                if (_load > _demand && {_load - _strength >= 0 max (_demand - _strength / 2)}) then {
                    _loads set [_target, 0 max (_load - _strength)];
                    _group setVariable ["SC_var_aiTarget", ""];
                    _toPlan pushBackUnique _group;
                    _committed = _committed-[_group];
                    _offensiveReserve pushBack _group;
                    _available = _available + _strength;
                };
            };
        } forEach _squads;
    };

    // The squads to plan with their candidates: the rating without the load (by travel time) and the own men near each.
    private _pending = [];

    {
        private _group = _x;
        private _currentTarget = _group getVariable ["SC_var_aiTarget", ""];
        private _squadPos = getPosWorld (leader _group);
        private _speed = [SC_var_aiFootSpeed, SC_var_aiVehicleSpeed] select (_group getVariable ["SC_var_aiMobile", false]);
        private _playerPos = [_group] call SC_fnc_aiGetSquadPlayerPos;
        private _strength = _strengths select (_squads find _group);

        // the squad's own objective is rated without its own load
        if (_currentTarget != "") then {
            _loads set [_currentTarget, (_loads get _currentTarget) - _strength];
        };

        // the current objective stays a candidate even if it isn't at the front any more
        private _candidates = if (_group in _committed) then {
            _objectives select {((_x select 0) == _currentTarget) || {(_x select 1) == "defend"}}
        } else {

            +_objectives
        };

        if (_group in _offensiveReserve) then {_candidates = _objectives select {(_x select 1) == "attack"}};

        if ((_currentTarget != "") && {(_candidates findIf {(_x select 0) == _currentTarget}) == -1}) then {
            _candidates pushBack ([_side, _currentTarget] call SC_fnc_aiSectorObjective);
        };

        private _bases = [];
        private _ownNears = [];

        {
            (SC_var_aiSectorInfo get (_x select 0)) params ["_center", "_radius", "", "", "", "_menNear"];

            // the men of the side near the sector, without the squad itself
            private _ownNear = _menNear getOrDefault [_side, 0];

            if ((_squadPos distance2D _center) < (_radius + SC_var_aiThreatMargin)) then {
                _ownNear = 0 max (_ownNear - _strength);
            };

            _ownNears pushBack _ownNear;
            _bases pushBack ([_x, _squadPos, _speed, _strength, _currentTarget, _playerPos] call SC_fnc_aiRateObjectiveBase);
        } forEach _candidates;

        _pending pushBack [_group, _strength, _currentTarget, _candidates, _bases, _ownNears];
    } forEach _toPlan;

    // Global greedy: the best pair of a squad and an objective is assigned first, then the next with the loads so far, so
    // every objective gets the squads closest to it (planning one squad after the other in any order sent many squads
    // across the map to the objectives the closer ones had left). Hard cap per objective: an objective only gets more men
    // than it needs (its share of the side's men) while no other one has room for the squad, and one that already has
    // all it needs only while no other one has room at all.
    while {_pending isNotEqualTo []} do {
        private _bestScore = -1e9;
        private _bestPlan = 0;
        private _bestCandidate = 0;

        {
            _x params ["", "_strength", "", "_candidates", "_bases", "_ownNears"];

            private _planIndex = _forEachIndex;

            {
                private _load = _loads getOrDefault [(_x select 0), 0];
                private _demand = _x select 3;

                private _tier = switch true do {
                    case ((_load + _strength) <= _demand): {2};
                    case (_load < _demand): {1};
                    default {0};
                };

                private _score =(10 * _tier) +((_bases select _forEachIndex) *([_load,
                    _ownNears select _forEachIndex, _strength, _demand] call SC_fnc_aiLoadFactor));

                if (_score > _bestScore) then {
                    _bestScore = _score;
                    _bestPlan = _planIndex;
                    _bestCandidate = _forEachIndex;
                };
            } forEach _candidates;
        } forEach _pending;

        (_pending deleteAt _bestPlan) params ["_group", "_strength", "_currentTarget", "_candidates"];
        (_candidates select _bestCandidate) params ["_bestTarget", "_bestKind"];

        if (_bestTarget != _currentTarget) then {
            _group setVariable ["SC_var_aiTarget", _bestTarget];
            _group setVariable ["SC_var_aiTargetKind", _bestKind];
            _group setVariable ["SC_var_aiTargetTime", time];
            _group setVariable ["SC_var_aiCalmSince", -1];
            _group setVariable ["SC_var_aiTargetPos", []];
            ["objective", _group, _bestTarget, _bestKind,
                format ["from '%1', load %2, strength %3", _currentTarget,
                (_loads getOrDefault [_bestTarget, 0]), _strength]] call SC_fnc_aiLog;
        };

        _loads set [_bestTarget, (_loads getOrDefault [_bestTarget, 0]) + _strength];
    };

    // the other fire teams of an SC group go for the objective of its lead
    {
        private _lead = _leads select _forEachIndex;
        private _target = _lead getVariable ["SC_var_aiTarget", ""];
        private _kind = _lead getVariable ["SC_var_aiTargetKind", ""];

        {
            if (_x isNotEqualTo _lead) then {
                if ((_x getVariable ["SC_var_aiTarget", ""]) != _target) then {
                    _x setVariable ["SC_var_aiTarget", _target];
                    _x setVariable ["SC_var_aiTargetTime", time];
                    _x setVariable ["SC_var_aiCalmSince", -1];
                    _x setVariable ["SC_var_aiTargetPos", []];
                };

                _x setVariable ["SC_var_aiTargetKind", _kind];
            };
        } forEach _x;
    } forEach _teams;
};

// objective of a UAV crew: the most valuable objective nearest to it (no load balancing, UAVs only support)
SC_fnc_aiPlanUav = {
    params ["_group", "_side"];

    private _objectives = [_side, SC_var_aiFullSquadSize] call SC_fnc_aiGetObjectives;

    if (_objectives isEqualTo []) exitWith {""};

    private _pos = getPosWorld (vehicle (leader _group));
    private _ratings = _objectives apply {[_x, _pos, SC_var_aiVehicleSpeed, 0, SC_var_aiFullSquadSize, "", []] call SC_fnc_aiRateObjective};

    (_objectives select (_ratings find (selectMax _ratings))) select 0
};
