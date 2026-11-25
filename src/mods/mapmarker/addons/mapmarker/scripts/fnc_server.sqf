// Map markers (server): settings, the side / icon / name of every unit and vehicle as public variables, positions of
// far entities for the clients that show them, and starting / stopping the markers.

MM_var_serverRunning = false;
MM_var_entityCreatedEhId = -1;
MM_var_entityKilledEhId = -1;
MM_var_entityRespawnedEhId = -1;
MM_var_playerDisconnectedEhId = -1;
MM_var_remoteExecId = "";
MM_var_entities = [];                  // entities whose positions are sent (multiplayer)
MM_var_viewers = createHashMap;        // client owner -> sides whose positions it needs (MM_fnc_setClientShownSides)
MM_var_broadcastUnitPosAndDirLoopScript = scriptNull;

// ---- settings ----
// Game modes and the module overwrite these later.

private _mapSizeConfig = configFile >> "CfgWorlds" >> worldName >> "mapSize";

MM_var_mapScaleFactor = if (isNull _mapSizeConfig) then {
    private _centerPos = getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition");
    0.0000001 * (_centerPos select 0) * (_centerPos select 1)
} else {
    0.00035 * getNumber _mapSizeConfig
};

// Beyond the object view distance a client knows an entity only from what the server sends: position, direction,
// velocity and turn rate, which the client continues (dead reckoning, MM_fnc_farPosAndDir) for at most
// MM_var_predictionTime seconds. The server sends an entity again once the client's continuation deviates from the real
// position or direction by more than MM_var_minMoveDistance / MM_var_minTurnAngle (also when it stops or turns).
MM_var_posBroadcastInterval = 0.3;    // seconds between two position batches
MM_var_minMoveDistance = 1;           // metres the continued position may deviate before the entity is sent again
MM_var_minTurnAngle = 4;              // degrees the continued direction may deviate before the entity is sent again
MM_var_predictionTime = 3;            // seconds a client continues an entity's last movement

MM_var_showAllSides = false;
MM_var_showAllSidesOnSpectator = false;
MM_var_showUnitNames = true;
MM_var_showUnitNamesOnlyOnHover = false;
MM_var_showAliveGroupUnits = true;
MM_var_restrictUnitIcons = false;
MM_var_showOwnUnitOnly = false;       // only the viewed unit itself, no other units (e.g. free for all)

{
    publicVariable _x;
} forEach [
    "MM_var_mapScaleFactor",
    "MM_var_posBroadcastInterval",
    "MM_var_predictionTime",
    "MM_var_showAllSides",
    "MM_var_showAllSidesOnSpectator",
    "MM_var_showUnitNames",
    "MM_var_showUnitNamesOnlyOnHover",
    "MM_var_showAliveGroupUnits",
    "MM_var_restrictUnitIcons",
    "MM_var_showOwnUnitOnly"
];

// ---- entities ----
// The clients build the unit names themselves (MM_fnc_unitName) and read the side of living units from their group;
// the server announces the side and controller a unit had at its init and death (for dead units).

// generic icons of vehicles without a usable own icon: [kind, CfgVehicleIcons entry], the first kind wins
MM_var_genericVehicleIcons = [
    ["Car_F", "iconCar"],
    ["Helicopter_Base_F", "iconHelicopter"],
    ["Tank_F", "iconTank"],
    ["Plane_Base_F", "iconPlane"],
    ["Plane", "iconPlane"],
    ["Ship_F", "iconShip"]
];
MM_var_vehicleIconCache = createHashMap;   // vehicle class -> icon

