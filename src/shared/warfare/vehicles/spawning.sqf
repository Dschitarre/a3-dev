// Vehicle spawning: spawn dialog, validation, spawning and cooldowns (both).

// ---- vehicle spawning ----

// seconds after a vehicle spawn request in which the next request of the same player is ignored
SC_var_vehicleRequestBlockTime = 7;

SC_fnc_isPlaneType = {
    params ["_type"];

    (_type isKindOf "Plane_Base_F") || {_type isKindOf "Plane"}
};

// ---- vehicle limit ----

// Players of a side can spawn vehicles while the side has fewer than SC_var_maximumVehicleAmount (no limit on huge
// maps); the AI has its own budget (SC_fnc_aiCanSpawnVehicle). A vehicle counts for the side that used it last
// (SC_fnc_updateVehicleOwnership); the counts per side are published as SC_var_numVehiclesSides.

// server: a vehicle of a side is being spawned: it counts at once (the vehicle loop recounts every few seconds), _isAi:
// spawned for the AI (its budget counts the vehicles spawned for the AI, SC_var_numAiVehiclesSides)
SC_fnc_countSpawnedVehicle = {
    params ["_side", "_isAi"];

    private _sideIndex = SC_var_sides find _side;

    if (_sideIndex == -1) exitWith {};

    SC_var_numVehiclesSides set [_sideIndex, (SC_var_numVehiclesSides select _sideIndex) + 1];
    publicVariable "SC_var_numVehiclesSides";

    if _isAi then {
        if (isNil "SC_var_numAiVehiclesSides") then {
            SC_var_numAiVehiclesSides = SC_var_sides apply {0};
        };

        SC_var_numAiVehiclesSides set [_sideIndex, (SC_var_numAiVehiclesSides select _sideIndex) + 1];
    };
};

// server: the cargo of a spawned vehicle: a toolkit, a Medikit and 10 first aid kits
SC_fnc_setSpawnedVehicleCargo = {
    params ["_vehicle"];

    clearBackpackCargoGlobal _vehicle;
    clearItemCargoGlobal _vehicle;
    clearMagazineCargoGlobal _vehicle;
    clearWeaponCargoGlobal _vehicle;
    _vehicle addItemCargoGlobal ["ToolKit", 1];
    _vehicle addItemCargoGlobal ["Medikit", 1];
    _vehicle addItemCargoGlobal ["FirstAidKit", 10];
};

// client: whether the player can spawn a vehicle type here: "normal" if he can, else why not ("locked": his rank is
// too low, "unavailable": not on this map or not at this place)
SC_fnc_getVehicleSpawnRowState = {
    params ["_type", "_rank"];

    switch true do {
        case ((SC_var_availableVehicles findIf {(_x select 0) == _type}) == -1): {"unavailable"};
        case (!SC_var_currentAllowPlanes && {[_type] call SC_fnc_isPlaneType}): {"unavailable"};

        // boats only at harbours; land vehicles and helicopters there only at one with a vehicle spawn point
        // (SC\vehicles\harbors.sqf)
        case ((_type isKindOf "Ship") && {!(missionNamespace getVariable ["SC_var_currentAtHarbor", false])}): {"unavailable"};
        case (!(_type isKindOf "Ship") && {!([SC_var_currentPlace, _type] call SC_fnc_isHarborSpawnable)}): {"unavailable"};
        case ((player getVariable ["SC_var_rank", 1]) < _rank): {"locked"};
        default {"normal"};
    }
};

// client: the vehicle line of the vehicle spawn dialog ("Vehicles: 7 / 10", in the error color at the limit; only the
// count on huge maps, they have no limit) and the state of every row (SC_var_vehicleSpawnRows: [row controls, type,
// rank])
SC_fnc_updateVehicleSpawnDialog = {
    params ["_dialog"];

    private _count = (missionNamespace getVariable ["SC_var_numVehiclesSides", []]) param [SC_var_sides find (side (group player)), 0];
    private _limit = missionNamespace getVariable ["SC_var_maximumVehicleAmount", 0];
    private _hasLimit = !(missionNamespace getVariable ["SC_var_hugeMap", false]) && {_limit > 0};
    private _ctrl = _dialog displayCtrl 1004;

    _ctrl ctrlSetText ([format ["Vehicles: %1", _count], format ["Vehicles: %1 / %2", _count, _limit]] select _hasLimit);
    _ctrl ctrlSetTextColor ([[1, 1, 1, 1], ["error"] call UI_fnc_color] select (_hasLimit && {_count >= _limit}));

    {
        _x params ["_row", "_type", "_rank"];

        [_row, [_type, _rank] call SC_fnc_getVehicleSpawnRowState] call SC_fnc_styleTableRow;
    } forEach SC_var_vehicleSpawnRows;
};

