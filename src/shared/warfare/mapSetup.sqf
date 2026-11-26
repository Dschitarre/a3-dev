// Map setup: choice of the map (param, vote of the last round or random), bases, sectors, airfields and the play
// zone from the map data (server).

// ---- map choice ----

// "MapName" param: value 0 = Random, value n = MapData entry n - 1 (texts are the map names with their size class)

// param randomMapByPlayers: from these numbers of connected players on, Medium / Large / Huge maps are chosen
SC_var_mapSizePlayerLimits = [8, 20, 40];

// param randomMapByPlayers: the last N maps are not chosen randomly
SC_var_recentMapsExcluded = 3;

// size class of a map name: 0 = Small, 1 = Medium (also without a class), 2 = Large, 3 = Huge
SC_fnc_getMapSizeClass = {
    params ["_mapName"];

    private _sizeClass = ["(Small)", "(Medium)", "(Large)", "(Huge)"] findIf {_x in _mapName};

    [_sizeClass, 1] select (_sizeClass == -1)
};

// random map (param value): of the size class set by the param mapSize, else with the param randomMapByPlayers of the
// size class that fits the number of connected players (the closest existing class if the world has none of it);
// with randomMapByPlayers not one of the last SC_var_recentMapsExcluded maps (if possible)
SC_fnc_getRandomMap = {
    private _mapNames = getArray (missionConfigFile >> "params" >> "MapName" >> "texts");
    private _maps = [];

    for "_i" from 1 to ((count _mapNames) - 1) do {
        _maps pushBack _i;
    };

    // param values: mapSize 0 = Auto, 1 - 4 = Small - Huge; randomMapByPlayers 0 = Disabled, 1 = Enabled
    private _sizeParam = "mapSize" call BIS_fnc_getParamValue;
    private _byPlayers = ("randomMapByPlayers" call BIS_fnc_getParamValue) == 1;
    private _wantedSizeClass = _sizeParam - 1;

    if ((_wantedSizeClass == -1) && _byPlayers) then {
        private _numPlayers = {!((getUserInfo _x) param [7, false])} count allUsers;
        _wantedSizeClass = {_numPlayers >= _x} count SC_var_mapSizePlayerLimits;
    };

    if (_wantedSizeClass != -1) then {
        private _classDistances = _maps apply {abs (([(_mapNames select _x)] call SC_fnc_getMapSizeClass) - _wantedSizeClass)};
        private _minClassDistance = selectMin _classDistances;

        _maps = _maps select {(_classDistances select (_maps find _x)) == _minClassDistance};
    };

    if _byPlayers then {
        private _newMaps = _maps - (profileNamespace getVariable [("SC_var_recentMaps" + worldName), []]);

        if (_newMaps isNotEqualTo []) then {
            _maps = _newMaps;
        };
    };

    selectRandom _maps
};

// server: map voted at the end of a round (param value, 0 = random), used once by the next mission start on this world
SC_fnc_setVotedMap = {
    params ["_mapIndex"];

    if (_mapIndex == 0) then {
        profileNamespace setVariable [("SC_var_votedMap" + worldName), nil];
    } else {
        profileNamespace setVariable [("SC_var_votedMap" + worldName), _mapIndex];
    };

    saveProfileNamespace;
};

// server: param value of the map to play: the MapName param, else the map voted in the last round, else a random map
SC_fnc_selectMap = {
    private _mapCount = count (getArray (missionConfigFile >> "params" >> "MapName" >> "texts"));
    private _votedMapVar = "SC_var_votedMap" + worldName;
    private _mapIndex = "MapName" call BIS_fnc_getParamValue;

    if (_mapIndex == 0) then {
        _mapIndex = profileNamespace getVariable [_votedMapVar, 0];

        if (!(_mapIndex isEqualType 0) || {_mapIndex < 1} || {_mapIndex >= _mapCount}) then {
            _mapIndex = call SC_fnc_getRandomMap;
        };
    };

    // a vote only decides the next round; the recent maps are excluded from the random choice
    private _recentMapsVar = "SC_var_recentMaps" + worldName;
    private _recentMaps = profileNamespace getVariable [_recentMapsVar, []];

    profileNamespace setVariable [_votedMapVar, nil];
    profileNamespace setVariable [_recentMapsVar, (([_mapIndex] + (_recentMaps - [_mapIndex])) select [0, SC_var_recentMapsExcluded])];
    saveProfileNamespace;

    _mapIndex
};

