// Battle Royale AI looting (server): an AI gets its gear only from real loot - the loot holders in buildings (spawned
// for the building it searches, BR\loot\loot.sqf) and supply crates (BR\airdrops.sqf). It walks to each holder and
// takes what it can use; what it takes is gone for everyone else.

BR_var_aiLootRadius = 150;          // buildings searched in the state "loot" ...
BR_var_aiNeedyLootRadius = 250;     // ... by an AI without weapon or ammo when scavenging (only fresh buildings) ...
BR_var_aiUrgentLootRadius = 30;     // ... and right on its way when the zone presses: ahead (towards the zone) ...
BR_var_aiUrgentLootAngle = 60;      // ... within this many degrees of its way ...
BR_var_aiUrgentLootTimeout = 15;    // ... and a holder not reached in this time is skipped
BR_var_aiLootStops = [2, 4];        // buildings searched before heading into the zone, random in [min, max]
BR_var_aiLootReach = 3;             // an AI takes loot this close to the holder (horizontally, on its floor) ...
BR_var_aiLootFloorHeight = 2;       // m height difference that still counts as the same floor
BR_var_aiLootTimeout = 40;
    // a holder not reached in this time (plus its way at BR_var_aiTravelSpeed) is skipped (no way up, locked door) ...
BR_var_aiLootNearDistance = 15;     // ... and this close to it one that got no closer for BR_var_aiLootProgressTime ...
BR_var_aiLootProgressTime = [12, 16]; // ... s: [armed, without weapon or ammo]
BR_var_aiLootMaxMisses = 3;         // holders not reached in a row: the loot run ends (unreachable floors, towers)
BR_var_aiLootMaxFails = 2;          // runs into a building that reached no holder: then no AI goes there any more
BR_var_aiScavengeTime = 40;         // AI that moves, follows or holds searches a building close by this often ...
BR_var_aiScavengeRadius = 40;       // ... when one is this close ...
BR_var_aiNeedyScavengeTime = 10;    // ... while without weapon or ammo more often (BR_var_aiNeedyLootRadius)
BR_var_aiIdleLootInterval = 10;     // holding at its zone spot an AI looks for houses around this often ...
BR_var_aiIdleLootZoneShare = 0.8;   // ... that lie within this share of the next zone's radius
BR_var_aiCrateRadius = 700;         // an AI goes for a landed supply crate this close inside the next zone ...
BR_var_aiCrateTeams = 2;            // ... unless this many teams already go for it
BR_var_aiCrateReach = 6;            // m: an AI gets no closer than about 4 m to the crate (it blocks its way)
BR_var_aiCrateTimeout = 360;        // a crate not reached in this time is given up
BR_var_aiCrateCheckInterval = 10;
BR_var_aiRearmRadius = 50;          // a stuck engine rearming takes the usable loot this close (BR_fnc_aiRearmNearby)
BR_var_aiWeaponSeekRadius = 250;    // an AI without weapon or ammo goes for a primary weapon lying this close (BR_fnc_aiSeekWeapon) ...
BR_var_aiWeaponSeekRetry = 60;      // ... and tries one it did not reach again after this many seconds
BR_var_aiNeedyBuildingWay = 60;     // m added to the way when an AI without weapon weighs loot spots against distance
BR_var_aiWeaponSeekMax = 500;       // m: without zone pressure it looks this far when nothing is closer (BR_fnc_aiSeekWeapon)
BR_var_aiLooseLootTime = 12;        // s to reach loose loot, plus its way at BR_var_aiTravelSpeed

// true without a primary weapon or without ammo for it (none loaded, none carried)
BR_fnc_aiNeedsGear = {
    params ["_unit"];

    private _weapon = primaryWeapon _unit;

    _weapon == "" ||
    {(_unit ammo _weapon) == 0 &&
        {(((magazines _unit) apply {toLowerANSI _x}) arrayIntersect ([_weapon] call BR_fnc_weaponMagazines)
        ) isEqualTo []}}
};

BR_fnc_aiNeedsSupplies = {
    params ["_unit"];
    if ([_unit] call BR_fnc_aiNeedsGear) exitWith {true};
    private _rounds = 0;
    private _compatible = [primaryWeapon _unit] call BR_fnc_weaponMagazines;
    {if((toLowerANSI (_x select 0)) in _compatible) then {_rounds = _rounds +(_x select 1)}} forEach ([
        getUnitLoadout _unit] call BR_fnc_aiLoadoutMagazines);
    _rounds < 60 || {vest _unit == ""} || {headgear _unit == ""} ||
    {((items _unit) arrayIntersect BR_var_aiHealItems) isEqualTo [] && {!(BR_var_bandageClass in magazines _unit)}}
};