SC_fnc_setupVehicleSpawnDialog = {
    createDialog "vehicleSpawnDialog";

    _this spawn {
        params ["_allowPlanes", "_place", ["_planeSpawnIdx", -1], ["_atHarbor", false]];

        SC_var_currentPlace = _place;
        SC_var_currentPlaneSpawnIdx = _planeSpawnIdx;
        SC_var_currentAllowPlanes = _allowPlanes;
        SC_var_currentAtHarbor = _atHarbor;
        SC_var_vehicleSpawnRows = [];

        // the list of this place: boats first and then everything else at a harbour, no boats elsewhere
        private _boats = SC_var_allVehicles select {(_x select 0) isKindOf "Ship"};
        SC_var_currentSpawnVehicles = ([[], _boats] select _atHarbor) + (SC_var_allVehicles - _boats);

        private _equipmentDialog = uiNamespace getVariable "SC_var_vehicleSpawnDialog";

        (_equipmentDialog displayCtrl 1600) ctrlAddEventHandler ["ButtonClick", {
            _equipmentDialog = uiNamespace getVariable "SC_var_vehicleSpawnDialog";
            private _controlsTable = _equipmentDialog displayCtrl 1500;
            private _vehicleIndex = ctCurSel _controlsTable;

            // clicked without a selected vehicle
            if (_vehicleIndex == -1) exitWith {};

            (SC_var_currentSpawnVehicles select _vehicleIndex) params ["_type", "_rank"];

            if (([_type, _rank] call SC_fnc_getVehicleSpawnRowState) == "normal") then {
                [player, SC_var_currentPlace, _type, SC_var_currentPlaneSpawnIdx] remoteExec ["SC_fnc_spawnVehicle", 2];
                closeDialog 2;
            };

        }];

        _controlsTable = _equipmentDialog displayCtrl 1500;
        ctClear _controlsTable;
        (ctAddHeader _controlsTable) params ["", "_header"];

        _header params ["",

        "_ctrlHeaderColumn1", "_ctrlHeaderColumn2", "_ctrlHeaderColumn3"
        ];

        [_header] call SC_fnc_styleTableHeader;
        _ctrlHeaderColumn1 ctrlSetText "Picture";
        _ctrlHeaderColumn2 ctrlSetText "Name";
        _ctrlHeaderColumn3 ctrlSetText "Rank";

        // [picture control, picture] of the rows
        private _pictures = [];

        {
            _x params ["_type", "_rank"];

            if (isNull _controlsTable) exitWith {};

            (ctAddRow _controlsTable) params ["", "_row"];
            _row params ["", "_ctrlColumn1", "_ctrlColumn2", "_ctrlColumn3"];

            SC_var_vehicleSpawnRows pushBack [_row, _type, _rank];
            _pictures pushBack [_ctrlColumn1, [_type] call SC_fnc_getPicture];
            _ctrlColumn2 ctrlSetText ([_type] call SC_fnc_getDisplayName);
            _ctrlColumn3 ctrlSetText (str _rank);
        } forEach SC_var_currentSpawnVehicles;

        // the pictures sized by their opaque area, once all rows exist (in case adding a row lays out the others again)
        {
            _x call UI_fnc_setVehiclePicture;
        } forEach _pictures;

        // status line (cooldown), vehicle line and row states, updated while the dialog is open
        _equipmentDialog spawn {
            private _lastCooldown = nil;
            private _lastCounts = nil;

            waitUntil {
                private _cooldown = call SC_fnc_getVehicleCooldown;
                private _counts = [
                missionNamespace getVariable ["SC_var_numVehiclesSides", []],
                missionNamespace getVariable ["SC_var_maximumVehicleAmount", 0],
                player getVariable ["SC_var_rank", 1]
                ];

                if (!(isNull _this) && {isNil "_lastCooldown" || {_cooldown != _lastCooldown}}) then {
                    _lastCooldown = _cooldown;

                    (_this displayCtrl 1003) ctrlSetText (switch true do {
                        case (_lastCooldown < 0): {" Searching for spawn position"};
                        case (_lastCooldown > 0): {"Spawn Cooldown: " + ([_lastCooldown] call SC_fnc_secondsToMinSec) + " min"};
                        default {"   Choose a vehicle to spawn"};

                    });
                };

                if (!(isNull _this) && {isNil "_lastCounts" || {_counts isNotEqualTo _lastCounts}}) then {
                    _lastCounts = +_counts;
                    [_this] call SC_fnc_updateVehicleSpawnDialog;
                };

                (isNull _this)
            };
        };
    };
};