// ---- map setup ----

// server: applies the selected map from MapData: play zone, bases, sectors
SC_fnc_applyMapServer = {
    private _mapNames = getArray (missionConfigFile >> "params" >> "MapName" >> "texts");
    private _mapIndex = call SC_fnc_selectMap;

    [_mapNames select _mapIndex, (getArray (missionConfigFile >> "MapData")) select (_mapIndex - 1)] call SC_fnc_applyMapData;
};

// Common framework map application. Offensive supplies its generated line through the same data contract.
SC_fnc_sectorLabels = {
    private _labels = [];
    for "_i" from 0 to 39 do {
        _labels pushBack (if (_i < 26) then {toString [65 + _i]} else {"A" + toString [65 + _i - 26]});
    };
    _labels
};

SC_fnc_applyMapData = {
    params ["_name", "_data"];
    SC_var_mapName = _name;
    SC_var_wholeMap = SC_var_mapName in ["Altis (Huge)", "Malden (Huge)", "Chernarus (Huge)", "Tanoa (Huge)"];
    publicVariable "SC_var_wholeMap";

    _data params ["_generalData", "_sideData", "_sectorData"];

    // planes only where the layout places a plane spawn in every base (7th base object); whole Malden has none
    SC_var_layoutPlaneSpawns = (_sideData findIf {count (_x select 7) < 7}) == -1;
    publicVariable "SC_var_layoutPlaneSpawns";

    "SC_var_playZone" setMarkerPos (_generalData select 3);
    "SC_var_playZone" setMarkerSize (_generalData select 4);
    "SC_var_playZone" setMarkerDir (_generalData select 5);
    "SC_var_playZone" setMarkerShape (_generalData select 6);

    // Cover map: none on whole-map maps (the whole island is played). The editor's cover map module draws its area when
    // the module framework initializes it (possibly after this), so there it is removed (its markers too, if it drew
    // them already); other maps give the module the wanted area before drawing it.
    if SC_var_wholeMap then {
        if !(isNull SC_var_coverMap) then {
            [SC_var_coverMap, [], false] call BIS_fnc_moduleCoverMap;
            deleteVehicle SC_var_coverMap;
        };

        // the module is also initialized on the clients that start the mission with the server (before its deletion
        // reaches them) and draws the cover again with global markers: removed whenever they appear
        if (isNil "SC_var_coverMapRemoverScript") then {
            SC_var_coverMapRemoverScript = [] spawn {
                waitUntil {
                    sleep 2;

                    if ((markerShape "bis_fnc_moduleCoverMap_border") != "") then {
                        [objNull, [], false] call BIS_fnc_moduleCoverMap;
                    };

                    false
                };
            };
        };
    } else {
        SC_var_coverMap setPos (_generalData select 0);

        if (((getPosWorld SC_var_coverMap) distance2D (getMarkerPos "SC_var_playZone")) > 100) then {
            SC_var_coverMap setPos (getMarkerPos "SC_var_playZone");
            private _size = 1.3 * (selectMax (getMarkerSize "SC_var_playZone"));
            SC_var_coverMap setVariable ["objectArea", [_size, _size, (_generalData select 1), true, 0]];
        } else {
            SC_var_coverMap setVariable ["objectArea", [(_generalData select 2), (_generalData select 2), (_generalData select 1), true, 0]];
        };

        [SC_var_coverMap, [], true] call BIS_fnc_moduleCoverMap;
    };
    if !(missionNamespace getVariable ["OF_var_enabled", false]) then {_sideData = _sideData call BIS_fnc_arrayShuffle};

    {
        private _varStart = "SC_var_" + toLower (str ([west, east, independent] select _forEachIndex));

        (_varStart + "Respawn") setMarkerPos (_x select 0);
        (_varStart + "Respawn") setMarkerDir (_x select 1);
        (_varStart + "HQ") setMarkerPos (_x select 2);
        (_varStart + "HQ") setMarkerDir 0;
        (_varStart + "Base") setMarkerPos (_x select 3);
        (_varStart + "Base") setMarkerShape (_x select 4);
        (_varStart + "Base") setMarkerSize (_x select 5);
        (_varStart + "Base") setMarkerDir (_x select 6);

        {
            private _obj = missionNamespace getVariable (_varStart + (["VehSpawn", "Cs", "Equip", "Inf", "Tp", "Veh", "PlaneSpawn"] select _forEachIndex));

            private _pos = _x select 0;
            _pos set [2, 0];

            _obj setPos _pos;
            _obj setVectorDir ((_x select 1) select 0);
            _obj setVectorUp (surfaceNormal _pos);
        } forEach (_x select 7);
    } forEach _sideData;

    SC_var_sectors = call SC_fnc_sectorLabels;
    SC_var_numSectorsLimit = count _sectorData;
    publicVariable "SC_var_numSectorsLimit";

    // Maps and generated fronts can have more sectors than the editor mission has flag objects: the missing flags are
    // created like the editor's (same class, no damage)
    private _flagType = typeOf (missionNamespace getVariable ["SC_var_flagA3d", objNull]);
    if (_flagType == "") then {_flagType = "FlagSmall_F"};
    {
        private _name = "SC_var_flag" + _x + "3d";
        if (isNull (missionNamespace getVariable [_name, objNull])) then {
            private _flag = createVehicle [_flagType, [0,0,0], [], 0, "NONE"];
            _flag allowDamage false;
            missionNamespace setVariable [_name, _flag, true];
        };
        private _marker = "SC_var_sector" + _x;
        if (markerShape _marker == "") then {createMarker [_marker, [0,0,0]]};
    } forEach (SC_var_sectors select [0, SC_var_numSectorsLimit]);

    {
        ["SC_var_sector" + _x] remoteExecCall ["deleteMarkerLocal", 0, true];
        deleteVehicle (missionNamespace getVariable ("SC_var_flag" + _x + "3d"));
    } forEach (SC_var_sectors select [SC_var_numSectorsLimit, ((count SC_var_sectors) - SC_var_numSectorsLimit)]);

    SC_var_sectors = SC_var_sectors select [0, SC_var_numSectorsLimit];
    publicVariable "SC_var_sectors";

    {
        private _sectorInd = SC_var_sectors select _forEachIndex;
        private _flag = missionNamespace getVariable ("SC_var_flag" + _sectorInd + "3d");
        private _sectorMarker = "SC_var_sector" + _sectorInd;

        _pos = _x select 0;
        private _safePos = [];
        private _rad = 3;

        while {_safePos isEqualTo []} do {
            _safePos = _pos findEmptyPosition [0, _rad, "FlagSmall_F"];
            _rad = _rad + 1;
        };

        _flag setPos _safePos;
        _flag setVectorUp (surfaceNormal _safePos);

        _sectorMarker setMarkerPos (_x select 2);
        _sectorMarker setMarkerShape (_x select 3);
        _sectorMarker setMarkerSize (_x select 4);
        _sectorMarker setMarkerDir (_x select 5);
    } forEach _sectorData;

    "SC_var_playZone" setMarkerAlpha ([0.35, 0] select SC_var_wholeMap);
    "SC_var_spawnArea" setMarkerAlpha 0;

    {
        if ((_x isNotEqualTo SC_var_equip) && {!(_x inArea "SC_var_playZone")} && {!(_x isKindOf "CAManBase")}) then {
            deleteVehicle _x;
        };
    } forEach (allMissionObjects "");

    call SC_fnc_hideTerrainAreas;
};