// ---- buildings ----

// state "loot": building after building until the wanted number is searched or none is left nearby, then "move"
BR_fnc_aiLootTick = {
    params ["_unit", "_urgent"];

    private _enough = (_unit getVariable ["BR_var_lootStops", 0]) >= 1 && {!([_unit] call BR_fnc_aiNeedsSupplies)};
    private _building = if (_enough) then {objNull} else {
        [_unit, [BR_var_aiLootRadius, BR_var_aiNeedyLootRadius] select _urgent] call BR_fnc_aiLootableBuilding
    };

    if (isNull _building) exitWith {
        // without weapon or ammo it looks farther (weapons lying around, fresh buildings) before it heads for the zone
        if ([_unit] call BR_fnc_aiNeedsGear && {[_unit, _urgent] call BR_fnc_aiSeekWeapon}) exitWith {};
        _unit setVariable ["BR_var_aiState", "move"];
    };

    [_unit, _building] call BR_fnc_aiStartLootRun;
};

/*
    Moving, following or holding: a loot run into a building close by now and then while the unit wants more loot; at
    once and farther while it has no weapon or no ammo - when the zone presses only one right on its way
    (BR_var_aiUrgentLootRadius). True if a run started.
*/
BR_fnc_aiScavenge = {
    params ["_unit", "_urgent"];

    private _needy = [_unit] call BR_fnc_aiNeedsGear;

    if (!_needy && {_urgent || {(_unit getVariable ["BR_var_lootStops", 0]) >= (_unit getVariable ["BR_var_lootStopsWanted", 0])}}) exitWith {false};
    if (time < (_unit getVariable ["BR_var_aiNextScavenge", 0])) exitWith {false};
    if ([_unit] call BR_fnc_aiOutsideZone) exitWith {false};

    _unit setVariable ["BR_var_aiNextScavenge", time + ([BR_var_aiScavengeTime, BR_var_aiNeedyScavengeTime] select _needy)];

    if (_needy) exitWith {[_unit, _urgent] call BR_fnc_aiSeekWeapon};

    private _radius = [BR_var_aiScavengeRadius, BR_var_aiUrgentLootRadius] select _urgent;
    // the zone presses: only a building on the way (not one after another)
    private _ahead = [[], [_unit] call BR_fnc_aiZoneDestination] select _urgent;
    private _building = [_unit, _radius, _ahead] call BR_fnc_aiLootableBuilding;

    if (isNull _building) exitWith {false};

    private _detourTime = (_unit distance2D _building) / BR_var_aiTravelSpeed + 8;
    if ((([getPosATL _unit] call BR_fnc_zoneEdgeTime) - serverTime) < _detourTime + 10) exitWith {false};

    [_unit, _building] call BR_fnc_aiStartLootRun;
    true
};

/*
    Holding at its zone spot with time left (BR_fnc_aiHoldTick): a loot run into the nearest unsearched building around
    that lies well inside the next zone, whatever it has already. True if a run started.
*/
BR_fnc_aiIdleLoot = {
    params ["_unit"];

    if (time < (_unit getVariable ["BR_var_aiNextIdleLoot", 0])) exitWith {false};

    _unit setVariable ["BR_var_aiNextIdleLoot", time + BR_var_aiIdleLootInterval];

    if ([_unit] call BR_fnc_aiNeedsGear && {[_unit, false] call BR_fnc_aiSeekWeapon}) exitWith {true};

    BR_var_zone params ["", "", "", "", "_nextCenter", "_nextRadius"];

    private _visited = _unit getVariable ["BR_var_aiVisited", []];
    private _building = (([_unit, BR_var_aiLootRadius] call BR_fnc_lootBuildingsNear) select {
        !(_x in _visited) &&
        {!([_x, "BR_var_aiUnreachable", false] call BR_fnc_bGet)} &&
        {!([_x, _unit] call BR_fnc_aiLootClaimed)} &&
        {(_x distance2D _nextCenter) < _nextRadius * BR_var_aiIdleLootZoneShare} &&
        {[_x] call BR_fnc_isLootBuilding}
    }) param [0, objNull];

    if (isNull _building) exitWith {false};

    [_unit, _building] call BR_fnc_aiStartLootRun;
    true
};