// whether a land vehicle or helicopter can be spawned at a place: true if the place is no harbour; at a harbour only
// with its vehicle spawn point (SC\vehicles\harbors.sqf) and no plane
SC_fnc_isHarborSpawnable = {
    params ["_place", "_type"];

    private _harbor = (missionNamespace getVariable ["SC_var_harbors", []]) select {(_x select 0) == _place};

    (_harbor isEqualTo []) || {!([_type] call SC_fnc_isPlaneType) && {((_harbor select 0) param [4, []]) isNotEqualTo []}}
};

// server-side check of a player's vehicle spawn request (mirrors the checks of the vehicle spawn dialog)
SC_fnc_isVehicleSpawnAllowed = {
    params ["_unit", "_place", "_type", "_planeOrVehSpawnId"];

    private _side = side (group _unit);
    private _vehicleIdx = SC_var_availableVehicles findIf {(_x select 0) == _type};

    if (_vehicleIdx == -1) exitWith {false};

    if ((_unit getVariable ["SC_var_rank", 1]) < ((SC_var_availableVehicles select _vehicleIdx) select 1)) exitWith {false};

    // harbours: boats for every side, land vehicles and helicopters at one with a vehicle spawn point; boats nowhere else
    if (((missionNamespace getVariable ["SC_var_harbors", []]) findIf {(_x select 0) == _place}) != -1) exitWith {
        (_type isKindOf "Ship") || {[_place, _type] call SC_fnc_isHarborSpawnable}
    };

    if (_type isKindOf "Ship") exitWith {false};

    if (_planeOrVehSpawnId != -1) exitWith {

        // airfield vehicle shop
        _planeOrVehSpawnId in SC_var_planeSpawnIds
    };

    if (_place == "the Base") exitWith {true};

    // sector: no planes, only on own sectors and only if sector vehicle spawns are enabled
    !([_type] call SC_fnc_isPlaneType) && {SC_var_spawnVehiclesOnSectors} && {_place in SC_var_sectors} &&
        {(missionNamespace getVariable ("SC_var_owner" + _place)) == _side}
};

// AI vehicles at a spawn point are spread over a ring around it: several AI squads spawn theirs at the same time (e.g. at
// the round start), and vehicles packed together (and soldiers next to them) block each other's way out. A free place
// for the type without other vehicles or men within SC_var_aiVehicleSpawnGap m and at least SC_var_aiVehicleRespawnGap m
// from _keepClear (the base's infantry respawn, where soldiers keep appearing; the vehicle spawn place of a base stands
// right next to it), the inner rings first (at most SC_var_aiVehicleSpawnRange m out); [] if there is none.
SC_var_aiVehicleSpawnGap = 10;
SC_var_aiVehicleRespawnGap = 35;
SC_var_aiVehicleSpawnRange = 110;