// client, whole-map maps: the cover map module also initializes on a client that starts the mission with the server and
// draws the cover at its editor position; removed locally whenever it appears
SC_fnc_removeCoverMapLocal = {
    waitUntil {
        if ((markerShape "bis_fnc_moduleCoverMap_border") != "") then {
            {
                deleteMarkerLocal _x;
            } forEach (["bis_fnc_moduleCoverMap_border"] + ([0, 90, 180, 270] apply {format ["bis_fnc_moduleCoverMap_%1", _x]}) +
                ([0, 90, 180, 270] apply {format ["bis_fnc_moduleCoverMap_dot_%1", _x]}));
        };

        sleep 2;
        false
    };
};

// The editor's Hide Terrain Objects modules belong to single maps (e.g. to clear a base), so the build takes them out of
// the mission and lists their areas in hideTerrainAreas.sqf (scripts\hideTerrainObjects.ps1). A map hides the areas
// whose center lies in its play zone; a whole-map map the ones in the sides' bases (its play zone is the whole island).
// Same object categories, filter flags and hiding as the module (bis_fnc_moduleHideTerrainObjects).
SC_var_hideTerrainCategories = [
    ["BUILDING", "HOUSE", "CHURCH", "CHAPEL", "FUELSTATION", "HOSPITAL", "RUIN", "BUNKER"],
    ["WALL", "FENCE"],
    ["TREE", "SMALL TREE", "BUSH"],
    [
        "ROCK", "ROCKS", "FOREST BORDER", "FOREST TRIANGLE", "FOREST SQUARE", "CROSS", "FORTRESS", "FOUNTAIN", "VIEW-TOWER",
        "LIGHTHOUSE", "QUAY", "HIDE", "BUSSTOP", "ROAD", "FOREST", "TRANSMITTER", "STACK", "TOURISM", "WATERTOWER", "TRACK",
        "MAIN ROAD", "POWER LINES", "RAILWAY", "POWERSOLAR", "POWERWAVE", "POWERWIND", "SHIPWRECK", "TRAIL"
    ]
];