// the nearest building within _radius with loot spots that the unit did not search yet (objNull if none)
BR_fnc_aiLootableBuilding = {
    params ["_unit", "_radius", ["_ahead", []], ["_freshOnly", false], ["_best", false]];

    private _visited = _unit getVariable ["BR_var_aiVisited", []];
    private _wayDir = if (_ahead isEqualTo []) then {0} else {_unit getDir _ahead};

    private _candidates = ([_unit, _radius] call BR_fnc_lootBuildingsNear) select {
        !(_x in _visited) &&
        // one that caught an AI before (BR_fnc_aiCheckTrapped)
        {!([_x, "BR_var_aiTrap", false] call BR_fnc_bGet)} &&
        {!([_x, "BR_var_aiUnreachable", false] call BR_fnc_bGet)} &&
        {[_x] call BR_fnc_isLootBuilding} &&
        {!([_x, _unit] call BR_fnc_aiLootClaimed)} &&
        // not one somebody emptied (a third of the loot runs went into empty houses)
        {([_x, "BR_var_lootState", ""] call BR_fnc_bGet) != "spawned" || {!_freshOnly && {([_x] call BR_fnc_buildingLootHolders) isNotEqualTo []}}} &&
        {_ahead isEqualTo [] || {abs ((((_unit getDir _x) - _wayDir) + 540) % 360 - 180) < BR_var_aiUrgentLootAngle}}
    };

    if (!_best || {count _candidates < 2}) exitWith {_candidates param [0, objNull]};

    // _best (an AI without weapon): the most loot spots for the way, not just the nearest (on Chernarus the nearest are
    // mostly sheds with 4 spots of the lowest tier)
    private _score = _candidates apply {
        (([_x] call BR_fnc_buildingLootQuality) select 1) / ((_unit distance2D _x) + BR_var_aiNeedyBuildingWay)
    };
    _candidates select (_score find (selectMax _score))
};

/*
    True while another AI searches the building (BR_fnc_aiStartLootRun claims it): up to a dozen AI land at one drop spot
    and would all run to the nearest house, where the first takes everything
*/
BR_fnc_aiLootClaimed = {
    params ["_building", "_unit"];

    private _claimer = [_building, "BR_var_aiLootClaim", objNull] call BR_fnc_bGet;

    !isNull _claimer && {_claimer isNotEqualTo _unit} && {alive _claimer} &&
    {(_claimer getVariable ["BR_var_aiLootBuilding", objNull]) isEqualTo _building ||
        {(_claimer getVariable ["BR_var_aiLooseLoot", objNull]) isEqualTo _building}}
};

// loose loot (a holder, a body) the unit walks to and takes from (BR_fnc_aiLooseLootTick), claimed like a building
BR_fnc_aiGoForLooseLoot = {
    params ["_unit", "_source"];

    [_source, "BR_var_aiLootClaim", _unit] call BR_fnc_bSet;
    _unit setVariable ["BR_var_aiLooseLoot", _source];
    _unit setVariable ["BR_var_aiLooseLootUntil",
        time + BR_var_aiLooseLootTime + ((_unit distance2D _source) min BR_var_aiWeaponSeekMax) / BR_var_aiTravelSpeed];
};

// a primary weapon class (rifle, machine gun, sniper rifle, shotgun): CfgWeapons type 1
BR_fnc_isPrimaryClass = {
    params ["_class"];
    getNumber (configFile >> "CfgWeapons" >> _class >> "type") == 1
};

