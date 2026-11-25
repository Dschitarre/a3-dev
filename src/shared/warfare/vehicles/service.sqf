// Base service: vehicles of a side that stand (almost) still in a service area of its base are repaired, rearmed and
// refueled step by step - the server decides, the machines that own the vehicle / its turrets apply (server); map
// markers of every side's service areas (client).

// ---- constants ----

SC_var_serviceRadius = 20;          // m around the base's vehicle spawn point (ground vehicles, helicopters)
SC_var_servicePlaneRadius = 40;     // m around the base's plane spawn point (huge maps)
SC_var_serviceDuration = 20;        // s for a complete service of a wrecked, empty and dry vehicle
SC_var_serviceInterval = 1;         // s between two service steps
SC_var_serviceMaxSpeed = 5;         // km/h: a faster vehicle is not serviced
SC_var_serviceMaxHeight = 2;        // m above the surface: an aircraft higher up (not landed) is not serviced
SC_var_serviceDoneThreshold = 0.01; // missing share (damage, fuel, ammo) below which a vehicle counts as serviced
SC_var_serviceTimeoutMargin = 10;   // s a service may take longer than SC_var_serviceDuration before it ends anyway

// ---- server ----

// server init: the service areas [side, center object, radius, center position] (published for the map markers: the
// map setup moves the spawn objects on the server, a joining client can still see such a static object at its editor
// position) and the service loop
SC_fnc_initServiceServer = {
    SC_var_servicePoints = [];
    SC_var_servicedVehicles = [];

    {
        private _sideStr = toLower (str _x);
        private _vehicleSpawn = missionNamespace getVariable [("SC_var_" + _sideStr + "VehSpawn"), objNull];
        private _planeSpawn = missionNamespace getVariable [("SC_var_" + _sideStr + "PlaneSpawn"), objNull];

        if !(isNull _vehicleSpawn) then {
            SC_var_servicePoints pushBack [_x, _vehicleSpawn, SC_var_serviceRadius, getPosWorld _vehicleSpawn];
        };

        // planes spawn at the base only on huge maps
        if (
            SC_var_hugeMap &&
            {!(isNull _planeSpawn)} &&
            {(getPosWorld _planeSpawn) inArea ("SC_var_" + _sideStr + "Base")} &&
            {(isNull _vehicleSpawn) || {(_planeSpawn distance2D _vehicleSpawn) > (SC_var_serviceRadius + SC_var_servicePlaneRadius)}}
        ) then {
            SC_var_servicePoints pushBack [_x, _planeSpawn, SC_var_servicePlaneRadius, getPosWorld _planeSpawn];
        };
    } forEach SC_var_sides;

    publicVariable "SC_var_servicePoints";

    SC_var_serviceLoopScript = [] spawn SC_fnc_serviceLoop;
    [] remoteExecCall ["SC_fnc_initServiceClient", 0, true];
};

SC_fnc_serviceLoop = {
    waitUntil {
        private _vehiclesInAreas = [];

        {
            _x params ["_side", "_center", "_radius"];

            {
                if (
                    (alive _x) &&
                    {!(_x isKindOf "StaticWeapon")} &&
                    {!(_x isKindOf "ParachuteBase")} &&
                    {([_x] call SC_fnc_getServiceSide) in [_side, sideUnknown]}
                ) then {
                    _vehiclesInAreas pushBack _x;

                    if ([_x] call SC_fnc_canServiceVehicle) then {
                        [_x] call SC_fnc_serviceVehicle;
                    };
                };
            } forEach (_center nearEntities [["LandVehicle", "Air", "Ship"], _radius]);
        } forEach SC_var_servicePoints;

        // a vehicle that left the service area keeps what it got so far; it starts a new service when it comes back
        {
            _x setVariable ["SC_var_serviceStartTime", nil];
        } forEach (SC_var_servicedVehicles - _vehiclesInAreas);

        SC_var_servicedVehicles = _vehiclesInAreas select {!(isNil {_x getVariable "SC_var_serviceStartTime"})};

        sleep SC_var_serviceInterval;
        false
    };
};

// the side a vehicle belongs to: of its (first living) crew, else its owner side (vehicle registry) or the side of a
// spawn vehicle; sideUnknown if nobody owns it
SC_fnc_getServiceSide = {
    params ["_vehicle"];

    private _crewAlive = (crew _vehicle) select {alive _x};

    if (_crewAlive isNotEqualTo []) exitWith {side (group (_crewAlive select 0))};

    _vehicle getVariable ["SC_var_vehicleSide", (_vehicle getVariable ["SC_var_spawnVehicleSide", sideUnknown])]
};

// stands (almost) still; an aircraft also has to be landed (the engine may run)
SC_fnc_canServiceVehicle = {
    params ["_vehicle"];

    ((abs (speed _vehicle)) <= SC_var_serviceMaxSpeed) &&
    {!(_vehicle isKindOf "Air") || {((getPos _vehicle) select 2) <= SC_var_serviceMaxHeight}}
};

// [repair, fuel, ammo]: the missing share of each (0 = nothing to do), seen from this machine
SC_fnc_getServiceNeeds = {
    params ["_vehicle"];

    private _hitDamages = (getAllHitPointsDamage _vehicle) param [2, []];

    [
        selectMax ([damage _vehicle] + _hitDamages),
        1 - (fuel _vehicle),
        1 - (([_vehicle] call SC_fnc_getAmmoLevels) select 0)
    ]
};

