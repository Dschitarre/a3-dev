// AI spawning with a rank based loadout and vehicle (server).

// ---- spawning ----

// a class matches a filter [prefixes, substrings, excluded substrings] if it starts with one of the prefixes
// (case-insensitive) or contains one of the substrings, and contains none of the excluded substrings
SC_fnc_classMatchesFilter = {
    params ["_class", "_filter"];
    _filter params [["_prefixes", []], ["_substrings", []], ["_excludes", []]];

    (
        ((_prefixes findIf {(_class select [0, count _x]) == _x}) != -1) ||
        {(_substrings findIf {(_class find _x) != -1}) != -1}
    ) &&
    {(_excludes findIf {(_class find _x) != -1}) == -1}
};

// item [class, rank] whose rank is closest to a random rank between 1 and _rank ([] if there is none)
SC_fnc_pickItemNearRandomRank = {
    params ["_items", "_rank"];

    private _preferredRank = 1 max (round (_rank * (random 1)));
    private _bestItemYet = [];
    private _bestDeviationYet = 999;

    {
        private _deviation = abs ((_x select 1) - _preferredRank);

        if (_deviation < _bestDeviationYet) then {
            _bestItemYet = _x;
            _bestDeviationYet = _deviation;
        };
    } forEach _items;

    _bestItemYet
};

// primary weapons: no handguns, launchers or the underwater rifle
SC_fnc_isAiPrimaryWeapon = {
    params ["_class"];

    private _type = ([_class] call SC_fnc_getItemType) select 1;

    (_class != "arifle_SDAR_F") && {_type != "Handgun"} && {(_type find "Launcher") == -1}
};

SC_fnc_isAiLauncher = {
    params ["_class"];

    ((([_class] call SC_fnc_getItemType) select 1) find "Launcher") != -1
};

SC_fnc_isAiHandgun = {
    params ["_class"];

    (([_class] call SC_fnc_getItemType) select 1) == "Handgun"
};

