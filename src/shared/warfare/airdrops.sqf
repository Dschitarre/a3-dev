// Supply airdrops: random crates with rank based items, extra drops for trailing sides (server).

// ---- airdrops ----

// Supply events follow mode progress, which need not be the remaining respawn tickets.
SC_fnc_airdropProgress = {SC_var_tickets};
SC_fnc_checkAirDrops = {
    if (time < (missionNamespace getVariable ["SC_var_nextAirdropAt",0])) exitWith {};
    private _interval = missionNamespace getVariable ["SC_var_airdropMinInterval",0];
    private _total = 0;
    {_total = _total + _x} forEach (call SC_fnc_airdropProgress);
    private _sideDrops = call SC_fnc_checkSideAirDrops;
    if (_sideDrops > 0) then {SC_var_nextAirdropAt = time + _interval};
    // Rate-limited modes coalesce progress into one event rather than draining a backlog for minutes afterwards.
    if (_sideDrops > 0 && {_interval > 0}) exitWith {SC_var_lastDrop = _total};
    if (_total > SC_var_lastDrop + SC_var_dropStep) then {
        SC_var_lastDrop = [SC_var_lastDrop + SC_var_dropStep,_total] select (_interval > 0);
        SC_var_nextAirdropAt = time + _interval;
        ["airDrop",[]] remoteExec ["SC_fnc_showNotificationIfHudIsEnabled",0];
        ["SC_var_playZone"] spawn SC_fnc_airDrop;
    };
};

// seconds after which an airdrop box is released from its parachute even if it is still in the air, and after which
// it counts as landed even if it still slides down a slope (its speed never reaches 0 there)
SC_var_airdropFallTimeout = 300;
SC_var_airdropLandTimeout = 15;

// the big cargo parachute on large maps, the small round one on the smaller maps (user decision 2026-11-13: the big one
// is out of proportion there); SC_var_mapSize from SC\init\server.sqf
SC_var_airdropSmallParachuteMapSizes = ["Small", "Medium"];
SC_var_airdropParachuteBig = "B_Parachute_02_F";
SC_var_airdropParachuteSmall = "NonSteerable_Parachute_F";

// a drop position in _dropMarker, [] if none is found: on land with a free sky above, in the play zone outside the
// bases and sectors, away from other airdrops and preferably near the zone's centre. After SC_var_airdropStrictTries
// tries only the hard rules count (land, free sky, outside the bases), after SC_var_airdropMaxTries it gives up.
SC_var_airdropStrictTries = 300;
SC_var_airdropMaxTries = 600;

SC_fnc_findAirdropPos = {
    params ["_dropMarker"];

    private _isPlayZone = _dropMarker == "SC_var_playZone";
    private _baseMarkers = SC_var_sides apply {"SC_var_" + toLower str _x + "Base"};
    private _found = [];

    for "_try" from 1 to SC_var_airdropMaxTries do {
        private _pos = _dropMarker call BIS_fnc_randomPosTrigger;
        _pos set [2, 0];

        private _strict = _try <= SC_var_airdropStrictTries;
        private _posAsl = (AGLToASL _pos) vectorAdd [0, 0, 0.5];

        if (
            !(surfaceIsWater _pos) && {
                !_isPlayZone ||
                {
                    ((_baseMarkers findIf {
                        (_pos distance2D (getMarkerPos _x)) < (1.4 * (selectMax (getMarkerSize _x)))
                    }) == -1) && {
                        !_strict || {
                            (
                                SC_var_hugeMap ||
                                {(random [0, 0.3, 1]) > ((_pos distance2D (getMarkerPos "SC_var_playZone")) / SC_var_maxZoneSize)}
                            ) && {
                                ((entities "box_NATO_equip_F") findIf {(_pos distance2D _x) < (0.25 * SC_var_maxZoneSize)}) == -1
                            } && {
                                (SC_var_sectors findIf {
                                    (_pos distance2D (getMarkerPos ("SC_var_sector" + _x))) <
                                    (selectMax (getMarkerSize ("SC_var_sector" + _x)) max (0.3 * (missionNamespace getVariable ("SC_var_nearestSectorDistance" + _x))))
                                }) == -1
                            }
                        }
                    }
                }
            } && {
                ([objNull, "VIEW"] checkVisibility [_posAsl, (_posAsl vectorAdd [0, 0, 100])]) != 0
            }
        ) exitWith {
            _found = _pos;
        };
    };

    _found
};