/*
    The nearest primary weapon lying within _radius that the unit could take (objNull if none): in a loot holder or a
    dropped weapon holder, or still on a body; for a unit with a primary but no ammo also ammo for it.
*/
BR_fnc_aiWeaponSource = {
    params ["_unit", "_radius"];

    private _magazines = (magazines _unit) apply {toLowerANSI _x};
    private _primary = primaryWeapon _unit;
    private _team = _unit getVariable ["BR_var_teamId", -1];
    private _sources = nearestObjects [_unit, ["GroundWeaponHolder", "WeaponHolderSimulated", "WeaponHolder", "CAManBase"], _radius];
    private _index = _sources findIf {
        private _source = _x;
        time > (_source getVariable ["BR_var_aiRetryAfter", 0]) &&
        {!([_source, _unit] call BR_fnc_aiLootClaimed)} &&
        {!surfaceIsWater (getPosATL _source)} &&
        {
            if (_source isKindOf "CAManBase") then {
                !alive _source && {!(_source getVariable ["BR_var_lootTransferred", false])} &&
                {_team < 0 || {(_source getVariable ["BR_var_teamId", -2]) != _team}} &&
                {primaryWeapon _source != ""}
            } else {
                (((weaponCargo _source) findIf {[_x] call BR_fnc_isPrimaryClass}) != -1 ||
                {_primary != "" && {!([_primary, _magazines] call BR_fnc_aiHasAmmoFor)} &&
                    {[_primary, (magazineCargo _source) apply {toLowerANSI _x}] call BR_fnc_aiHasAmmoFor}}) &&
                {
                    private _building = nearestBuilding _source;
                    !([_building, "BR_var_aiTrap", false] call BR_fnc_bGet) && {!([_source, _building] call BR_fnc_aiUpLadder)}
                }
            }
        }
    };

    _sources param [_index, objNull]
};

/*
    Without weapon or ammo: to the nearest weapon lying around (BR_fnc_aiWeaponSource) or into the nearest fresh building
    (no loot spawned yet), whichever is closer, if the zone leaves time for the detour. True if the unit got a target.
*/
BR_fnc_aiSeekWeapon = {
    params ["_unit", "_urgent"];

    // "urgent" starts for everyone outside the next circle once it shrinks, with the edge often minutes away. Urgent, it
    // looks as far as the time to the edge allows (there and on: half of the slack after the fixed costs), at least
    // 30 m. Calm, it looks up to BR_var_aiWeaponSeekMax (the nearest source still wins).
    private _slack = ([getPosATL _unit] call BR_fnc_zoneEdgeTime) - serverTime;
    private _radius = (((_slack - 25) * BR_var_aiTravelSpeed / 2) min
        ([BR_var_aiWeaponSeekMax, BR_var_aiWeaponSeekRadius] select _urgent)) max BR_var_aiUrgentLootRadius;
    private _source = [_unit, _radius] call BR_fnc_aiWeaponSource;
    private _building =[_unit, _radius,[],
        true, true] call BR_fnc_aiLootableBuilding;
    private _target = if(!isNull _source &&
        {isNull _building ||
        {(_unit distance2D _source) <(_unit distance2D _building) + 40}}) then {_source} else {_building};

    if (isNull _target) exitWith {false};

    private _detourTime = (_unit distance2D _target) / BR_var_aiTravelSpeed + 15;
    if ((([getPosATL _unit] call BR_fnc_zoneEdgeTime) - serverTime) < _detourTime + 10) exitWith {false};

    if (_target isEqualTo _source) then {
        [_unit, _source] call BR_fnc_aiGoForLooseLoot;
    } else {
        [_unit, _building] call BR_fnc_aiStartLootRun;
    };
    true
};

// the building's loot lies there from now on (if nobody came close before)
BR_fnc_aiStartLootRun = {
    params ["_unit", "_building"];

    [_building, "BR_var_aiLootClaim", _unit] call BR_fnc_bSet;

    if (([_building, "BR_var_lootState", ""] call BR_fnc_bGet) in ["", "cached"]) then {
        [_building] call BR_fnc_spawnBuildingLoot;
    };

    _unit setVariable ["BR_var_aiLootBuilding", _building];
    _unit setVariable ["BR_var_aiLootHolder", objNull];
    _unit setVariable ["BR_var_aiLootSkipped", []];
    _unit setVariable ["BR_var_aiLootMisses", 0];
    _unit setVariable ["BR_var_aiLootTook", false];
    // the run ends when the unit is drawn this far away: at least BR_var_aiLootRadius, farther for a building that was
    // farther away at the start (an unarmed AI goes up to BR_var_aiWeaponSeekMax)
    _unit setVariable ["BR_var_aiLootRunReach", ((_unit distance2D _building) + 30) max BR_var_aiLootRadius];
};

