// Server init: game state variables, loops, map setup and the per-player server setup (server).

// ---- server init ----

// server init: called from initServer.sqf after all functions are compiled; starts the server loops
SC_fnc_initServer = {
    call SC_fnc_initKillFeedServer;
    call SC_fnc_initAIUnitsServer;
    call SC_fnc_applyMapServer;
    call SC_fnc_initServerVars;
    call SC_fnc_addActionsServer;
    call SC_fnc_initHarborsServer;
    call SC_fnc_initSpawnVehiclesServer;
    call SC_fnc_initServiceServer;

    call SC_fnc_initGroupMenuServer;

    addMissionEventHandler ["EntityKilled", {
        _this call SC_fnc_entityKilled;
    }];

    addMissionEventHandler ["EntityRespawned", {
        _this call SC_fnc_entityRespawned;
    }];

    addMissionEventHandler ["HandleDisconnect", {
        _this call SC_fnc_handleDisconnect;
        true
    }];

    // param "progressStorage": 0 = Client, 1 = Server
    if (("progressStorage" call BIS_fnc_getParamValue) == 1) then {
        SC_var_progressSaveLoopScript = [] spawn SC_fnc_progressSaveLoop;
    };

    SC_var_zoneLoopScript = [] spawn SC_fnc_zoneLoop;
    SC_var_gameModeLoopScript = [] spawn SC_fnc_gameModeLoop;
    SC_var_weaponHolderLoopScript = [] spawn SC_fnc_weaponHolderLoop;
    SC_var_aiLoopScript = [] spawn SC_fnc_aiLoop;
    SC_var_suspendAiLoopScript = [] spawn SC_fnc_suspendAiLoop;
    SC_var_groupLoopScript = [] spawn SC_fnc_aiGroupLoop;
    // AI with launchers attack enemy spawn vehicles they see (SCi\delivery.sqf)
    SC_var_aiHuntLoopScript = [] spawn SC_fnc_aiHuntLoop;

    if (missionNamespace getVariable ["DW_cba_enabled", true]) then {
        [true] call DW_fnc_startDynamicWeather;
    };
    if (missionNamespace getVariable ["DTV_cba_enabled", true]) then {
        call DTV_fnc_startDisableTacticalViewServer;
    };
    if (missionNamespace getVariable ["TDI_cba_enabled", true]) then {
        call TDI_fnc_startTdIconsServer;
    };
    if (missionNamespace getVariable ["E_cba_enabled", true]) then {
        call E_fnc_startEarplugsServer;
    };
    if (missionNamespace getVariable ["H_cba_enabled", true]) then {
        call H_fnc_startHolsterServer;
    };
    if (missionNamespace getVariable ["UF_cba_enabled", true]) then {
        call UF_fnc_startUnflipServer;
    };
    if (missionNamespace getVariable ["MR_cba_enabled", true]) then {
        call MR_fnc_startMagRepackServer;
    };
    if (missionNamespace getVariable ["J_cba_enabled", true]) then {
        call J_fnc_startJumpServer;
    };
    if (missionNamespace getVariable ["MM_cba_enabled", true]) then {
        call MM_fnc_startMapMarkerServer;
    };

    SC_var_serverInitDone = true;
    publicVariable "SC_var_serverInitDone";
};

// server: game variables and settings (map size, params, registries, vehicle and equipment lists)
SC_fnc_unitsForArea = {
    params ["_area", "_maximum"];

    0 max (_maximum min (round (0.052 * ((_area max 1) ^ 0.4))))
};

SC_fnc_aiPopulationArea = {SC_var_mapArea};

SC_fnc_vehicleAvailabilityArea = {SC_var_mapArea};