// a CfgVehicleIcons entry or a texture path. Paths are taken as they are: fileExists did not find the addon textures
// on the dedicated server, so every vehicle fell back to its generic icon (drones got the helicopter icon)
MM_fnc_isValidIcon = {
    params ["_icon"];

    if (_icon == "") exitWith {false};
    if ((_icon find "\") == -1) exitWith {isText (configFile >> "CfgVehicleIcons" >> _icon)};

    true
};

// the vehicle's own top-down map icon (config "icon", drawn in the side color: the vanilla icons are white), else a
// generic icon of its kind; cached per class. Stored as in the config - MM_fnc_vehicleIconScale normalizes the key.
MM_fnc_getIcon = {
    params ["_object"];

    private _type = typeOf _object;
    private _icon = MM_var_vehicleIconCache get _type;

    if (isNil "_icon") then {
        _icon = getText (configOf _object >> "icon");

        if !([_icon] call MM_fnc_isValidIcon) then {
            private _index = MM_var_genericVehicleIcons findIf {_object isKindOf (_x select 0)};

            _icon = if (_index == -1) then {"iconStaticAA"} else {(MM_var_genericVehicleIcons select _index) select 1};
        };

        MM_var_vehicleIconCache set [_type, _icon];
    };

    _icon
};

MM_fnc_entityInitServer = {
    params ["_entity"];

    // the name and group of a new unit can be missing for a moment
    private _timeout = time + 3;
    waitUntil {isNull _entity || {name _entity != ""} || {time > _timeout}};

    if (isNull _entity) exitWith {};

    if !(_entity getVariable ["MM_var_initDone", false]) then {
        _entity setVariable ["MM_var_initDone", true];

        if (_entity isKindOf "CAManBase") then {
            _entity setVariable ["MM_var_side", side group _entity, true];
        } else {
            _entity setVariable ["MM_var_icon", [_entity] call MM_fnc_getIcon, true];
            _entity setVariable ["MM_var_name", getText (configFile >> "CfgVehicles" >> typeOf _entity >> "displayName"), true];
        };

        if (isMultiplayer) then {
            MM_var_entities pushBackUnique _entity;
        };
    };

    [[_entity], {
        if (!isNil "MM_var_clientInitDone") then {
            _this call MM_fnc_entityInitClient;
        };
    }] remoteExecCall ["call", 0];
};

// a dead unit keeps the side and the controller (player or AI) of its death
MM_fnc_entityKilled = {
    params ["_unit"];

    if (!(_unit isKindOf "CAManBase") || {!(_unit getVariable ["MM_var_initDone", false])}) exitWith {};

    if (!isNull group _unit) then {
        _unit setVariable ["MM_var_side", side group _unit, true];
    };

    _unit setVariable ["MM_var_wasPlayer", isPlayer _unit, true];
};

// ---- positions ----
// Beyond its object view distance a client gets only rare position updates from the engine, so the server sends the
// positions and directions of the entities that moved, batched per side - only to the clients that show that side
// and only while they draw a map, GPS or UAV terminal.

// the entities whose positions are sent: a unit in a vehicle goes with the vehicle
MM_fnc_isBroadcast = {
    params ["_entity"];

    !isNull _entity && {simulationEnabled _entity} && {!(_entity isKindOf "CAManBase") || {isNull objectParent _entity}}
};

// the side whose clients draw an entity: a unit's side or a vehicle's crew side; a vehicle without living crew only
// for the side a game mode shows it to while empty (MM_var_showWhenEmpty), else (crew of dead units only) for theirs
MM_fnc_viewSide = {
    params ["_entity"];

    private _isUnit = _entity isKindOf "CAManBase";
    private _crew = if (_isUnit) then {[_entity]} else {crew _entity};
    private _emptySide = if (_isUnit) then {sideUnknown} else {_entity getVariable ["MM_var_showWhenEmpty", sideUnknown]};

    if (_emptySide isNotEqualTo sideUnknown && {(_crew findIf {alive _x}) == -1}) exitWith {_emptySide};

    private _unit = _crew param [0, objNull];

    if (isNull _unit) exitWith {sideUnknown};
    if (alive _unit && {!isNull group _unit}) exitWith {side group _unit};

    _unit getVariable ["MM_var_side", sideUnknown]
};

// signed difference of two directions in degrees (-180..180)
MM_fnc_angleDiff = {
    params ["_a", "_b"];

    ((_a - _b + 540) % 360) - 180
};

// [entity, position, direction, velocity, turn rate (degrees per second, from the direction one pass ago)]
MM_fnc_posAndDir = {
    params ["_entity"];

    private _now = diag_tickTime;
    private _dir = getDirVisual _entity;
    (_entity getVariable ["MM_var_dirSample", [_dir, _now - 1]]) params ["_lastDir", "_lastTime"];
    private _turnRate = if ((_now - _lastTime) > 0.05) then {([_dir, _lastDir] call MM_fnc_angleDiff) / (_now - _lastTime)} else {0};

    _entity setVariable ["MM_var_dirSample", [_dir, _now]];
    [_entity, (getPosWorldVisual _entity) select [0, 2], _dir, (velocity _entity) select [0, 2], _turnRate]
};

// Called by every client (MM_fnc_reportShownSidesLoop): the sides it shows while it draws a map, [] otherwise. A
// client that starts to show a side gets the current positions of its entities at once.
MM_fnc_setClientShownSides = {
    params ["_sides"];

    private _owner = remoteExecutedOwner;
    private _newSides = _sides - (MM_var_viewers getOrDefault [_owner, []]);

    if (_sides isEqualTo []) then {
        MM_var_viewers deleteAt _owner;
    } else {
        MM_var_viewers set [_owner, _sides];
    };

    if (_newSides isEqualTo []) exitWith {};

    private _updates = (MM_var_entities select {
        ([_x] call MM_fnc_isBroadcast) && {([_x] call MM_fnc_viewSide) in _newSides}
    }) apply {[_x] call MM_fnc_posAndDir};

    if (_updates isNotEqualTo []) then {
        [_updates] remoteExecCall ["MM_fnc_updateServerPosAndDirBatch", _owner];
    };
};

MM_fnc_broadcastPositions = {
    private _receivers = createHashMap;   // side -> client owners

    {
        private _owner = _x;

        {
            private _owners = _receivers getOrDefault [_x, []];

            _owners pushBack _owner;
            _receivers set [_x, _owners];
        } forEach _y;
    } forEach MM_var_viewers;

    private _updates = createHashMap;     // side -> [[entity, pos, dir], ...]

    {
        if ([_x] call MM_fnc_isBroadcast) then {
            private _side = [_x] call MM_fnc_viewSide;

            if (_side in _receivers) then {
                private _update = [_x] call MM_fnc_posAndDir;
                _update params ["", "_pos", "_dir"];
                // where the clients continue the entity to (the same continuation as MM_fnc_farPosAndDir)
                (_x getVariable ["MM_var_lastSent", [[-1e6, -1e6], 0, [0, 0], 0, -1e6]]) params ["_lastPos", "_lastDir", "_lastVelocity", "_lastTurnRate", "_lastTime"];
                private _elapsed = (diag_tickTime - _lastTime) min MM_var_predictionTime;
                private _predictedPos = _lastPos vectorAdd (_lastVelocity vectorMultiply _elapsed);
                private _predictedDir = _lastDir + _lastTurnRate * _elapsed;

                if (
                    (_pos distance2D _predictedPos) > MM_var_minMoveDistance ||
                    {abs ([_dir, _predictedDir] call MM_fnc_angleDiff) > MM_var_minTurnAngle}
                ) then {
                    private _sideUpdates = _updates getOrDefault [_side, []];

                    _x setVariable ["MM_var_lastSent", [_pos, _dir, _update select 3, _update select 4, diag_tickTime]];
                    _sideUpdates pushBack _update;
                    _updates set [_side, _sideUpdates];
                };
            };
        };
    } forEach MM_var_entities;

    {
        [_y] remoteExecCall ["MM_fnc_updateServerPosAndDirBatch", _receivers get _x];
    } forEach _updates;
};

MM_fnc_broadcastUnitPosAndDirLoop = {
    waitUntil {
        private _passStart = diag_tickTime;

        // deleted entities
        if ((MM_var_entities findIf {isNull _x}) != -1) then {
            MM_var_entities = MM_var_entities select {!isNull _x};
        };

        if (count MM_var_viewers > 0) then {
            call MM_fnc_broadcastPositions;
        };

        sleep (0 max (MM_var_posBroadcastInterval - (diag_tickTime - _passStart)));
        false
    };
};

// ---- start / stop ----

MM_fnc_startMapMarkerServer = {
    if (MM_var_serverRunning) exitWith {};

    MM_var_serverRunning = true;

    private _entities = entities [["AllVehicles"], ["Animal"], true, false];

    if (isMultiplayer) then {
        MM_var_entities = +_entities;
    };

    {
        [_x] spawn MM_fnc_entityInitServer;
    } forEach _entities;

    MM_var_entityCreatedEhId = addMissionEventHandler ["EntityCreated", {
        params ["_entity"];

        if (_entity isKindOf "AllVehicles" && {!(_entity isKindOf "Animal")}) then {
            [_entity] spawn MM_fnc_entityInitServer;
        };
    }];

    MM_var_entityKilledEhId = addMissionEventHandler ["EntityKilled", {_this call MM_fnc_entityKilled}];

    if (isMultiplayer) then {
        // the mission event fires here for every unit (the object's "Respawn" event only where the unit is local)
        MM_var_entityRespawnedEhId = addMissionEventHandler ["EntityRespawned", {
            params ["_newEntity", "_oldEntity"];

            private _index = MM_var_entities find _oldEntity;

            if (_index != -1) then {
                MM_var_entities deleteAt _index;
            };

            MM_var_entities pushBackUnique _newEntity;
        }];

        MM_var_playerDisconnectedEhId = addMissionEventHandler ["PlayerDisconnected", {
            params ["", "", "", "", "_owner"];

            MM_var_viewers deleteAt _owner;
        }];

        MM_var_broadcastUnitPosAndDirLoopScript = [] spawn MM_fnc_broadcastUnitPosAndDirLoop;
    } else {
        // a loaded singleplayer savegame has lost the event handlers: restart
        MM_var_loadedEhId = addMissionEventHandler ["Loaded", {
            call MM_fnc_stopMapMarkerServer;

            [] spawn {
                waitUntil {!MM_var_serverRunning};
                call MM_fnc_startMapMarkerServer;
            };
        }];
    };

    MM_var_remoteExecId = [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "MM_var_clientInitDone"};
        call MM_fnc_startMapMarkerClient;
    }] remoteExecCall ["spawn", 0, true];
};