/*
    A loot run in progress: to the building's loot holders one after another, taking what the unit can use
    (BR_fnc_aiTakeLoot); true while busy. It ends when nothing is left, the unit was drawn far away or the zone presses
    an armed unit; the building then counts as searched.
*/
BR_fnc_aiLootRunTick = {
    params ["_unit", "_urgent"];

    private _building = _unit getVariable ["BR_var_aiLootBuilding", objNull];

    if (isNull _building) exitWith {false};

    // outside of the circle, drawn away, or the zone presses and the building is no longer right here: the run ends
    if (
        (_urgent && {_unit distance2D _building > BR_var_aiUrgentLootRadius} && {!([_unit] call BR_fnc_aiNeedsGear)}) ||
        {_unit distance2D _building > (_unit getVariable ["BR_var_aiLootRunReach", BR_var_aiLootRadius])} ||
        {[_unit] call BR_fnc_aiOutsideZone}
    ) exitWith {
        [_unit] call BR_fnc_aiEndLootRun;
        false
    };

    private _holder = _unit getVariable ["BR_var_aiLootHolder", objNull];

    if (isNull _holder) then {
        _holder = [_unit, _building] call BR_fnc_aiNextLootHolder;
        _unit setVariable ["BR_var_aiLootHolder", _holder];
        // the time for the holder grows with the way to it (a holder 150 m away needs more than BR_var_aiLootTimeout)
        _unit setVariable ["BR_var_aiLootStart", time + ((_unit distance2D _holder) min (_unit getVariable ["BR_var_aiLootRunReach", BR_var_aiLootRadius])) / BR_var_aiTravelSpeed];
        _unit setVariable ["BR_var_aiLootProgress", [_unit distance _holder, time]];
    };

    if (isNull _holder) exitWith {
        [_unit] call BR_fnc_aiEndLootRun;
        false
    };

    if !([_unit, _holder] call BR_fnc_aiReachesHolder) exitWith {
        (_unit getVariable ["BR_var_aiLootProgress", [1e9, time]]) params ["_distance", "_progressAt"];
        private _nowDistance = _unit distance _holder;
        // progress counts only close by: farther away the way is watched by BR_fnc_aiCheckStuck (BR_fnc_aiMoveTo). With
        // ~150 AI the engine often plans a way for more than 8 s, and each new holder ordered anew restarts the
        // planning
        if (_nowDistance < _distance - 1 || {_unit distance2D _holder > BR_var_aiLootNearDistance}) then {
            _progressAt = time;
            _unit setVariable ["BR_var_aiLootProgress", [_nowDistance, time]];
        };
        private _slack = ([getPosATL _unit] call BR_fnc_zoneEdgeTime) - serverTime;
        private _worthTime = ((BR_var_aiLootProgressTime select ([_unit] call BR_fnc_aiNeedsGear)) min (_slack - 10)) max 0;
        if (time - _progressAt > _worthTime ||
            {time - (_unit getVariable ["BR_var_aiLootStart", time]) > ([BR_var_aiLootTimeout, BR_var_aiUrgentLootTimeout] select _urgent)}) then {
            [_unit, _holder] call BR_fnc_aiSkipLootHolder;
            // holders it cannot reach one after another (e.g. a radar mast's platform 8-10 m up): the building is given
            // up
            private _misses = (_unit getVariable ["BR_var_aiLootMisses", 0]) + 1;
            _unit setVariable ["BR_var_aiLootMisses", _misses];
            if (_misses >= BR_var_aiLootMaxMisses) then {[_unit] call BR_fnc_aiEndLootRun};
        } else {
            [_unit, getPosATL _holder] call BR_fnc_aiMoveTo;
        };

        true
    };

    // setUnitLoadout cannot apply during a weapon switch. Retry this holder instead of marking its loot handled.
    if (isSwitchingWeapon _unit || {_unit getVariable ["BR_var_bandaging", false]}) exitWith {true};
    [_unit, _holder] call BR_fnc_aiTakeLoot;
    [_unit, _holder] call BR_fnc_aiSkipLootHolder;
    _unit setVariable ["BR_var_aiLootMisses", 0];
    _unit setVariable ["BR_var_aiLootTook", true];
    true
};

// close enough to the holder to take from it: on its floor and within reach - farther once it tried for a while
BR_fnc_aiReachesHolder = {_this call BR_fnc_aiCanReachLoot};

