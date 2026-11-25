// Team Deathmatch maps (server): map rotation, map vote choices and setup from mapData[] (TDM\maps\mapData<map>.hpp),
// cleanup between rounds. Row format of mapData[]: [coverMapPos, coverMapDir, coverMapSize, playZonePos, playZoneSize,
// playZoneDir, playZoneShape, respawnWestPos, respawnEastPos, westHQPos, eastHQPos, sizeCategory]; sizeCategory
// (mapSize param): 0 small (< 60000 m2), 1 medium (< 110000 m2), 2 large.

DM_var_zoneShrinkRatio = 0.7;       // each shrink step keeps 30 % of the remaining zone size
DM_var_zoneBroadcastInterval = 0.25;
DM_var_playZonePollInterval = 0.25; // scan for units outside the zone (all units)
DM_var_mapSizeIndex = 11;           // position of the size category in a mapData[] row
DM_var_mapSizePlayerLimits = [4, 9];    // mapSize Auto: up to 4 players small zones, up to 9 medium, more large
DM_var_mapVoteOptions = 3;

// MapName param: 0 Alternating Maps, 1 One random map, 2.. row (value - 2) of mapData[]
DM_fnc_initMapsServer = {
    private _mapSetting = "MapName" call BIS_fnc_getParamValue;

    DM_var_alternatingMaps = _mapSetting == 0;
    DM_var_randomMapRotation = [];

    if (!DM_var_alternatingMaps) exitWith {
        [[_mapSetting - 2, selectRandom (call DM_fnc_mapsOfWantedSize)] select (_mapSetting == 1), false] call DM_fnc_applyMap;
    };

    [] call DM_fnc_buildMapRotation;
};

// maps of the size the mapSize param asks for (Auto: by the players connected now)
DM_fnc_mapsOfWantedSize = {
    [DM_var_mapSizeIndex, DM_var_mapSizePlayerLimits] call CMN_fnc_mapsOfWantedSize
};

/*
    Alternating Maps: random maps of the wanted size, _firstMap (e.g. the voted one, -1: none) first. Every map is
    played twice (once per side), so about half of the possible rounds need a map each.
*/
DM_fnc_buildMapRotation = {
    params [["_firstMap", -1]];

    private _remainingMaps = (call DM_fnc_mapsOfWantedSize) - [_firstMap];
    private _rotationLength = 1 max floor ((DM_var_minPointsToWin + 1) / 2);

    DM_var_randomMapRotation = [_firstMap] select {_x != -1};

    while {count DM_var_randomMapRotation < _rotationLength && {_remainingMaps isNotEqualTo []}} do {
        DM_var_randomMapRotation pushBack (_remainingMaps deleteAt floor random count _remainingMaps);
    };
};

// warmup map vote: up to DM_var_mapVoteOptions random maps of the wanted size; [] when the map is fixed or there is no choice
DM_fnc_mapVoteChoices = {
    if (("MapName" call BIS_fnc_getParamValue) > 1) exitWith {[]};

    private _choices = (call DM_fnc_mapsOfWantedSize) call BIS_fnc_arrayShuffle;
    _choices resize (DM_var_mapVoteOptions min count _choices);

    [[], _choices] select (count _choices > 1)
};

// MapName param texts: value v >= 2 is row v - 2 of mapData[]
DM_fnc_mapName = {
    params ["_mapIndex"];

    (getArray (missionConfigFile >> "Params" >> "MapName" >> "texts")) select (_mapIndex + 2)
};

/*
    End of the warmup: the map of the match (One random map) or the rotation (Alternating Maps) for the players now
    connected, with the voted map (-1: no vote) as the map of the match or the first one of the rotation.
*/
DM_fnc_applyWarmupMapChoice = {
    params ["_votedMap"];

    if (DM_var_alternatingMaps) exitWith {
        [_votedMap] call DM_fnc_buildMapRotation;
    };

    if (("MapName" call BIS_fnc_getParamValue) != 1) exitWith {};

    // no vote (a single map of the wanted size): that map
    if (_votedMap == -1) then {
        _votedMap = selectRandom (call DM_fnc_mapsOfWantedSize);
    };

    [_votedMap, false] call DM_fnc_applyMap;
};