SC_fnc_aiVehicleSpawnPos = {
    params ["_pos", "_type", ["_keepClear", []], ["_range", SC_var_aiVehicleSpawnRange]];

    private _result = [];
    private _step = [15, 5] select (_range <= 30);

    for "_ring" from 0 to (_range - _step) step _step do {
        for "_i" from 1 to 6 do {
            private _free = (_pos getPos [_ring + (random _step), random 360]) findEmptyPosition [0, _step / 2 + 1, _type];

            if (
            (_free isNotEqualTo []) && {(_free distance2D _pos) <= _range} && {!(surfaceIsWater _free)} &&
                {(_keepClear isEqualTo []) || {(_free distance2D _keepClear) >= SC_var_aiVehicleRespawnGap}} &&
                {(_free nearEntities [["LandVehicle", "Air", "Ship", "CAManBase"],
                SC_var_aiVehicleSpawnGap]) isEqualTo []}

            ) exitWith {
                _result = _free;
            };
        };

        if (_result isNotEqualTo []) exitWith {};

    };

    _result
};

SC_fnc_spawnVehicle = {
    params ["_unit", "_place", "_type", ["_planeOrVehSpawnId", -1]];

    if (isNull _unit) exitWith {};

    private _wasPlayer = isPlayer _unit;
    private _requestGroup = group _unit;

    if (isNil "_type") exitWith {};

    scopeName "main";

    _side = side (group _unit);
    _isPlane = [_type] call SC_fnc_isPlaneType;

    // UID of the requesting player ("" for AI); his cooldowns are kept per UID on the server
    private _playerUid = "";

    if (isPlayer _unit) then {

        // player requests come from the client, so they are validated here as well
        if !([_unit, _place, _type, _planeOrVehSpawnId] call SC_fnc_isVehicleSpawnAllowed) then {
            ["vehiclesystem", ["This vehicle cannot be spawned here"]] remoteExec ["BIS_fnc_showNotification", _unit];
            breakOut "main";
        };

        _playerUid = getPlayerUID _unit;

        if !([_unit, _playerUid, _side] call SC_fnc_startVehicleSpawnRequest) then {
            breakOut "main";
        };
    };

    // a harbour (SC\vehicles\harbors.sqf): boats at its boat spawn point, the others at its vehicle spawn point
    private _harborIndex = (missionNamespace getVariable ["SC_var_harbors", []]) findIf {(_x select 0) == _place};
    private _isBoat = _type isKindOf "Ship";

    private _pos = switch (true) do {
        case (_harborIndex != -1): {(SC_var_harbors select _harborIndex) select ([4, 2] select _isBoat)};
        case (_planeOrVehSpawnId != -1): {
            getPosATL (missionNamespace getVariable ("SC_var_" + (if _isPlane then {"plane"} else {"veh"}) + "Spawn" + (str _planeOrVehSpawnId)))
        };
        case (_place == "the Base"): {
            getPosATL (missionNamespace getVariable ("SC_var_" + (str _side) + (if _isPlane then {"Plane"} else {"Veh"}) + "Spawn"))
        };
        default {getMarkerPos ("SC_var_sector" + _place)};
    };

    _safePos = [];
    private _rad = 7;

    _semaphoreVar = if (_harborIndex != -1) then {
        (["SC_var_harborVehicleSpawnSemaphore", "SC_var_boatSpawnSemaphore"] select _isBoat) + (str _harborIndex)
    } else {
        "SC_var_" + (["vehicle", "plane"] select _isPlane) + "SpawnSemaphore" + ([(toLower (str _side)), (str _planeOrVehSpawnId)] select (_planeOrVehSpawnId != -1))
    };

    if (isNil _semaphoreVar) exitWith {
        [_playerUid, 0] call SC_fnc_endVehicleSpawnRequest;
    };

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

    private _startTime = serverTime;

    if (!_wasPlayer && {!([_unit, _requestGroup, _pos] call SC_fnc_aiVehicleRequestStillNeeded)}) exitWith {
        missionNamespace setVariable [_semaphoreVar, false];
        ["vehicle", _requestGroup, _type, "cancelled", "request no longer needed"] call SC_fnc_aiLog;
    };

    // AI vehicles are spread over the place (SC_fnc_aiVehicleSpawnPos), a player's vehicle stands as close as possible
    private _spreadOut = !_wasPlayer && {!_isPlane};

    if ((_harborIndex != -1) && _isBoat) then {
        _safePos = [_pos] call SC_fnc_boatSpawnPos;
    };

    waitUntil {
        if ((isNil "_safePos") || {_safePos isEqualTo []}) then {
            if ((_harborIndex != -1) && _isBoat) exitWith {true};

            waitUntil {_pos findEmptyPositionReady [0,[_rad, SC_var_aiVehicleSpawnRange] select _spreadOut] ||
                {(serverTime - _startTime) > 5}};
            if ((serverTime - _startTime) > 5) exitWith {true};

            _safePos = if _spreadOut then {
                [_pos, _type, [[], getMarkerPos ("SC_var_" + (toLower (str _side)) + "Respawn")] select (_place == "the Base")] call SC_fnc_aiVehicleSpawnPos
            } else {

                _pos findEmptyPosition [0, _rad, _type]
            };

            _rad = _rad + 1.5;

            ((serverTime - _startTime) > 5)
        } else {

            true
        }
    };

    if (!_wasPlayer && {!([_unit, _requestGroup, _pos] call SC_fnc_aiVehicleRequestStillNeeded)}) then {_safePos = []};

    if (_safePos isEqualTo []) then {
        missionNamespace setVariable [_semaphoreVar, false];

        if (isPlayer _unit) then {
            ["vehiclesystem", ["Vehicle could not be spawned, cooldown reset."]] remoteExec ["BIS_fnc_showNotification", _unit];
        };

        [_playerUid, 0] call SC_fnc_endVehicleSpawnRequest;
    } else {

        _veh = [_type, _safePos] call {
            params ["_type", "_safePos"];

            _veh = createVehicle [_type, _safePos, [], 7, "NONE"];
            _veh setVariable ["BIS_enableRandomization", false];
            [_veh, false] call ADG_fnc_allowDamage;
            _veh disableTIEquipment true;

            _veh
        };

        waitUntil {!(isNull _veh)};

        // damage handler and actions on every machine; the JIP entry is removed with the vehicle
        [_veh] remoteExecCall ["SC_fnc_initSpawnedVehicle", 0, _veh];

        _veh setVariable ["SC_var_lockerUid", "", true];
        _veh setVariable ["SC_var_spawnerUid", _playerUid, true];
        _veh setVariable ["SC_var_vehicleSide", _side, true];
        _veh setVariable ["SC_var_timeRemaining", SC_var_vehicleDespawnTime];
        _veh setVariable ["SC_var_posAtServerTime", [_safePos, serverTime]];
        _veh setVariable ["KF_var_side", _side];
        [_veh] call SC_fnc_registerEntityServer;

        if _isPlane then {
            _veh setDir (getDir (missionNamespace getVariable (

            if (_planeOrVehSpawnId != -1) then {
                "SC_var_planeSpawn" + (str _planeOrVehSpawnId)
            } else {

                "SC_var_" + (str _side) + "PlaneSpawn"
            }

            )));
        };

        // a boat points away from the harbour's shop, out to the water
        if ((_harborIndex != -1) && _isBoat) then {
            _veh setDir ((SC_var_harbors select _harborIndex) select 3);
        };

        _veh setUnloadInCombat [true, false];
        _veh allowCrewInImmobile [false, false];

        [_semaphoreVar, _isPlane, _veh] spawn {
            params ["_semaphoreVar", "_isPlane", "_veh"];

            if _isPlane then {
                _pos = getPosWorld _veh;

                waitUntil {
                    sleep 1;

                    (isNull _veh) || {!(alive _veh)} || {!(canMove _veh)} ||
                        {((getPosWorld _veh) distance _pos) > 30} ||
                        {((crew _veh) findIf {alive _x}) == -1}
                };
            } else {

                sleep 4;
            };

            missionNamespace setVariable [_semaphoreVar, false];
        };

        private _typeString = [_type] call SC_fnc_getDisplayName;
        private _textEnd = format ["spawned a%1 at %2",
            ((if((_typeString select [0, 1]) in ["A", "E", "I", "O",
            "U"]) then {"n "} else {" "}) + _typeString), _place];
        private _grpUnits = ([_unit] call SC_fnc_getGroupUnits) - [_unit];

        if (_grpUnits isNotEqualTo []) then {
            ["vehiclesystem", [format ["Your groupmate %1 %2", (_unit getVariable "SC_var_name"), _textEnd]], _grpUnits] call SC_fnc_notifyPlayers;
        };

        [_playerUid, SC_var_vehicleSpawnCooldown] call SC_fnc_endVehicleSpawnRequest;

        if ((isPlayer _unit) && {_wasPlayer}) then {
            private _unitText = "You " + _textEnd;
            ["vehiclesystem", [_unitText]] remoteExec ["SC_fnc_showNotificationIfHudIsEnabled", _unit];
        } else {

            if !(unitIsUAV _veh) then {
                (group _unit) addVehicle _veh;
                _unit assignAsDriver _veh;
                _unit moveInDriver _veh;

                if !(isPlayer _unit) then {
                    [_unit] call SC_fnc_aiAdoptVehicle;
                };
            };
        };

        (group _unit) setCombatBehaviour "COMBAT";
        _unit setCombatBehaviour "COMBAT";
        (group _unit) setCombatMode "RED";
        _unit setUnitCombatMode "RED";
        _unit enableAI "all";
        _unit setUnitPos "AUTO";

        [_veh] call SC_fnc_setSpawnedVehicleCargo;

        if (unitIsUAV _veh) then {
            _side createVehicleCrew _veh;
            private _crew = crew _veh;
            private _grpCrew = createGroup [_side, true];
            _crew joinSilent _grpCrew;
            _grpCrew setCombatBehaviour "COMBAT";
            _grpCrew setCombatMode "RED";

            {
                _x setCombatBehaviour "COMBAT";
                _x setUnitCombatMode "RED";
                _x enableAI "all";

                _x setVariable ["SC_var_isWatched", false];

                [_x] call SC_fnc_registerEntityServer;
            } forEach _crew;

            {
                _x linkItem "ItemMap";
                _x linkItem "ItemGPS";
                _x linkItem "H_PilotHelmetFighter_B";
            } forEach (crew _veh);

            if ((isPlayer _unit) && {!_wasPlayer}) exitWith {};

            // A terminal connection is local to its operator. Connecting an AI on
            // a dedicated server creates a GUI terminal slot without a local player;
            // Arma 3 2.22 crashes when that UAV is subsequently damaged/destroyed.
            // AI pilots remain autonomous; only players need a terminal connection.
            if (isPlayer _unit) then {
                [_unit, _veh] remoteExecCall ["connectTerminalToUAV", _unit];
            };
        };

        // a player's vehicle at a harbour: he takes the wheel at once (the shop stands next to the spawn points)
        if ((_harborIndex != -1) && {isPlayer _unit} && {_wasPlayer}) then {
            [_unit, _veh] remoteExecCall ["moveInDriver", _unit];
        };

        if ((_harborIndex == -1) && {(count _place) > 1} && {_planeOrVehSpawnId == -1}) then {
            if ((isPlayer _unit) && _wasPlayer) then {
                [_unit, _veh] remoteExecCall ["moveInDriver", _unit];
            };

            [_veh, _safePos, _side] spawn {
                params ["_veh", "_safePos", "_side"];

                private _baseMarker = "SC_var_" + (str _side) + "Base";
                private _radiusProtected = 0.7 * ((((getMarkerSize _baseMarker) select 0) + ((getMarkerSize _baseMarker) select 1)) / 2);
                private _baseMarkerPos = getMarkerPos _baseMarker;

                waitUntil {
                    sleep 1;
                    ((_veh distance _baseMarkerPos) > _radiusProtected)
                };

                [_veh, true] call ADG_fnc_allowDamage;
                private _playersInCrew = (crew _veh) select {isPlayer _x};

                if (_playersInCrew isNotEqualTo []) then {
                    ["vehiclesystem", ["Your vehicle is now vulnerable"], _playersInCrew] call SC_fnc_notifyPlayers;
                };
            };
        } else {

            [_veh] spawn {
                params ["_veh"];

                sleep 3;

                if (alive _veh) then {
                    [_veh, true] call ADG_fnc_allowDamage;
                };
            };
        };
    };
};