// Needy units prefer a usable primary or its ammo, then an unloaded primary; distance breaks ties.
// Otherwise the nearest unhandled holder wins (objNull if none).
BR_fnc_aiNextLootHolder = {
    params ["_unit", "_building"];

    private _skipped = _unit getVariable ["BR_var_aiLootSkipped", []];
    private _nearest = objNull;
    private _nearestDistance = 1e9;
    private _needy = [_unit] call BR_fnc_aiNeedsGear;
    private _bestPriority = -1;
    private _carriedMagazines = (magazines _unit) apply {toLowerANSI _x};
    private _primary = primaryWeapon _unit;

    {
        private _distance = _unit distance _x;
        private _priority = 0;

        // Get a usable primary before spending time on clothing, pistols or inaccessible decoration loot.
        // Only inspect real cargo; taking it still requires reaching the holder on its floor.
        if (_needy) then {
            private _magazines = _carriedMagazines + ((magazineCargo _x) apply {toLowerANSI _x});

            if ((weaponCargo _x findIf {
                ([_x] call BR_fnc_lootCategory) == "primaries" && {[_x, _magazines] call BR_fnc_aiHasAmmoFor}
            }) != -1) then {
                _priority = 2;
            } else {
                if (_primary != "" && {[_primary, _magazines] call BR_fnc_aiHasAmmoFor}) then {
                    _priority = 2;
                } else {
                    if ((weaponCargo _x findIf {([_x] call BR_fnc_lootCategory) == "primaries"}) != -1) then {
                        _priority = 1;
                    };
                };
            };
        };

        if (!(_x in _skipped) && {_priority > _bestPriority || {_priority == _bestPriority && {_distance < _nearestDistance}}}) then {
            _nearest = _x;
            _nearestDistance = _distance;
            _bestPriority = _priority;
        };
    } forEach (([_building] call BR_fnc_buildingLootHolders) select {!([_x, _building] call BR_fnc_aiUpLadder)});

    _nearest
};

/*
    True if the holder lies up a ladder of its building: above the floor the lowest ladder (config ladders[]) starts on
    and at about its top or higher. AI on ladders fall - two died getting loot from a sawmill tower and a workshop roof
    (Chernarus) - so that loot is left to players. [bottom, top] of the lowest ladder in model space, cached per type.
*/
BR_var_aiLadderCache = createHashMap;
BR_fnc_aiUpLadder = {
    params ["_holder", "_building"];

    if (isNull _building) exitWith {false};

    private _type = typeOf _building;
    private _ladder = BR_var_aiLadderCache get _type;

    if (isNil "_ladder") then {
        _ladder = [];
        {
            if (_x isEqualType [] && {count _x >= 2}) then {
                private _heights = (_x select [0, 2]) apply {(_building selectionPosition [_x, "Memory"]) select 2};
                // a ladder without both memory points (selectionPosition [0, 0, 0]) is no ladder to go by
                if (abs ((_heights select 0) - (_heights select 1)) > 1 &&
                    {_ladder isEqualTo [] || {(selectMax _heights) < (_ladder select 1)}}) then {
                    _ladder = [selectMin _heights, selectMax _heights];
                };
            };
        } forEach getArray (configOf _building >> "ladders");
        BR_var_aiLadderCache set [_type, _ladder];
    };

    if (_ladder isEqualTo []) exitWith {false};

    private _height = (_building worldToModel ASLToAGL getPosASL _holder) select 2;

    _height > (_ladder select 0) + BR_var_aiLootFloorHeight && {_height >= (_ladder select 1) - BR_var_aiLootFloorHeight}
};

BR_fnc_aiSkipLootHolder = {
    params ["_unit", "_holder"];

    _unit setVariable ["BR_var_aiLootSkipped", (_unit getVariable ["BR_var_aiLootSkipped", []]) + [_holder]];
    _unit setVariable ["BR_var_aiLootHolder", objNull];
};

BR_fnc_aiEndLootRun = {
    params ["_unit"];

    // a run that reached no holder at all counts against the building; after BR_var_aiLootMaxFails such runs (by any
    // AI) no AI goes there again (e.g. castle walls with their loot up on the wall, a radar mast's platform)
    private _building = _unit getVariable ["BR_var_aiLootBuilding", objNull];
    if (!isNull _building && {!(_unit getVariable ["BR_var_aiLootTook", false])}) then {
        private _fails = ([_building, "BR_var_aiLootFails", 0] call BR_fnc_bGet) + 1;
        [_building, "BR_var_aiLootFails", _fails] call BR_fnc_bSet;
        if (_fails >= BR_var_aiLootMaxFails) then {[_building, "BR_var_aiUnreachable", true] call BR_fnc_bSet};
    };

    _unit setVariable ["BR_var_aiVisited", (_unit getVariable ["BR_var_aiVisited", []]) + [_unit getVariable ["BR_var_aiLootBuilding", objNull]]];
    _unit setVariable ["BR_var_lootStops", (_unit getVariable ["BR_var_lootStops", 0]) + 1];
    _unit setVariable ["BR_var_aiLootBuilding", objNull];
    _unit setVariable ["BR_var_aiLootHolder", objNull];
};