DM_fnc_applyMap = {
    params ["_mapIndex", "_switchedSides"];

    private _mapRow = (getArray (missionConfigFile >> "mapData")) select _mapIndex;
    _mapRow params ["", "", "", "_playZonePos", "_playZoneSize", "", "_playZoneShape", "_respawnWestPos", "_respawnEastPos", "_westHQPos", "_eastHQPos"];

    call DM_fnc_cleanUp;

    ([missionNamespace getVariable ["DM_var_coverMap", objNull], "DM_mrk_playZone", _mapRow] call CMN_fnc_applyPlayZone) params ["_maxZoneSize", "_zoneArea"];

    "respawn_west" setMarkerPos _respawnWestPos;
    "respawn_west" setMarkerDir (_respawnWestPos getDir _playZonePos);
    "respawn_east" setMarkerPos _respawnEastPos;
    "respawn_east" setMarkerDir (_respawnEastPos getDir _playZonePos);
    "DM_mrk_westHQ" setMarkerPos _westHQPos;
    "DM_mrk_eastHQ" setMarkerPos _eastHQPos;

    if (_switchedSides) then {
        call DM_fnc_switchSides;
    };

    DM_var_zoneStartSize = _playZoneSize;
    DM_var_zoneStartPos = _playZonePos;
    DM_var_maxZoneSize = _maxZoneSize;
    DM_var_zoneSize = _zoneArea;

    // shrink duration factor, tuned by hand (ellipses take pi times longer)
    DM_var_zoneSizeFactor = ((_playZoneSize select 0) * (_playZoneSize select 1) / 4560) ^ 0.05;

    if (_playZoneShape == "ELLIPSE") then {
        DM_var_zoneSizeFactor = DM_var_zoneSizeFactor * pi;
    };

    publicVariable "DM_var_maxZoneSize";

    [true] remoteExec ["DM_fnc_setToSpawn", (allPlayers select {!(_x isKindOf "HeadlessClient_F")}) select {alive _x && {simulationEnabled _x}}];
};

// [mapIndex, switchedSides] of the current round; every rotation map is played twice, once per side
DM_fnc_getCurrentMap = {
    private _roundIndex = (DM_var_roundNumber - 1) mod (2 * count DM_var_randomMapRotation);

    [DM_var_randomMapRotation select floor (_roundIndex / 2), _roundIndex mod 2 != 0]
};

// swaps the HQ and respawn markers of both sides
DM_fnc_switchSides = {
    {
        private _westMarker = format [_x, "west"];
        private _eastMarker = format [_x, "east"];
        private _westPos = getMarkerPos _westMarker;
        private _westDir = markerDir _westMarker;

        _westMarker setMarkerPos (getMarkerPos _eastMarker);
        _westMarker setMarkerDir (markerDir _eastMarker);
        _eastMarker setMarkerPos _westPos;
        _eastMarker setMarkerDir _westDir;
    } forEach ["DM_mrk_%1HQ", "respawn_%1"];
};

// removes wrecks, dropped gear, craters etc. and repairs the buildings around the play zone
DM_fnc_cleanUp = {
    private _debrisTypes = [
        "GroundWeaponHolder",
        "WeaponHolderSimulated",
        "#slop",
        "#mark",
        "#crateronvehicle",
        "#crater",
        "#track",
        "#objectdestructed",
        "#explosion"
    ];

    {
        {
            deleteVehicle _x;
        } forEach _x;
    } forEach ((_debrisTypes apply {allMissionObjects _x}) + [vehicles]);

    {
        if !(_x isKindOf "CAManBase" && {_x in playableUnits}) then {
            deleteVehicle _x;
        };
    } forEach allDead;

    private _zoneCenter = getMarkerPos "DM_mrk_playZone";
    private _radius = 1.5 * selectMax (getMarkerSize "DM_mrk_playZone");

    {
        _x setDamage 0;
        private _doorCount = getNumber (configFile >> "CfgVehicles" >> typeOf _x >> "numberofdoors");

        for "_i" from 1 to _doorCount do {
            _x animateSource [format ["Door_%1_sound_source", _i], 0];
        };
    } forEach (nearestObjects [_zoneCenter, [], _radius, true] + nearestTerrainObjects [_zoneCenter, [], _radius, false, true]);
};