// runs on every machine for a vehicle spawned by SC_fnc_spawnVehicle or a spawn vehicle (SC\vehicles\spawnVehicles.sqf,
// not lockable) (JIP entry keyed to the vehicle)
SC_fnc_initSpawnedVehicle = {
    params ["_veh", ["_isLockable", true]];

    if (isNull _veh) exitWith {};

    [_veh] call SC_fnc_addHandleDamageToVehicle;

    if !hasInterface exitWith {};

    // locking on the key J (SC_fnc_keyVehicleLock, SC\vehicles\handling.sqf) instead of scroll actions
    _veh setVariable ["SC_var_lockable", _isLockable];
};

// ---- vehicle spawn cooldowns ----

// The server keeps the cooldowns per player UID (SC_var_vehicleCooldowns: UID -> [spawn cooldown end, request block
// end] in server time, a request block end of -1 while a spawn is in progress), so they survive a reconnect.
// The client only displays them.

// server: checks the cooldowns and the vehicle limit of the side for a player's spawn request and marks the spawn as in
// progress (true, the vehicle counts for the side at once) or rejects it
SC_fnc_startVehicleSpawnRequest = {
    params ["_unit", "_uid", "_side"];

    (SC_var_vehicleCooldowns getOrDefault [_uid, [0, 0]]) params ["_cooldownEnd", "_requestBlockEnd"];

    if (_requestBlockEnd < 0) exitWith {
        ["vehicleCooldown", ["Vehicle spawn is in progress"]] remoteExec ["BIS_fnc_showNotification", _unit];
        false
    };

    if (time < _requestBlockEnd) exitWith {false};

    private _rejection = switch true do {
        case (time < _cooldownEnd): {
            "Vehicle spawn cooldown active: " + ([_cooldownEnd - time] call SC_fnc_secondsToMinSec)
        };
        case (!SC_var_hugeMap && {(SC_var_numVehiclesSides select (SC_var_sides find _side)) >= SC_var_maximumVehicleAmount}): {
            "The maximum number of vehicles has been reached"
        };
        default {""};
    };

    if (_rejection != "") exitWith {
        ["vehicleCooldown", [_rejection]] remoteExec ["BIS_fnc_showNotification", _unit];
        SC_var_vehicleCooldowns set [_uid, [_cooldownEnd, time + SC_var_vehicleRequestBlockTime]];
        false
    };

    SC_var_vehicleCooldowns set [_uid, [_cooldownEnd, -1]];
    [_uid] call SC_fnc_sendVehicleCooldown;
    [_side, false] call SC_fnc_countSpawnedVehicle;
    true
};