SC_fnc_airDrop = {
    params ["_dropMarker"];

    // the position first: the box exists only once it is known (it used to wait at [0, 0, 0], the south-west map corner,
    // while the search ran, and stayed there when nothing fitted)
    private _safePos = [_dropMarker] call SC_fnc_findAirdropPos;

    if (_safePos isEqualTo []) exitWith {
        diag_log format ["SC airdrop: no drop position found in %1, the airdrop is skipped", _dropMarker];
    };

    private _parachuteClass =[SC_var_airdropParachuteBig,
        SC_var_airdropParachuteSmall] select (SC_var_mapSize in SC_var_airdropSmallParachuteMapSizes);
    private _parachute = createVehicle [_parachuteClass, (_safePos vectorAdd [0, 0, 150]), [], 0, "FLY"];
    private _box = createVehicle ["box_NATO_equip_F", (_safePos vectorAdd [0, 0, 148]), [], 0, "CAN_COLLIDE"];

    waitUntil {!(isNull _box) && {!(isNull _parachute)}};

    // cargo parachute with the box below it; moved straight down by script so that it doesn't drift
    _box attachTo [_parachute, [0, 0, -1.3]];

    // -1 while falling, then the serverTime at which the box is deleted (clients compute the countdown)
    _box setVariable ["SC_var_despawnTime", -1, true];
    SC_var_airdropBoxes pushBack _box;
    publicVariable "SC_var_airdropBoxes";
    clearItemCargoGlobal _box;
    [_box, false] call ADG_fnc_allowDamage;

    [_box, _parachute, _safePos] spawn {
        params ["_box", "_parachute", "_safePos"];

        private _timeout = time + SC_var_airdropFallTimeout;

        waitUntil {
            _parachute setPosASL ((_safePos select [0, 2]) + [((visiblePositionASL _parachute) select 2) - 0.05]);
            _parachute setVectorDirAndUp [[0, 1, 0], [0, 0, 1]];
            _parachute setVelocity [0, 0, 0];

            (isNull _parachute) || {((visiblePosition _box) select 2) < 2} || {time > _timeout}
        };

        detach _box;

        _timeout = time + SC_var_airdropLandTimeout;
        waitUntil {sleep 0.5; (isTouchingGround _box) || {(vectorMagnitude (velocity _box)) < 0.1} || {time > _timeout}};

        deleteVehicle _parachute;

        private _duration = SC_var_airDropDurationMins * 60;
        _box setVariable ["SC_var_despawnTime", serverTime + _duration, true];
        sleep _duration;

        SC_var_airdropBoxes = SC_var_airdropBoxes - [_box, objNull];
        publicVariable "SC_var_airdropBoxes";
        [_box] remoteExecCall ["deleteVehicle", _box];
    };

    ([sideEmpty, [], -1, false] call SC_fnc_getItemsUniqueAndGrouped) params ["_items", "_mags", "_groupedWeapons", "_groupedOptics", "_groupedSuppressors"];

    // no explosives (mines, charges, claymores, IEDs) in airdrops
    _items = _items select {(([_x select 0] call SC_fnc_getItemType) select 0) != "Mine"};

    private _cargo = [];
    private _worth = 0;

    while {_worth < 600} do {
        private _itemAndRank = selectRandom _items;
        _itemAndRank params ["_item", "_rank"];
        private _itemType = [_item] call SC_fnc_getItemType;

        if ((_itemType select 0) == "Weapon") then {
            _itemAndRank = selectRandom (_groupedWeapons select (_groupedWeapons findIf {_itemAndRank in _x}));
            _itemAndRank params ["_variant", "_variantRank"];
            _item = _variant;
            _rank = _variantRank;
            private _possibleMags = _mags arrayIntersect (getArray (configFile >> "CfgWeapons" >> _item >> "magazines"));

            if (_possibleMags isNotEqualTo []) then {
                for "_i" from 1 to (selectRandom [5, 6, 7, 8, 9]) do {
                    _cargo pushBack (selectRandom _possibleMags);
                };
            };

            private _muzzles = getArray (configFile >> "CfgWeapons" >> _item >> "muzzles");

            if (_muzzles isNotEqualTo ["this"]) then {
                private _secondaryMuzzle = (_muzzles - ["this"]) select 0;
                _possibleMags = _mags arrayIntersect (getArray (configFile >> "CfgWeapons" >> _item >> _secondaryMuzzle >> "magazines"));

                if (_possibleMags isNotEqualTo []) then {
                    for "_i" from 1 to (selectRandom [3, 4, 5, 6, 7]) do {
                        _cargo pushBack (selectRandom _possibleMags);
                    };
                };
            };
        } else {
            private _grouped = switch (_itemType select 1) do {
                case "AccessorySights": {_groupedOptics};
                case "AccessoryMuzzle": {_groupedSuppressors};
                default {[]};
            };

            if (_grouped isNotEqualTo []) then {
                _itemAndRank = selectRandom (_grouped select (_grouped findIf {_itemAndRank in _x}));
                _itemAndRank params ["_variant", "_variantRank"];
                _item = _variant;
                _rank = _variantRank;
            };

            // a laser designator comes with its battery
            if ((_itemType select 1) == "LaserDesignator") then {
                private _battery = (getArray (configFile >> "CfgWeapons" >> _item >> "magazines")) param [0, ""];

                if (_battery != "") then {
                    _cargo pushBack _battery;
                };
            };
        };

        _cargo pushBack _item;
        _worth = _worth + _rank;
    };

    {
        _box addItemCargoGlobal [_x, 1];
    } forEach _cargo;
};