// ---- taking loot ----

/*
    Takes what the unit can use from a loot container (holder, supply crate) and leaves the rest: a backpack, vest or
    helmet and useful upgrades, contextually better weapons, bounded supplies and suitable attachments.
    Full weapon/container states and unused loot are preserved. Returns the number of objects taken.
*/
// whether one of _magazines (lower case) fits _weapon
BR_fnc_aiHasAmmoFor = {
    params ["_weapon", "_magazines"];

    private _compatible = [_weapon] call BR_fnc_weaponMagazines;

    (_magazines findIf {_x in _compatible}) != -1
};

BR_fnc_aiTakeLoot = {
    params ["_unit", "_source", ["_rearm", false]];
    private _taken = 0;
    // Unscheduled transaction: no competing AI or inventory update can duplicate a cargo snapshot.
    isNil {
        if (_source isKindOf "CAManBase") then {
            if (!alive _source && {[_unit, _source] call BR_fnc_aiCanReachLoot}) then {
                _source = [_source, _unit] call BR_fnc_aiCorpseLoot;
            } else {_source = objNull};
        };
        if (!isNull _source) then {_taken = [_unit, _source, _rearm] call BR_fnc_aiTakeGear};
    };
    _taken
};

// Recovery sources must be reached physically, just like an ordinary loot holder.
BR_fnc_aiRearmNearby = {
    params ["_unit"];
    private _sources = (nearestObjects [_unit, ["WeaponHolder", "WeaponHolderSimulated", "CAManBase"], BR_var_aiRearmRadius]) select {
        !(_x isKindOf "CAManBase") || {!alive _x && {!(_x getVariable ["BR_var_lootTransferred", false])}}
    };
    private _taken = 0;
    {
        if ([_unit, _x] call BR_fnc_aiCanReachLoot) then {_taken = _taken + ([_unit, _x, true] call BR_fnc_aiTakeLoot)};
    } forEach _sources;
    if (_taken == 0) then {
        private _source = (_sources select {
            ([objNull, "GEOM", _x] checkVisibility [eyePos _unit,
                if(_x isKindOf "CAManBase") then {eyePos _x} else {(getPosASL _x) vectorAdd [0, 0,
                0.2]}]) > 0 &&
            {time > (_x getVariable ["BR_var_aiRetryAfter", 0])}
        }) param [0, objNull];
        if (!isNull _source) then {
            [_unit, _source] call BR_fnc_aiGoForLooseLoot;
        };
    };
    _taken
};

// Recovery loot is approached normally, on its floor. No 50 m pickup through walls.
BR_fnc_aiLooseLootTick = {
    params ["_unit", "_urgent"];
    private _source = _unit getVariable ["BR_var_aiLooseLoot", objNull];
    if (isNull _source) exitWith {false};
    // the zone presses: an armed unit leaves it; an unarmed one keeps going (BR_fnc_aiSeekWeapon checked the time - it
    // dropped every weapon it went for at once before and stayed unarmed)
    if ((_urgent && {!([_unit] call BR_fnc_aiNeedsGear)}) || {time > (_unit getVariable ["BR_var_aiLooseLootUntil", time])} || {[_source, _unit] call BR_fnc_aiLootClaimed}) exitWith {
        _source setVariable ["BR_var_aiRetryAfter", time + ([30, BR_var_aiWeaponSeekRetry] select ([_unit] call BR_fnc_aiNeedsGear))];
        _unit setVariable ["BR_var_aiLooseLoot", objNull];
        false
    };
    if ([_unit, _source] call BR_fnc_aiCanReachLoot) exitWith {
        if (isSwitchingWeapon _unit || {_unit getVariable ["BR_var_bandaging", false]}) exitWith {true};
        [_unit, _source] call BR_fnc_aiTakeLoot;
        _unit setVariable ["BR_var_aiLooseLoot", objNull];
        true
    };
    [_unit, getPosATL _source] call BR_fnc_aiMoveTo;
    true
};

// ---- supply crates ----