// land area (m²) of an area marker: a grid over the marker (about 200 x 200 points) tested with surfaceIsWater, so a
// coastal or whole-island play zone counts its land and islands, not the sea (user 2026-11-26)
SC_fnc_markerLandArea = {
    params ["_marker"];

    (getMarkerSize _marker) params ["_a", "_b"];
    private _center = getMarkerPos _marker;
    private _direction = markerDir _marker;
    private _isRectangle = (markerShape _marker) == "RECTANGLE";
    private _markerArea = [pi * _a * _b, 4 * _a * _b] select _isRectangle;
    private _step = 25 max ((sqrt _markerArea) / 200);
    private _reach = sqrt ((_a * _a) + (_b * _b));
    private _land = 0;

    for "_dx" from -_reach to _reach step _step do {
        for "_dy" from -_reach to _reach step _step do {
            // into the marker's own axes (its direction is clockwise from north)
            private _u = (_dx * cos _direction) - (_dy * sin _direction);
            private _v = (_dx * sin _direction) + (_dy * cos _direction);

            if ([((_u / _a) ^ 2) + ((_v / _b) ^ 2) <= 1, (abs _u) <= _a && {(abs _v) <= _b}] select _isRectangle) then {
                private _px = (_center select 0) + _dx;
                private _py = (_center select 1) + _dy;

                if (_px >= 0 && {_py >= 0} && {_px <= worldSize} && {_py <= worldSize} && {!(surfaceIsWater [_px, _py])}) then {
                    _land = _land + 1;
                };
            };
        };
    };

    // a zone with too few points on land (tiny marker) keeps its marker area
    [_markerArea, _land * _step * _step] select (_land >= 20)
};

// at most 30 per side on smaller maps, 50 on huge maps (the 50 playable units of a side)
SC_fnc_populationTarget = {
    [call SC_fnc_aiPopulationArea, [30, 50] select SC_var_hugeMap] call SC_fnc_unitsForArea
};