// Side airdrops favour the trailing sides: a side gets a supply drop each time its ticket deficit to the leading side
// reaches the next multiple of SC_var_sideDropStep (after catching up, a side can earn the same steps again).
SC_fnc_checkSideAirDrops = {
    private _progress = call SC_fnc_airdropProgress;
    private _leadingTickets = selectMax _progress;
    private _requested = 0;

    {
        private _deficitLevel = floor ((_leadingTickets - (_progress select _forEachIndex)) / SC_var_sideDropStep);
        private _levelVar = "SC_var_last" + (str _x) + "Drop";
        private _lastLevel = missionNamespace getVariable [_levelVar, 0];

        if (_deficitLevel > _lastLevel) then {
            [_x] call SC_fnc_sideAirDrop;
            _requested = _requested + 1;
        };

        if (_deficitLevel != _lastLevel) then {
            missionNamespace setVariable [_levelVar, _deficitLevel];
        };
    } forEach SC_var_sides;
    _requested
};

// airdrop on the side's sector that is farthest away from all existing airdrop boxes, in its base if it holds none
SC_fnc_sideAirDrop = {
    params ["_side"];

    private _sideString = [_side] call SC_fnc_getSideString;
    private _possibleDropSectors = SC_var_sectors select {(missionNamespace getVariable ("SC_var_owner" + _x)) == _side};

    if (_possibleDropSectors isEqualTo []) exitWith {
        [("SC_var_" + (toLower (str _side)) + "Base")] spawn SC_fnc_airDrop;
        ["sideAirDrop", [_sideString, "their base"]] remoteExec ["SC_fnc_showNotificationIfHudIsEnabled", 0];
    };

    private _boxes = entities "box_NATO_equip_F";
    private _bestSectorsMinDistanceToDrop = -1;
    private _dropSector = "";

    {
        private _sectorPos = getMarkerPos ("SC_var_sector" + _x);
        private _sectorsMinDistanceToDrop = if (_boxes isEqualTo []) then {1e10} else {selectMin (_boxes apply {_x distance2D _sectorPos})};

        if (_sectorsMinDistanceToDrop > _bestSectorsMinDistanceToDrop) then {
            _bestSectorsMinDistanceToDrop = _sectorsMinDistanceToDrop;
            _dropSector = _x;
        };
    } forEach _possibleDropSectors;

    [("SC_var_sector" + _dropSector)] spawn SC_fnc_airDrop;
    ["sideAirDrop", [_sideString, _dropSector]] remoteExec ["SC_fnc_showNotificationIfHudIsEnabled", 0];
};

// remaining time of an airdrop box ("" while falling), nil if the object is no airdrop box
SC_fnc_getAirdropTimeText = {
    params ["_box"];

    private _despawnTime = _box getVariable "SC_var_despawnTime";

    if (isNil "_despawnTime") exitWith {nil};
    if (_despawnTime < 0) exitWith {""};

    // the text only changes once per second, so it is cached on the box (locally)
    private _secondsLeft = 0 max (round (_despawnTime - serverTime));
    (_box getVariable ["SC_var_timeTextCache", [-1, ""]]) params ["_cachedSeconds", "_cachedText"];

    if (_cachedSeconds == _secondsLeft) exitWith {_cachedText};

    private _text = [_secondsLeft] call SC_fnc_secondsToMinSec;
    _box setVariable ["SC_var_timeTextCache", [_secondsLeft, _text]];
    _text
};