/*
    A landed supply crate with loot inside the next zone within BR_var_aiCrateRadius: the unit goes there and takes what
    it can use. At most BR_var_aiCrateTeams teams go for one crate, a unit the zone presses leaves crates alone. True
    while the unit heads for a crate.
*/
BR_fnc_aiCrateTick = {
    params ["_unit", "_urgent"];

    private _crate = _unit getVariable ["BR_var_aiCrate", objNull];

    if (isNull _crate && {!_urgent} && {time >= (_unit getVariable ["BR_var_aiNextCrateCheck", 0])}) then {
        _unit setVariable ["BR_var_aiNextCrateCheck", time + BR_var_aiCrateCheckInterval];
        _crate = [_unit] call BR_fnc_aiPickCrate;

        if (!isNull _crate) then {
            [_unit, _crate] call BR_fnc_aiClaimCrate;
        };
    };

    if (isNull _crate) exitWith {false};

    if (_urgent || {!([_crate] call BR_fnc_aiCrateWanted)} || {time - (_unit getVariable ["BR_var_aiCrateSince", time]) > BR_var_aiCrateTimeout}) exitWith {
        [_unit, _crate] call BR_fnc_aiLeaveCrate;
        false
    };

    if !([_unit, _crate] call BR_fnc_aiCanReachLoot) exitWith {
        // Approach an accessible side, not the blocked centre of the crate.
        [_unit, _crate getPos [2.5, _crate getDir _unit]] call BR_fnc_aiMoveTo;
        true
    };

    if (isSwitchingWeapon _unit || {_unit getVariable ["BR_var_bandaging", false]}) exitWith {true};
    [_unit, _crate] call BR_fnc_aiTakeLoot;
    [_unit, _crate] call BR_fnc_aiLeaveCrate;
    true
};

// a landed crate with loot inside the next zone
BR_fnc_aiCrateWanted = {
    params ["_crate"];

    BR_var_zone params ["", "", "", "", "_nextCenter", "_nextRadius"];

    !isNull _crate &&
    {isNull attachedTo _crate} &&
    {(_crate distance2D _nextCenter) <= _nextRadius} &&
    {([_crate] call BR_fnc_cargoCount) > 0}
};

// the nearest wanted crate in reach that the unit did not visit yet and that its team may go for
BR_fnc_aiPickCrate = {
    params ["_unit"];

    private _teamId = _unit getVariable ["BR_var_teamId", -1];
    private _visited = _unit getVariable ["BR_var_aiCratesVisited", []];
    private _nearest = objNull;
    private _nearestDistance = BR_var_aiCrateRadius;

    {
        private _crate = _x;
        private _teams = [];
        // Claims belong to living units still heading for this crate, not to every team that ever visited it.
        // Otherwise the first two teams permanently lock everybody else out, even after dying or leaving.
        {
            if (alive _x && {(_x getVariable ["BR_var_aiCrate", objNull]) isEqualTo _crate} &&
                {time - (_x getVariable ["BR_var_aiCrateSince", time]) <= BR_var_aiCrateTimeout}) then {
                _teams pushBackUnique (_x getVariable ["BR_var_teamId", -1]);
            };
        } forEach BR_var_rosterUnits;
        _crate setVariable ["BR_var_aiCrateTeams", _teams];
        private _distance = _unit distance2D _x;

        if (
            _distance < _nearestDistance &&
            {!(_x in _visited)} &&
            {_teamId in _teams || {count _teams < BR_var_aiCrateTeams}} &&
            {[_x] call BR_fnc_aiCrateWanted}
        ) then {
            _nearest = _x;
            _nearestDistance = _distance;
        };
    } forEach (BR_var_airdropCrates - [objNull]);

    _nearest
};

BR_fnc_aiClaimCrate = {
    params ["_unit", "_crate"];

    private _teams = _crate getVariable ["BR_var_aiCrateTeams", []];

    _teams pushBackUnique (_unit getVariable ["BR_var_teamId", -1]);
    _crate setVariable ["BR_var_aiCrateTeams", _teams];
    _unit setVariable ["BR_var_aiCrate", _crate];
    _unit setVariable ["BR_var_aiCrateSince", time];
};

BR_fnc_aiLeaveCrate = {
    params ["_unit", "_crate"];

    _unit setVariable ["BR_var_aiCratesVisited", (_unit getVariable ["BR_var_aiCratesVisited", []]) + [_crate]];
    _unit setVariable ["BR_var_aiCrate", objNull];
};