SC_fnc_hideTerrainAreas = {
    if !(fileExists "hideTerrainAreas.sqf") exitWith {};

    private _zones = if SC_var_wholeMap then {
        ["west", "east", "guer"] apply {"SC_var_" + _x + "Base"} select {(markerShape _x) != ""}
    } else {
        ["SC_var_playZone"]
    };
    private _count = 0;

    {
        _x params ["_center", "_a", "_b", "_direction", "_isRectangle", "_filter", "_hideLocally"];

        if ((_zones findIf {_center inArea _x}) != -1) then {
            [_center, _a, _b, _direction, _isRectangle, _filter, _hideLocally] call SC_fnc_hideTerrainArea;
            _count = _count + 1;
        };
    } forEach (call compile preprocessFileLineNumbers "hideTerrainAreas.sqf");

    diag_log format ["SC: %1 hide terrain areas for %2", _count, SC_var_mapName];
};

// server: hides the terrain objects of the area (globally, or with _hideLocally on every machine)
SC_fnc_hideTerrainArea = {
    params ["_center", "_a", "_b", "_direction", "_isRectangle", "_filter", "_hideLocally"];

    if (_hideLocally && {isServer}) exitWith {
        [_center, _a, _b, _direction, _isRectangle, _filter, false] remoteExecCall ["SC_fnc_hideTerrainAreaLocal", 0, true];
    };

    [_center, _a, _b, _direction, _isRectangle, _filter, true] call SC_fnc_hideTerrainAreaLocal;
};

SC_fnc_hideTerrainAreaLocal = {
    params ["_center", "_a", "_b", "_direction", "_isRectangle", "_filter", "_global"];

    private _area = [_center, _a, _b, _direction, _isRectangle];
    private _flags = _filter call BIS_fnc_decodeFlags2;

    {
        if (_x == 1) then {
            private _objects =(nearestTerrainObjects [_center, SC_var_hideTerrainCategories select _forEachIndex,
                (_a max _b) * 1.42, false, true]) inAreaArray _area;

            {
                if _global then {_x hideObjectGlobal true} else {_x hideObject true};
                if (_global || {isServer}) then {_x allowDamage false};
            } forEach _objects;
        };
    } forEach _flags;
};