SC_fnc_initServerVars = {
    SC_var_groundWeaponHolders = [];
    SC_var_airdropBoxes = [];
    publicVariable "SC_var_airdropBoxes";

    // vehicle spawn cooldowns per player UID, see SC\vehicles\spawning.sqf
    SC_var_vehicleCooldowns = createHashMap;

    // statistics of the round per player UID, see SC\roundEnd.sqf
    SC_var_roundStats = createHashMap;
    SC_var_roundStartTime = time;

    private _vars = [];

    _vars pushBack ["SC_var_vehicles", []];
    _vars pushBack ["SC_var_numVehicles", 0];
    _vars pushBack ["SC_var_numVehiclesSides", [0, 0, 0]];
    _vars pushBack ["SC_var_lastDrop", 0];

    // tickets and ticket rates (per minute) per side (order of SC_var_sides), each published as one array
    _vars pushBack ["SC_var_tickets", [0, 0, 0]];
    _vars pushBack ["SC_var_ticketRates", [0, 0, 0]];

    {
        {
            _vars pushBack _x;
        } forEach [

        [("SC_var_units" + (str _x)), []],
        [("SC_var_numUnits" + (str _x)), 0],
        [("SC_var_uavAiUnits" + (str _x)), []],
        [("SC_var_numUavAiUnits" + (str _x)), 0]
        ];
    } forEach [west, east, independent, civilian, sideEmpty, sideLogic, sideAmbientLife, sideUnknown];

    {
        private _side = _x;

        _vars pushBack ["SC_var_last" + (str _side) + "Drop", 0];
        _vars pushBack ["SC_var_planeSpawnSemaphore" + (str _side), false];
        _vars pushBack ["SC_var_vehicleSpawnSemaphore" + (str _side), false];
        _vars pushBack ["SC_var_unitSpawnSemaphore" + (str _side), false];
    } forEach SC_var_sides;

    {
        private _sector = _x;

        _vars pushBack ["SC_var_flag" + _sector, 0];
        _vars pushBack ["SC_var_holder" + _sector, civilian];
        _vars pushBack ["SC_var_owner" + _sector, civilian];
        _vars pushBack ["SC_var_lastOwner" + _sector, civilian];
        _vars pushBack ["SC_var_lastDecapturingSide" + _sector, civilian];
        _vars pushBack ["SC_var_" + _sector + "RespawnPos", []];
    } forEach SC_var_sectors;

    {
        missionNamespace setVariable (_x + [true]);
    } forEach _vars;

    {
        private _sectorInd = _x;
        private _flag3d = missionNamespace getVariable ("SC_var_flag" + _sectorInd + "3d");
        _flag3d setVariable ["SC_var_sectorInd", _sectorInd];
    } forEach SC_var_sectors;

    SC_var_gameModeLoopScript = scriptNull;
    SC_var_zoneLoopScript = scriptNull;
    SC_var_aiLoopScript = scriptNull;
    SC_var_suspendAiLoopScript = scriptNull;
    SC_var_groupLoopScript = scriptNull;

    MM_var_restrictUnitIcons = true;
    publicVariable "MM_var_restrictUnitIcons";

    private _playZoneSize = getMarkerSize "SC_var_playZone";

    SC_var_maxZoneSize = selectMax _playZoneSize;
    publicVariable "SC_var_maxZoneSize";

    TDI_var_ShowGroupIcons = true;
    publicVariable "TDI_var_ShowGroupIcons";

    // the land of the play zone (islands included, the sea not): AI strength, size class, vehicles, ticket rate
    SC_var_mapArea = ["SC_var_playZone"] call SC_fnc_markerLandArea;
    publicVariable "SC_var_mapArea";

    SC_var_mapZoomFactor = switch worldName do {
        case "Malden": {1.3};
        case "Altis": {0.5};
        case "Stratis": {2};
        default {1};
    };

    publicVariable "SC_var_mapZoomFactor";

    {
        _sector = _x;
        private _nearestSectorDistance = selectMin ((SC_var_sectors -[_sector]) apply {(getMarkerPos (
            "SC_var_sector" + _sector)) distance2D (getMarkerPos ("SC_var_sector" + _x))});
        missionNamespace setVariable [("SC_var_nearestSectorDistance" + _sector), _nearestSectorDistance];
    } forEach SC_var_sectors;

    SC_var_parachuteJumpHeight = 15 * (sqrt (sqrt SC_var_mapArea));
    publicVariable "SC_var_parachuteJumpHeight";

    SC_var_mapSize = switch (true) do {
        case (SC_var_mapArea < 700000): {"Small"};
        case (SC_var_mapArea < 2000000): {"Medium"};
        case (SC_var_mapArea < 15000000): {"Large"};
        default {"Huge"};
    };

    SC_var_hugeMap = SC_var_mapSize == "Huge";
    publicVariable "SC_var_hugeMap";

    private _minTicketGainFactor = if SC_var_hugeMap then {0.02} else {0.1};
    SC_var_ticketGainFactor = _minTicketGainFactor max (800 / (SC_var_mapArea ^ 0.66));
    SC_var_wantedUnitAmount = call SC_fnc_populationTarget;

    SC_var_playZoneMiddle = [0, 0, 0];

    {
        SC_var_playZoneMiddle = SC_var_playZoneMiddle vectorAdd (getMarkerPos ("SC_var_sector" + _x));
    } forEach SC_var_sectors;

    SC_var_playZoneMiddle = SC_var_playZoneMiddle vectorMultiply (1 / (count SC_var_sectors));
    publicVariable "SC_var_playZoneMiddle";

    SC_var_vehicleDamageFactor = 0.1 * (("vehicleDamage" call BIS_fnc_getParamValue) + 1);
    publicVariable "SC_var_vehicleDamageFactor";

    SC_var_vehicleSpawnCooldown = 60 * (1 + ("vehicleSpawnCooldown" call BIS_fnc_getParamValue));
    publicVariable "SC_var_vehicleSpawnCooldown";

    // map size dependent settings: [Small, Medium, Large, Huge]
    private _mapSizeIndex = ["Small", "Medium", "Large", "Huge"] find SC_var_mapSize;

    SC_var_minDistanceFromTargetSectorForUnitToUseVehicle = [50, 70, 120, 200] select _mapSizeIndex;
    SC_var_sectorCaptureRate = [6, 5, 4, 2] select _mapSizeIndex;
    SC_var_unitDespawnTime = [30, 45, 60, 480] select _mapSizeIndex;
    SC_var_vehicleDespawnTime = [90, 120, 240, 960] select _mapSizeIndex;
    SC_var_vehicleOwnershipTime = [45, 60, 120, 480] select _mapSizeIndex;
    SC_var_minDistanceFromVehicleToDespawn = [5, 8, 12, 30] select _mapSizeIndex;
    SC_var_minDistanceFromUnitToDespawn = [3, 4.5, 6, 20] select _mapSizeIndex;
    SC_var_timeToDeleteNotMovingVehicle = [60, 90, 120, 360] select _mapSizeIndex;
    SC_var_airDropDurationMins = [2, 5, 10, 15] select _mapSizeIndex;
    private _vehicleArea = call SC_fnc_vehicleAvailabilityArea;
    private _vehicleSizeIndex = {_vehicleArea >= _x} count [700000, 2000000, 15000000];
    SC_var_vehicleHugeMap = _vehicleSizeIndex == 3;
    SC_var_maxVehicleRank = [27, 55, 75, 1000] select _vehicleSizeIndex;
    SC_var_maxVehicleMass = [4000, 14000, 999999, 999999] select _vehicleSizeIndex;
    SC_var_sideDropStep = [25, 15, 10, 7] select _mapSizeIndex;
    SC_var_dropStep = [20, 10, 5, 4] select _mapSizeIndex;
    DW_var_timeBetweenWeatherChangesMultiplierSunny = [1, 1.5, 2, 2] select _mapSizeIndex;
    DW_var_timeBetweenWeatherChangesMultiplierStormy = [0.1, 0.15, 0.2, 0.2] select _mapSizeIndex;

    // AI distances from the sector spacing, then the vehicle budgets (renewed by SC_fnc_aiVehicleLoop)
    call SC_fnc_aiInitTuning;
    call SC_fnc_updateVehicleBudgets;

    // mobile spawn vehicles of every side, [[kind, count], ...] (SC\vehicles\spawnVehicles.sqf); param spawnVehicles:
    // 0 = Auto (by map size), 1 = Off
    SC_var_spawnVehicleKinds = if (("spawnVehicles" call BIS_fnc_getParamValue) == 1) then {[]} else {
        [
        [],
        [["truck", 1]],
        [["truck", 1], ["heli", 1]],
        [["truck", 2], ["bigHeli", 1]]
        ] select _mapSizeIndex
    };

    publicVariable "SC_var_spawnVehicleKinds";

    // seconds until a lost spawn vehicle is back at the base: 30 s on the smallest to 5 min on the largest maps,
    // continuously by the play zone area (logarithmic between 0.4 and 600 km^2), in half minutes
    private _areaShare = 0 max (1 min (((ln (SC_var_mapArea max 1)) - (ln 0.4e6)) / ((ln 600e6) - (ln 0.4e6))));
    SC_var_spawnVehicleRespawnTime = 30 * (round ((30 + 270 * _areaShare) / 30));
    publicVariable "SC_var_spawnVehicleRespawnTime";

    // metres around a spawn vehicle without enemies, so that it is a respawn position
    SC_var_spawnVehicleEnemyRadius = [50, 75, 100, 150] select _mapSizeIndex;
    publicVariable "SC_var_spawnVehicleEnemyRadius";

    // params are read by value (see SC\params.hpp for the texts)
    SC_var_sectorCapturedMessages = "sectorCapturedMessages" call BIS_fnc_getParamValue;

    // 0 = Disabled, 1 = Enabled, 2 = Only on huge maps
    SC_var_spawnVehiclesOnSectors = [false, true, SC_var_hugeMap] select ("spawnVehiclesOnSectors" call BIS_fnc_getParamValue);

    private _timeMultipliers = [0.1, 1, 10, 20, 40, 80, 120];
    private _timeMultiplierDay = _timeMultipliers select ("timeMultiplierDay" call BIS_fnc_getParamValue);
    private _timeMultiplierNight = _timeMultipliers select ("timeMultiplierNight" call BIS_fnc_getParamValue);
    DW_var_changeTimeMultiplierDay = _timeMultiplierDay;
    DW_var_staticTimeMultiplierDay = _timeMultiplierDay;
    DW_var_changeTimeMultiplierNight = _timeMultiplierNight;
    DW_var_staticTimeMultiplierNight = _timeMultiplierNight;

    // skipNight: 0 = Disabled, 1 = Enabled; a mission that starts at night (startTime 3) never skips nights
    DW_var_skipNight = (("skipNight" call BIS_fnc_getParamValue) == 1) && {("startTime" call BIS_fnc_getParamValue) != 3};
    publicVariable "DW_var_skipNight";

    // weather: 0 Dynamic, 1 Dynamic Foggy, 2 Sun, 3 Clouds, 4 Storm, 5 Rain -> presets of the dynamicweather mod
    DW_var_weatherPreset = ["dynamic", "dynamicFoggy", "sunny", "cloudy", "stormy", "rainy"] select ("weather" call BIS_fnc_getParamValue);

    // 0 = Morning, 1 = Noon, 2 = Evening, 3 = Night; morning and evening as bright as on Altis (DW_fnc_startDate)
    DW_var_date = [[2035, 7, 1], "startTime" call BIS_fnc_getParamValue] call DW_fnc_startDate;

    SC_var_allVehicles = [(getArray (missionConfigFile >> "vehicles")) call SC_fnc_filterConfigArr, [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy;
    publicVariable "SC_var_allVehicles";

    SC_var_availableVehicles = SC_var_allVehicles select {
        _x params ["_type", "_rank"];

        (_rank <= SC_var_maxVehicleRank) && {(SC_var_vehicleHugeMap && SC_var_layoutPlaneSpawns) || {!([_type] call SC_fnc_isPlaneType)}} && {
            private _vehicle = _type createVehicleLocal [0, 0, 100];
            private _mass = getMass _vehicle;
            deleteVehicle _vehicle;

            (_mass <= SC_var_maxVehicleMass)
        }
    };

    publicVariable "SC_var_availableVehicles";

    SC_var_availableVehiclesWithoutUnarmedUavs = SC_var_availableVehicles select {
        _x params ["_veh"];

        !(_veh isKindOf "UAV") || {(getArray (configFile >> "CfgVehicles" >> (_x select 0) >> "weapons")) findIf {!(("Horn" in _x) || {"Laser" in _x})} != -1}
    };

    // equipment by rank, used to translate stored loadouts between sides: [[rank, [westItems, eastItems, guerItems]], ...]
    SC_var_nvGogglesByRank = ["NVGoggles", ["general", "%1General", "%1Marksman"]] call SC_fnc_buildItemsByRank;
    publicVariable "SC_var_nvGogglesByRank";

    SC_var_uniformsByRank = ["Uniform", ["%1General", "%1Marksman", "%1Armor"]] call SC_fnc_buildItemsByRank;
    publicVariable "SC_var_uniformsByRank";

    SC_var_helmetsByRank = ["Headgear", ["general", "%1General", "%1Armor"]] call SC_fnc_buildItemsByRank;
    publicVariable "SC_var_helmetsByRank";

    SC_var_vestsByRank = ["Vest", ["%1General", "%1Armor"]] call SC_fnc_buildItemsByRank;
    publicVariable "SC_var_vestsByRank";

    SC_var_backpacksByRank = ["Backpack", ["%1General"]] call SC_fnc_buildItemsByRank;
    publicVariable "SC_var_backpacksByRank";
};

// server: turns a unit into a player unit (called by the client once it is positioned at its base).
// Idempotent; works for a unit that was set up as pool AI (JIP takeover, slot of a player that was connected
// at mission start) as well as for a unit that never was.
SC_fnc_playerServer = {
    params ["_player"];

    if (isNull _player) exitWith {};

    private _side = side (group _player);
    _player hideObjectGlobal false;

    // remove all AI-only state: pool membership, the AI name (setName JIP entry) and the AI bookkeeping
    {
        private _suspendedUnits = missionNamespace getVariable [("SC_var_suspendedUnits" + (str _x)), []];
        private _idx = _suspendedUnits find _player;

        if (_idx != -1) then {
            _suspendedUnits deleteAt _idx;
        };
    } forEach SC_var_sides;

    remoteExec ["", netId _player];

    {
        _player setVariable [_x, nil];
    } forEach ["SC_var_unitId", "SC_var_aiSkill", "SC_var_posAtServerTime"];

    // group locks of a former player of this slot (SC\groupMenu.sqf)
    _player setVariable ["SC_var_groupLocks", nil, true];

    // player name and "[rank] name" labels (the rank is published by the client before it calls this function)
    private _name = name _player;
    private _rankName = format ["[%1] %2", (_player getVariable ["SC_var_rank", 1]), _name];
    _player setVariable ["SC_var_name", _name, true];
    _player setVariable ["TDI_var_name", _rankName, true];
    _player setVariable ["MM_var_name", _rankName, true];

    _player setVariable ["SC_var_side", _side];
    _player setVariable ["SC_var_timeRemaining", SC_var_unitDespawnTime];
    _player setVariable ["SC_var_isWatched", false];

    [_player] call SC_fnc_registerEntityServer;

    // the vehicle spawn cooldown of a player who reconnects is still running
    [getPlayerUID _player] call SC_fnc_sendVehicleCooldown;

    private _id = _player getVariable "SC_var_respawnPositionId";

    if !(isNil "_id") then {
        [_player, _id] call BIS_fnc_removeRespawnPosition;
    };

    [_player] remoteExecCall ["SC_fnc_addHandleHeal", 0];

    [_player] spawn SC_fnc_assignJoiningPlayer;
};