// server: ends a player's spawn request (no-op for AI, _uid ""); the spawn cooldown _cooldown (seconds) starts now
SC_fnc_endVehicleSpawnRequest = {
    params ["_uid", "_cooldown"];

    if (_uid == "") exitWith {};

    SC_var_vehicleCooldowns set [_uid, [time + _cooldown, time + SC_var_vehicleRequestBlockTime]];
    [_uid] call SC_fnc_sendVehicleCooldown;
};

// server: sends a connected player his remaining spawn cooldown (-1 while a spawn is in progress) for display
SC_fnc_sendVehicleCooldown = {
    params ["_uid"];

    private _players = allPlayers select {(getPlayerUID _x) == _uid};

    if (_players isEqualTo []) exitWith {};

    (SC_var_vehicleCooldowns getOrDefault [_uid, [0, 0]]) params ["_cooldownEnd", "_requestBlockEnd"];
    [([0 max (_cooldownEnd - time), -1] select (_requestBlockEnd < 0))] remoteExecCall ["SC_fnc_setVehicleCooldown", _players];
};

// client: remaining spawn cooldown sent by the server, counted down with the client's own clock
SC_fnc_setVehicleCooldown = {
    params ["_remainingTime"];

    SC_var_vehicleCooldownEnd = [time + _remainingTime, -1] select (_remainingTime < 0);
};

// client: remaining spawn cooldown in whole seconds, -1 while a spawn is in progress
SC_fnc_getVehicleCooldown = {
    if (SC_var_vehicleCooldownEnd < 0) exitWith {-1};

    0 max (ceil (SC_var_vehicleCooldownEnd - time))
};