MM_fnc_stopMapMarkerServer = {
    if (!MM_var_serverRunning) exitWith {};

    MM_var_serverRunning = false;

    if (isMultiplayer) then {
        terminate MM_var_broadcastUnitPosAndDirLoopScript;
        MM_var_broadcastUnitPosAndDirLoopScript = scriptNull;

        removeMissionEventHandler ["EntityRespawned", MM_var_entityRespawnedEhId];
        removeMissionEventHandler ["PlayerDisconnected", MM_var_playerDisconnectedEhId];
        MM_var_entityRespawnedEhId = -1;
        MM_var_playerDisconnectedEhId = -1;

        {
            _x setVariable ["MM_var_initDone", nil];
        } forEach MM_var_entities;

        MM_var_entities = [];
        MM_var_viewers = createHashMap;
    } else {
        removeMissionEventHandler ["Loaded", MM_var_loadedEhId];
        MM_var_loadedEhId = nil;
    };

    removeMissionEventHandler ["EntityCreated", MM_var_entityCreatedEhId];
    removeMissionEventHandler ["EntityKilled", MM_var_entityKilledEhId];
    MM_var_entityCreatedEhId = -1;
    MM_var_entityKilledEhId = -1;

    remoteExecCall ["", MM_var_remoteExecId];
    MM_var_remoteExecId = "";

    [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "MM_var_clientInitDone"};
        call MM_fnc_stopMapMarkerClient;
    }] remoteExecCall ["spawn", 0];
};

MM_var_serverInitDone = true;