// random weapon (of a random variant group) that matches _filter: [weapon, its magazines among _mags], or [] if none
SC_fnc_pickAiWeapon = {
    params ["_groupedWeapons", "_mags", "_filter"];

    private _candidates = (_groupedWeapons apply {_x select 0}) select {[_x select 0] call _filter};

    if (_candidates isEqualTo []) exitWith {[]};

    private _candidate = selectRandom _candidates;
    private _weapon = (selectRandom (_groupedWeapons select (_groupedWeapons findIf {_candidate in _x}))) select 0;

    [_weapon, _mags arrayIntersect (getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines"))]
};

// whether a unit with these perks gets a primary weapon: the low-rank weapons of a perk can all belong to a DLC that
// is not loaded (e.g. the marksman rifles of ranks 7-9 are Reaction Forces weapons)
SC_fnc_hasAiPrimaryWeapon = {
    params ["_side", "_perks", "_rank"];

    ((([_side, _perks, _rank,
        true] call SC_fnc_getItemsUniqueAndGrouped) select 2) findIf {[(_x select 0) select 0] call
        SC_fnc_isAiPrimaryWeapon}) != -1
};

// AI never get explosives (mines, charges, claymores, IEDs), laser designators and their batteries, or smoke magazines
// from the item pools (colored hand smoke, GL / shotgun smoke rounds: grenadiers keep HE); their hand smoke is the
// white SmokeShell added in SC_fnc_spawnAi
SC_var_aiExcludedItemTypes = ["Mine", "MineBounding", "MineDirectional", "LaserDesignator", "SmokeShell"];

SC_fnc_isAiItemAllowed = {
    params ["_class"];

    ([_class] call SC_fnc_getItemType) params ["_category", "_type"];

    (_category != "Mine") &&
    {!(_type in SC_var_aiExcludedItemTypes)} &&
    {_class != "Laserbatteries"} &&
    {((toLower _class) find "smoke") == -1}
};

SC_fnc_addAiMagazines = {
    params ["_unit", "_mags", "_count"];

    if (_mags isEqualTo []) exitWith {};

    for "_i" from 1 to _count do {
        _unit addMagazineGlobal (selectRandom _mags);
    };
};

// objective of a fire team, else the one of another fire team of its SC group (a lone AI that just spawned has none
// yet), "" if there is none
SC_fnc_aiSquadTarget = {
    params ["_group"];

    private _target = _group getVariable ["SC_var_aiTarget", ""];

    if (_target != "") exitWith {_target};

    {
        private _mateTarget = (group _x) getVariable ["SC_var_aiTarget", ""];

        if (!(isPlayer _x) && {_mateTarget != ""}) exitWith {
            _target = _mateTarget;
        };
    } forEach ([leader _group] call SC_fnc_getGroupUnits);

    _target
};

// spawn points that many own units are near or where many AI of the side spawned lately count as farther away (so the
// spawns spread): per own unit within SC_var_aiSpawnCrowdRadius m this share of the sector spacing, per AI spawn there
// in the last SC_var_aiSpawnRecentTime seconds this share
SC_var_aiSpawnCrowdRadius = 100;
SC_var_aiSpawnCrowdPenalty = 0.05;
SC_var_aiSpawnRecentTime = 60;
SC_var_aiSpawnRecentPenalty = 0.15;

// the AI spawns at the spawn points: [side, position, time]
SC_var_aiRecentSpawns = [];

// spawn point of an AI that doesn't spawn at a group mate: of the own sectors, the base and the usable mobile spawn
// vehicles of the side (SC\vehicles\spawnVehicles.sqf), one of those closest to its squad's objective (or to the front:
// the sectors the side doesn't own), mostly the closest one; crowded spawn points and ones with many spawns lately
// count as farther away. With _withVehicle (the AI gets a vehicle for its squad at the base) the way from the base
// counts as shorter (SC_var_aiVehicleTripScale). A marker name or a spawn vehicle; the spawn is remembered.
// Modes may restrict every spawn route, including group mates and mobile spawns.
SC_fnc_aiSpawnPointAllowed = {true};
SC_fnc_aiSpawnGoals = {
    params ["_side"];
    (SC_var_sectors select {(missionNamespace getVariable ("SC_var_owner" + _x)) != _side}) apply {getMarkerPos ("SC_var_sector" + _x)}
};

SC_fnc_aiChooseSpawnPoint = {
    params ["_side", "_group", ["_withVehicle", false]];

    private _baseMarker = "SC_var_" + (toLower (str _side)) + "Respawn";
    private _spawnPoints = [_baseMarker] +
        ((SC_var_sectors select {(missionNamespace getVariable ("SC_var_owner" + _x)) == _side}) apply {"SC_var_sector" + _x}) +
        ([_side] call SC_fnc_getUsableSpawnVehicles);
    _spawnPoints=_spawnPoints select {[_side,_x] call SC_fnc_aiSpawnPointAllowed};
    private _target = [_group] call SC_fnc_aiSquadTarget;
    if (_target!="" && {!([_side,"SC_var_sector"+_target] call SC_fnc_aiSpawnPointAllowed)}) then {_target=""};
    private _goals = if (_target != "") then {
        [getMarkerPos ("SC_var_sector" + _target)]
    } else {
        [_side] call SC_fnc_aiSpawnGoals
    };

    if (_goals isEqualTo []) exitWith {selectRandom _spawnPoints};

    SC_var_aiRecentSpawns = SC_var_aiRecentSpawns select {(time - (_x select 2)) < SC_var_aiSpawnRecentTime};
    private _recent = (SC_var_aiRecentSpawns select {(_x select 0) == _side}) apply {_x select 1};

    private _sorted = [_spawnPoints, [], {
        private _pointPos = if (_x isEqualType "") then {getMarkerPos _x} else {getPosWorld _x};
        private _distance = selectMin (_goals apply {_x distance2D _pointPos});

        if (_withVehicle && {_x isEqualTo _baseMarker} && {_distance > SC_var_aiVehicleUseDistance}) then {
            SC_var_aiVehicleTripScale params ["_factor", "_fixed"];
            _distance = _fixed + (_factor * _distance);
        };

        private _ownNear = {(alive _x) && {(side (group _x)) == _side}} count (_pointPos nearEntities ["CAManBase", SC_var_aiSpawnCrowdRadius]);
        private _spawnsNear = {(_x distance2D _pointPos) < SC_var_aiSpawnCrowdRadius} count _recent;

        _distance + (SC_var_aiSectorSpacing * ((SC_var_aiSpawnCrowdPenalty * _ownNear) + (SC_var_aiSpawnRecentPenalty * _spawnsNear)))
    }, "ASCEND"] call BIS_fnc_sortBy;

    private _spawnPoint = _sorted select (floor (random [0, 0.4, ((count _sorted) min 3) - 0.01]));

    SC_var_aiRecentSpawns pushBack [_side,
        (if(_spawnPoint isEqualType "") then {getMarkerPos _spawnPoint} else {getPosWorld _spawnPoint}),
        time];

    _spawnPoint
};

// for the choice of the spawn point a way from the base by vehicle counts
// like a walk of [factor, fixed part (m)] of its length: a vehicle is about 3 times as fast, and the base is preferred
// a bit while the AI of the side may spawn vehicles (so that it keeps using some)
SC_var_aiVehicleTripScale = [0.25, 50];

// distance from a position to its squad's objective, or to the nearest sector the side doesn't own (0 if none)
SC_fnc_aiDistanceToGoal = {
    params ["_pos", "_side", "_group"];

    private _target = [_group] call SC_fnc_aiSquadTarget;
    private _goals = if (_target != "") then {[_target]} else {
        SC_var_sectors select {(missionNamespace getVariable ("SC_var_owner" + _x)) != _side}
    };

    if (_goals isEqualTo []) exitWith {0};

    // Match squad movement's distance to the sector edge. Measuring to its centre could request
    // transport at the base, then immediately choose to walk because the capture area was already near.
    0 max (selectMin (_goals apply {(_pos distance2D (getMarkerPos ("SC_var_sector" + _x)))-(selectMax getMarkerSize("SC_var_sector"+_x))}))
};

SC_fnc_spawnAi = {
    params ["_unit"];
    _side = side (group _unit);

    if !(_side in SC_var_sides) exitWith {};

    private _rank = _unit getVariable "SC_var_rank";

    // a spawn vehicle of the side waits at the base for a squad that moves it to the front (SC\ai\delivery.sqf): one
    // AI spawns there instead of at its squad, alone, it drives (the planning asks again if it is still needed)
    private _forDelivery = false;

    if !(isPlayer _unit) then {
        private _driverWantedVar = "SC_var_aiDeliveryDriverWanted" + (str _side);
        _forDelivery = missionNamespace getVariable [_driverWantedVar, false];
        missionNamespace setVariable [_driverWantedVar, false];
    };

    // into a fire team of its SC group (one riding a vehicle with a free seat, or a lone AI), else alone
    if _forDelivery then {
        if (((units (group _unit)) - [_unit]) isNotEqualTo []) then {
            [_unit] call SC_fnc_leaveSquad;
        };
    } else {
        [_unit, true] call SC_fnc_joinSquad;
    };
    _unit setVariable ["SC_var_name", ([_unit] call SC_fnc_getName), true];
    _unit setSkill (_unit getVariable "SC_var_aiSkill");

    // no radio protocol: the squad leaders' orders ("2, move to ...") would show in the players' chat
    _unit disableAI "RADIOPROTOCOL";

    // group mates it may spawn at: not under fire and no enemy close (SC_fnc_isSafeSpawnTarget, SC\init\common.sqf); if
    // none is, it spawns at a spawn point
    private _otherGroupUnits = (([_unit] call SC_fnc_getGroupUnits) - [_unit]) select {
        (alive _x) &&
        {!(_x getVariable ["ais_unconscious", false])} &&
        {(getPosWorld _x) inArea "SC_Var_playZone"} &&
        {[_x] call SC_fnc_isSafeSpawnTarget} &&
        {[_side,_x] call SC_fnc_aiSpawnPointAllowed} &&
        {
            !(surfaceIsWater (getPosWorld _x)) ||
            {
                private _parX = objectParent _x;
                !(isNull _parX) && {((fullCrew [_parX, "", true]) findIf {isNull (_x select 0)}) != -1}
            }
        }
    };
    // a player mate or a mate of its engine group (a ride it joined) in a vehicle with a free gunner / commander seat, a
    // mate of its ride in a free seat of the ride's vehicle, or next to an AI mate of its squad (SC group) on foot: it
    // always spawns at its squad; next to a player mate only sometimes
    private _seatMateIndex = _otherGroupUnits findIf {
        private _parGroupMate = objectParent _x;
        ((isPlayer _x) || {(group _x) isEqualTo (group _unit)}) &&
        {!(isNull _parGroupMate)} &&
        {(locked _parGroupMate) <= 1} &&
        {((fullCrew [_parGroupMate, "", true]) findIf {(isNull (_x select 0)) && {(_x select 1) in ["commander", "gunner", "turret"]}}) != -1}
    };
    private _squadMates = _otherGroupUnits select {!(isPlayer _x) && {isNull (objectParent _x)}};
    private _squadVehicle = [group _unit] call SC_fnc_aiGetSquadVehicle;
    private _squadVehicleMates = _otherGroupUnits select {((group _x) isEqualTo (group _unit)) &&
        {(objectParent _x) isEqualTo _squadVehicle} &&
        {((fullCrew [_squadVehicle, "", true]) findIf {isNull (_x select 0)}) != -1}};
    _spawnPos = [];
    private _groupSpawn = false;
    private _spawnMarker = "";
    private _baseMarker = "SC_var_" + (toLower (str _side)) + "Respawn";

    // a vehicle type for the size the squad has or will have (a lone AI gets a small one), if the AI of the side may
    // spawn one more vehicle and the squad has none
    private _vehicleType = if (isNull _squadVehicle) then {
        [_rank,(count ([_unit] call SC_fnc_getGroupUnits)) max ([_unit] call SC_fnc_getGroupTargetSize),
            _side] call SC_fnc_aiPickVehicleType
    } else {""};

    if(!_forDelivery &&
        {(_seatMateIndex != -1) || {_squadMates isNotEqualTo []} ||
        {(_otherGroupUnits isNotEqualTo []) &&
        {(random 1) <(0.3 *((count _otherGroupUnits) / 3))}}}) then {
        _groupSpawn = true;
        private _grpUnit = switch true do {
            case (_squadVehicleMates isNotEqualTo []): {_squadVehicleMates select 0};
            case (_seatMateIndex != -1): {_otherGroupUnits select _seatMateIndex};
            case(_squadMates isNotEqualTo []) : {[selectRandom _squadMates,
                leader (group _unit)] select ((leader (group _unit)) in _squadMates)};
            default {selectRandom _otherGroupUnits};
        };
        _spawnPos = getPosATL _grpUnit;

        if (isPlayer _unit) exitWith {};

        private _hdl = [_unit, _grpUnit] spawn SC_fnc_groupSpawn;
        waitUntil {scriptDone _hdl};
    } else {
        private _spawnPoint = [[_side, group _unit, _vehicleType != ""] call SC_fnc_aiChooseSpawnPoint, _baseMarker] select _forDelivery;
        ["spawnPoint", group _unit, (if (_spawnPoint isEqualType "") then {_spawnPoint} else {typeOf _spawnPoint}), _vehicleType] call SC_fnc_aiLog;

        if (_spawnPoint isEqualType objNull) exitWith {
            _spawnPos = getPosATL _spawnPoint;

            if !(isPlayer _unit) then {
                [_unit, _spawnPoint] call SC_fnc_moveUnitToSpawnVehicle;
            };
        };

        _spawnMarker = _spawnPoint;
        _spawnPos = getMarkerPos _spawnMarker;
        _semaphoreVar = "SC_var_unitSpawnSemaphore" + (toLower (str _side));

        if (isNil _semaphoreVar) exitWith {};

        waitUntil {
            [_semaphoreVar] call {
                params ["_semaphoreVar"];

                if !(missionNamespace getVariable _semaphoreVar) then {
                    missionNamespace setVariable [_semaphoreVar, true];
                    true
                } else {
                    false
                }
            }
        };

        private _safeSpawnPos = [];
        private _isBaseSpawn = "Respawn" in _spawnMarker;
        private _radius = 5;

        waitUntil {
            _safeSpawnPos = [_spawnPos, _radius] call BIS_fnc_randomPosTrigger;
            _radius = _radius * 1.05;

            _isBaseSpawn || {
                private _safePosAsl = _safeSpawnPos;
                _safePosAsl set [2, 0];
                _safePosAsl = AGLToASL _safePosAsl;
                _safePosAsl set [2, ((_safePosAsl select 2) + 0.5)];

                (([objNull, "VIEW"] checkVisibility [_safePosAsl, (_safePosAsl vectorAdd [0, 0, 100])]) != 0)
            }
        };

        _spawnPos = _safeSpawnPos;

        if (isPlayer _unit) exitWith {
            missionNamespace setVariable [_semaphoreVar, false];
        };

        _unit setPos _safeSpawnPos;

        missionNamespace setVariable [_semaphoreVar, false];
    };

    // the unit itself (perks, loadout, weapons) in one go: unscheduled it takes a few ms, in the scheduler it took
    // ~10 s and many parallel spawns starved the AI planning of the scheduler (squads stood until the fill ended)
    private _isMedic = false;

    isNil {
        // A front may change while a scheduled spawn waits for a seat or an empty position.
        if (!(isPlayer _unit) && {!([_side,_unit] call SC_fnc_aiSpawnPointAllowed)}) then {
            if (!isNull objectParent _unit) then {moveOut _unit};
            _unit setPosATL (getMarkerPos _baseMarker);
            _spawnPos=getPosATL _unit;
        };
        _unit hideObjectGlobal false;
        _unit enableSimulationGlobal true;
        _unit addPlayerScores [0, 0, 0, 0, 0];

        [_unit, false] call ADG_fnc_allowDamage;

        private _perks = [];

        // the Medic perk is rolled separately, AI never take the Explosives perk
        private _possiblePerks = (SC_var_perkConfig select {!((_x select 1) in ["MEDC", "DEMO"]) && {(_x select 2) <= _rank}}) apply {_x select 1};

        // weapon perks that would leave the unit without a primary weapon are not used
        _possiblePerks = _possiblePerks -(["MRKS", "MGNR", "GRND"] select {(_x in _possiblePerks) &&
            {!([_side,[_x], _rank] call SC_fnc_hasAiPrimaryWeapon)}});

        if ((_rank >= 7) && {_rank <= 50} && {"MRKS" in _possiblePerks} && {(random 1) < (((1 / 80) * ((_rank ^ 0.825) - 40)) + 0.5)}) then {
            _perks = ["MRKS"];
            _possiblePerks = _possiblePerks - ["MRKS", "MGNR", "GRND"];
        } else {
            private _exclusivePerks = ["MGNR", "GRND"] arrayIntersect _possiblePerks;

            if ((_rank > 50) && {"MRKS" in _possiblePerks}) then {
                _exclusivePerks pushBack "MRKS";
            };

            if ((count _exclusivePerks) > 1) then {
                _possiblePerks = _possiblePerks - (_exclusivePerks - [selectRandom _exclusivePerks]);
            };
        };

        if ((random 1) < 0.5) then {
            _perks pushBack "MEDC";
        };

        // AI use at most 5 perk slots
        _perks append ((_possiblePerks call BIS_fnc_arrayShuffle) select [0, ([_rank, 5] call SC_fnc_getNumPerkSlots) - (count _perks)]);
        private _isMarksman = "MRKS" in _perks;

        _isMedic = "MEDC" in _perks;
        ([_side, _perks, _rank, true] call SC_fnc_getItemsUniqueAndGrouped) params ["_items", "_mags", "_groupedWeapons", "_groupedOptics", "_groupedSuppressors"];
        _items = _items select {[_x select 0] call SC_fnc_isAiItemAllowed};
        _mags = _mags select {[_x] call SC_fnc_isAiItemAllowed};
        _unit setUnitLoadout SC_var_emptyLoadout;

        if (isPlayer _unit) exitWith {};

        private _uniform = [(_items select {
            if _isMarksman then {((_x select 0) find "hillie") != -1} else {
                [(_x select 0), (getArray (SC_var_worldGroupConfig >> "aiUniformFilter"))] call SC_fnc_classMatchesFilter
            }
        }), _rank] call SC_fnc_pickItemNearRandomRank;

        if (_uniform isNotEqualTo []) then {
            _unit forceAddUniform (_uniform select 0);
        };

        private _vest =[(_items select {[(_x select 0),
            (getArray (SC_var_worldGroupConfig >> "aiVestFilter"))] call SC_fnc_classMatchesFilter}),
            _rank] call SC_fnc_pickItemNearRandomRank;

        if (_vest isNotEqualTo []) then {
            _unit addVest (_vest select 0);
        };

        private _bag =[(_items select {((([_x select 0] call SC_fnc_getItemType) select 1) == "Backpack") &&
            {!("_Bergen_" in (_x select 0))}}), _rank] call SC_fnc_pickItemNearRandomRank;

        if (_bag isNotEqualTo []) then {
            _unit addBackpackGlobal (_bag select 0);
        };

        private _helmet =[(_items select {[(_x select 0),
            (getArray (SC_var_worldGroupConfig >> "aiHelmetFilter"))] call SC_fnc_classMatchesFilter}),
            _rank] call SC_fnc_pickItemNearRandomRank;

        if (_helmet isNotEqualTo []) then {
            _unit addHeadgear (_helmet select 0);
        };

        if _isMedic then {
            _unit addItem "Medikit";
        } else {
            for "_i" from 1 to (selectRandom [4, 5]) do {
                _unit addItem "FirstAidKit";
            };
        };

        if (isPlayer _unit) exitWith {};

        _unit linkItem "ItemMap";
        _unit linkItem "ItemWatch";
        _unit linkItem "ItemCompass";
        _unit addWeaponGlobal (["Binocular", "Rangefinder"] select ("MRKS" in _perks));

        _unit linkItem (SC_var_wgUavTerminals select (SC_var_sides find _side));

        for "_i" from 1 to (round (random [1,2,4])) do {
            _unit addItem (selectRandom ["HandGrenade", "MiniGrenade"]);
        };

        for "_i" from 1 to (round (random [1,1.5,3])) do {
            _unit addItem "SmokeShell";
        };

        private _nvgs = _items select {(([_x select 0] call SC_fnc_getItemType) select 1) == "NVGoggles"};

        if (!DW_var_skipNight && {_nvgs isNotEqualTo []}) then {
            private _newNvg = (selectRandom _nvgs) select 0;
            _unit addItem _newNvg;
            _unit assignItem _newNvg;
        };

        private _launcher = [_groupedWeapons, _mags, SC_fnc_isAiLauncher] call SC_fnc_pickAiWeapon;

        if (_launcher isNotEqualTo []) then {
            _launcher params ["_launcherClass", "_launcherMags"];
            [_unit, _launcherMags, 4] call SC_fnc_addAiMagazines;
            _unit addWeaponGlobal _launcherClass;
        };

        private _primary = [_groupedWeapons, _mags, SC_fnc_isAiPrimaryWeapon] call SC_fnc_pickAiWeapon;

        // no primary weapon in the unit's pool: the lowest-rank primary weapon of its side
        if (_primary isEqualTo []) then {
            ([_side, [], 1000, false] call SC_fnc_getItemsUniqueAndGrouped) params ["", "_sideMags", "_sideGroupedWeapons"];
            private _sidePrimaries = (_sideGroupedWeapons apply {_x select 0}) select {[_x select 0] call SC_fnc_isAiPrimaryWeapon};

            if (_sidePrimaries isNotEqualTo []) then {
                private _lowestRank = selectMin (_sidePrimaries apply {_x select 1});
                private _weapon = (_sidePrimaries select (_sidePrimaries findIf {(_x select 1) == _lowestRank})) select 0;
                _mags = _mags + (_sideMags select {[_x] call SC_fnc_isAiItemAllowed});
                _primary = [_weapon, _mags arrayIntersect (getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines"))];
            };
        };

        _primary params [["_newPrimWep", ""], ["_primaryMags", []]];

        if (_newPrimWep != "") then {
            [_unit, _primaryMags, 9] call SC_fnc_addAiMagazines;

            private _muzzles = getArray (configFile >> "CfgWeapons" >> _newPrimWep >> "muzzles");

            if (_muzzles isNotEqualTo ["this"]) then {
                private _secondaryMuzzle = (_muzzles - ["this"]) select 0;
                [_unit,
                    (_mags arrayIntersect (getArray (configFile >> "CfgWeapons" >> _newPrimWep >> _secondaryMuzzle >>
                    "magazines"))), 4] call SC_fnc_addAiMagazines;
            };

            _unit addWeaponGlobal _newPrimWep;
        };

        if ((_newPrimWep != "") && {_rank >= 3}) then {
            private _compatibleItems = compatibleItems _newPrimWep;
            private _preferredOpticRank = 3 max (round (_rank * (random 1)));
            private _bestOpticYet = nil;
            private _bestDeviationYet = 999;
            {
                if ((_x select 0) in _compatibleItems) then {
                    private _deviation = abs ((_x select 1) - _preferredOpticRank);

                    if (_deviation < _bestDeviationYet) then {
                        _bestOpticYet = _x;
                        _bestDeviationYet = _deviation;
                    };
                };
            } forEach (_groupedOptics apply {_x select 0});

            if !(isNil "_bestOpticYet") then {
                private _newOptic = (selectRandom (_groupedOptics select (_groupedOptics findIf {_bestOpticYet in _x}))) select 0;
                _unit addPrimaryWeaponItem _newOptic;
            };
        };

        if ((_newPrimWep != "") && {"SUPR" in _perks}) then {
            private _allSuppressors = [];
            {_allSuppressors append (_x apply {_x select 0});} forEach _groupedSuppressors;

            private _possibleSuppressors = (compatibleItems [_newPrimWep, "MuzzleSlot"]) arrayIntersect _allSuppressors;

            if (_possibleSuppressors isNotEqualTo []) then {
                _unit addPrimaryWeaponItem (selectRandom _possibleSuppressors);
            };
        };

        if ((random 1) < 0.5) then {
            private _accs = _items select {[(_x select 0), (getArray (SC_var_worldGroupConfig >> "aiAccessoryFilter"))] call SC_fnc_classMatchesFilter};
            private _added = false;
            while {!(isNil "_added") && {!_added} && {(_accs isNotEqualTo [])}} do {
                private _acc = selectRandom _accs;
                _accs = _accs - [_acc];
                _added = _unit addPrimaryWeaponItem (_acc select 0);
            };
        };

        if (isPlayer _unit) exitWith {};

        private _handgun = [_groupedWeapons, _mags, SC_fnc_isAiHandgun] call SC_fnc_pickAiWeapon;

        if (_handgun isNotEqualTo []) then {
            _handgun params ["_handgunClass", "_handgunMags"];
            [_unit, _handgunMags, 3] call SC_fnc_addAiMagazines;
            _unit addWeaponGlobal _handgunClass;
        };
    };

    if (isPlayer _unit) exitWith {};

    waitUntil {!(isNull _unit)};

    _unit setVariable ["SC_var_isWatched", false];
    _unit setVariable ["SC_var_timeRemaining", SC_var_unitDespawnTime];

    [_unit] call SC_fnc_registerEntityServer;

    _unit setUnitTrait ["UAVHacker", true];
    _unit setUnitTrait ["Medic", _isMedic];

    // repairs with the toolkit of a squad vehicle (SC\ai\vehicles.sqf)
    _unit setUnitTrait ["Engineer", true];

    if _isMedic then {
        _unit setAnimSpeedCoef 1.1;
    };

    _unit enableStamina false;
    _unit enableFatigue false;
    _unit setCustomAimCoef 0.35;

    if SC_var_wgOneTimeLaunchers then {
        [_unit] remoteExecCall ["SC_fnc_addFiredMan", 0];
    };

    // a vehicle for the squad (it gets in at the spawn point) if it has none and its objective is far away
    if (
        !_groupSpawn &&
        {!_forDelivery} &&
        {_spawnMarker != ""} &&
        {SC_var_spawnVehiclesOnSectors || {_spawnMarker == _baseMarker}} &&
        {_vehicleType != ""} &&
        {isNull ([group _unit] call SC_fnc_aiGetSquadVehicle)} &&
        {([_spawnPos, _side, group _unit] call SC_fnc_aiDistanceToGoal) > SC_var_aiVehicleUseDistance}
    ) then {
        private _place = if (_spawnMarker == _baseMarker) then {"the Base"} else {_spawnMarker select [count "SC_var_sector"]};

        // with room for the own AI on foot at the spawn point (SC_fnc_aiTransportSize)
        private _transportSize =[_spawnPos, _side,
            (count ([_unit] call SC_fnc_getGroupUnits)) max ([_unit] call SC_fnc_getGroupTargetSize),
            group _unit] call SC_fnc_aiTransportSize;
        private _transportType = [_rank, _transportSize, _side] call SC_fnc_aiPickVehicleType;

        if (_transportType != "") then {
            _vehicleType = _transportType;
        };

        [_unit, _place, _vehicleType] call SC_fnc_aiQueueVehicle;
    };

    _base = "SC_var_" + (toLower (str _side)) + "Base";
    _id = _unit getVariable "SC_var_respawnPositionId";

    if !(isNil "_id") then {
        [_unit, _id] call BIS_fnc_removeRespawnPosition;
    };

    ([_unit, [100, 100, 10], "respawn"] call BIS_fnc_addRespawnPosition) params ["", "_id"];
    _unit setVariable ["SC_var_respawnPositionId", _id];

    [_unit, _base, _spawnPos] spawn {
        params ["_unit", "_base", "_spawnPos"];

        sleep 4;
        if (isPlayer _unit) exitWith {};

        if (_spawnPos inArea _base) then {
            waitUntil {
                sleep 1;
                ((isPlayer _unit) || {(_unit distance _spawnPos) > 8} || {!(alive _unit)})
            };
        };

        if (isPlayer _unit) exitWith {};

        if (alive _unit) then {
            [_unit, true] call ADG_fnc_allowDamage;
        };
    };
};