// [lowest, highest] fill level of the vehicle's magazines (1 / 1 without magazines)
SC_fnc_getAmmoLevels = {
    params ["_vehicle"];

    private _levels = (magazinesAllTurrets _vehicle) apply {
        _x params ["_magazine", "", "_ammoCount"];

        private _capacity = getNumber (configFile >> "CfgMagazines" >> _magazine >> "count");

        if (_capacity > 0) then {1 min (_ammoCount / _capacity)} else {1}
    };

    if (_levels isEqualTo []) exitWith {[1, 1]};

    [selectMin _levels, selectMax _levels]
};

// server: one service step of a vehicle in a service area; the crew is told when the service starts and ends
SC_fnc_serviceVehicle = {
    params ["_vehicle"];

    private _needs = [_vehicle] call SC_fnc_getServiceNeeds;
    private _need = selectMax _needs;

    // -2: no service yet, -1: the service ended without filling everything, else its start time
    private _startTime = _vehicle getVariable ["SC_var_serviceStartTime", -2];

    if (_startTime == -1) exitWith {};

    if (_need < SC_var_serviceDoneThreshold) exitWith {
        if (_startTime >= 0) then {
            _vehicle setVariable ["SC_var_serviceStartTime", nil];
            [_vehicle, "Service complete"] call SC_fnc_notifyServiceCrew;
        };
    };

    if (_startTime < 0) then {
        _startTime = time;
        _vehicle setVariable ["SC_var_serviceStartTime", _startTime];

        private _tasks = [];

        {
            if ((_needs select _forEachIndex) >= SC_var_serviceDoneThreshold) then {
                _tasks pushBack _x;
            };
        } forEach ["repairing", "refueling", "rearming"];

        [
            _vehicle,
            format ["Service: %1 (about %2 s), stay in the service area", (_tasks joinString ", "), (ceil (_need * SC_var_serviceDuration))]
        ] call SC_fnc_notifyServiceCrew;
    };

    // something the service can't fill (e.g. a magazine setVehicleAmmo doesn't refill) must not keep it running
    if ((time - _startTime) > (SC_var_serviceDuration + SC_var_serviceTimeoutMargin)) exitWith {
        _vehicle setVariable ["SC_var_serviceStartTime", -1];
        [_vehicle, "Service complete"] call SC_fnc_notifyServiceCrew;
    };

    // repair and fuel where the vehicle is local, ammo also where one of its turrets is (a turret is local to its
    // gunner)
    private _owners = [owner _vehicle];

    {
        _owners pushBackUnique (_vehicle turretOwner _x);
    } forEach (allTurrets [_vehicle, false]);

    // 0 (no owner) would be every machine
    [_vehicle, (SC_var_serviceInterval / SC_var_serviceDuration)] remoteExecCall ["SC_fnc_serviceVehicleStep", (_owners - [0])];
};

SC_fnc_notifyServiceCrew = {
    params ["_vehicle", "_text"];

    private _players = (crew _vehicle) select {isPlayer _x};

    if (_players isNotEqualTo []) then {
        ["vehiclesystem", [_text]] remoteExec ["SC_fnc_showNotificationIfHudIsEnabled", _players];
    };
};

// owner of the vehicle or one of its turrets: one service step of _step (share of a complete service)
SC_fnc_serviceVehicleStep = {
    params ["_vehicle", "_step"];

    if !(alive _vehicle) exitWith {};

    if (local _vehicle) then {
        private _fuel = fuel _vehicle;

        if (_fuel < 1) then {
            _vehicle setFuel ([(_fuel + _step), 1] select ((_fuel + _step) > (1 - SC_var_serviceDoneThreshold)));
        };

        // the overall damage and every hit point; setDamage first, it can change the hit points
        private _damage = damage _vehicle;
        private _hitDamages = (getAllHitPointsDamage _vehicle) param [2, []];
        private _maxDamage = selectMax ([_damage] + _hitDamages);

        if (_maxDamage > 0) then {
            if ((_maxDamage - _step) < SC_var_serviceDoneThreshold) then {
                _vehicle setDamage 0;
            } else {
                _vehicle setDamage [(0 max (_damage - _step)), false];

                {
                    _vehicle setHitIndex [_forEachIndex, (0 max (_x - _step)), false];
                } forEach _hitDamages;
            };
        };
    };

    // setVehicleAmmo sets every magazine to the same level: never below the fullest one, so no magazine loses rounds
    ([_vehicle] call SC_fnc_getAmmoLevels) params ["_lowestLevel", "_highestLevel"];

    if (_lowestLevel < 1) then {
        private _level = (_lowestLevel + _step) max _highestLevel;

        _vehicle setVehicleAmmo ([_level, 1] select (_level > (1 - SC_var_serviceDoneThreshold)));
    };
};

// ---- client ----

// client (JIP message of the server init): map markers of every side's service areas, in the side's marker type
SC_fnc_initServiceClient = {
    if !hasInterface exitWith {};

    [] spawn {
        waitUntil {sleep 0.5; !(isNil "SC_var_servicePoints")};

        {
            _x params ["_pointSide", "_center", "_radius", "_pos"];

            private _sideIndex = [west, east, independent] find _pointSide;

            if (_sideIndex != -1) then {
                private _marker = createMarkerLocal [(format ["SC_var_serviceMarker%1", _forEachIndex]), _pos];
                _marker setMarkerTypeLocal (["b_maint", "o_maint", "n_maint"] select _sideIndex);
                _marker setMarkerTextLocal "Service";
            };
        } forEach SC_var_servicePoints;
    };
};
