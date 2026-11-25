// Teamplay XP: transports (passengers dropped off near a target sector, captures by them), defence kills near own
// sectors and vehicle repairs, shown as mid feed XP lines (server; repairs are detected on the client).

SC_var_transportXp = 20;            // per passenger dropped off near a target sector
SC_var_transportCaptureXp = 100;    // when passengers the player dropped off capture that sector
SC_var_transportMinDistance = 300;  // a passenger must have travelled at least this far in the vehicle
SC_var_transportCaptureTime = 600;  // seconds after the drop off in which a capture by the passenger counts
SC_var_defenceXp = 50;              // kill of an enemy in or near a sector of the own side
SC_var_defenceDistance = 100;       // "near": this far outside the sector area
SC_var_repairXp = 50;               // fully repaired vehicle, scaled by the repaired damage
SC_var_repairXpCooldown = 120;      // seconds until the same vehicle gives repair XP again

// server: XP with the Experience perk bonus (x 1.5, rounded to 5) and a mid feed line "You <action> <target> <xp> XP"
SC_fnc_giveTeamplayXp = {
    params ["_unit", "_xp", "_action", "_targetSide", "_targetName"];

    if !(isPlayer _unit) exitWith {};

    if (_unit getVariable ["SC_var_hasExprPerk", false]) then {
        _xp = 1.5 * _xp;
    };

    _xp = 5 * (round (_xp / 5));
    [_unit, _xp] call SC_fnc_giveXp;
    [_unit, _action, _targetSide, _targetName, _xp] call SC_fnc_sendMidFeedXpLine;
};

// first sector (index in SC_var_sectors) whose area plus _distance contains _pos and whose owner is (_owned) / is
// not (!_owned) _side, -1 if none
SC_fnc_findSectorNear = {
    params ["_pos", "_side", "_owned", "_distance"];

    SC_var_sectors findIf {
        private _marker = "SC_var_sector" + _x;

        (((missionNamespace getVariable ("SC_var_owner" + _x)) == _side) isEqualTo _owned) &&
        {(_pos distance2D (getMarkerPos _marker)) < ((selectMax (getMarkerSize _marker)) + _distance)}
    }
};

// ---- transport ----

// server (vehicle loop): remembers the passengers of a vehicle with their boarding position and rewards its player
// driver for passengers of his side that got out near a target sector (not owned by them, within the distance at which
// AI leave their vehicles) after a ride of at least SC_var_transportMinDistance
SC_fnc_updateTransport = {
    params ["_vehicle"];

    private _passengers = ((fullCrew [_vehicle, "cargo"]) + ((fullCrew [_vehicle, "turret"]) select {_x select 4})) apply {_x select 0};
    private _oldPassengers = _vehicle getVariable ["SC_var_transportPassengers", []];
    private _driver = _vehicle getVariable ["SC_var_transportDriver", objNull];

    if (isPlayer _driver) then {
        private _driverSide = side (group _driver);
        private _droppedOff = [];

        {
            _x params ["_unit", "_boardingPos"];

            if (
                (alive _unit) &&
                {!(_unit in _passengers)} &&
                {isNull (objectParent _unit)} &&
                {(side (group _unit)) == _driverSide} &&
                {(_unit distance2D _boardingPos) >= SC_var_transportMinDistance}
            ) then {
                private _sectorIndex =[(getPosWorld _unit), _driverSide, false,
                    SC_var_minDistanceFromTargetSectorForUnitToUseVehicle] call SC_fnc_findSectorNear;

                if (_sectorIndex != -1) then {
                    _unit setVariable ["SC_var_droppedOffBy", [_driver, (SC_var_sectors select _sectorIndex), time]];
                    _droppedOff pushBack _unit;
                };
            };
        } forEach _oldPassengers;

        if (_droppedOff isNotEqualTo []) then {
            private _targetName = if ((count _droppedOff) == 1) then {
                (_droppedOff select 0) getVariable ["SC_var_name", (name (_droppedOff select 0))]
            } else {
                format ["%1 soldiers", (count _droppedOff)]
            };

            [_driver, (SC_var_transportXp * (count _droppedOff)), "dropped off", _driverSide, _targetName] call SC_fnc_giveTeamplayXp;
        };
    };

    _vehicle setVariable ["SC_var_transportPassengers", (_passengers apply {
        private _unit = _x;
        private _index = _oldPassengers findIf {(_x select 0) isEqualTo _unit};

        // a new passenger starts at its current position, a known one keeps where it got in
        if (_index == -1) then {[_unit, (getPosWorld _unit)]} else {_oldPassengers select _index}
    })];
    _vehicle setVariable ["SC_var_transportDriver", (driver _vehicle)];
};

// server: a sector was captured; the player drivers who dropped off some of the capturers there get a bonus once
SC_fnc_rewardTransportCapture = {
    params ["_capturers", "_sector"];

    private _drivers = [];

    {
        (_x getVariable ["SC_var_droppedOffBy", []]) params [["_driver", objNull], ["_dropSector", ""], ["_dropTime", -1e9]];

        if ((_dropSector == _sector) && {(time - _dropTime) < SC_var_transportCaptureTime} && {isPlayer _driver}) then {
            _drivers pushBackUnique _driver;
        };
    } forEach _capturers;

    {
        [_x, SC_var_transportCaptureXp, "supported the capture of", (side (group _x)), _sector] call SC_fnc_giveTeamplayXp;
    } forEach _drivers;
};

// ---- defence ----

// server (kill feed): kill of an enemy in or near a sector of the killer's side
SC_fnc_rewardDefence = {
    params ["_killer", "_victim"];

    if !(isPlayer _killer) exitWith {};

    private _side = side (group _killer);
    private _sectorIndex = [(getPosWorld _victim), _side, true, SC_var_defenceDistance] call SC_fnc_findSectorNear;

    if (_sectorIndex != -1) then {
        [_killer, SC_var_defenceXp, "defended", _side, (SC_var_sectors select _sectorIndex)] call SC_fnc_giveTeamplayXp;
    };
};

// ---- repairs ----

// damage of a vehicle including the mean damage of its hit points (0 - 2)
SC_fnc_getVehicleDamage = {
    params ["_vehicle"];

    private _hitDamages = (getAllHitPointsDamage _vehicle) param [2, []];

    (damage _vehicle) + (if (_hitDamages isEqualTo []) then {0} else {_hitDamages call BIS_fnc_arithmeticMean})
};

// client (UI action "RepairVehicle" of an engineer with a toolkit): waits for the repair and reports it to the server
SC_fnc_watchRepair = {
    params ["_vehicle"];

    private _damageBefore = [_vehicle] call SC_fnc_getVehicleDamage;

    if (_damageBefore <= 0) exitWith {};

    private _timeout = time + 30;

    waitUntil {
        sleep 0.5;

        (([_vehicle] call SC_fnc_getVehicleDamage) < _damageBefore) || {time > _timeout} || {!(alive player)}
    };

    private _repaired = _damageBefore - ([_vehicle] call SC_fnc_getVehicleDamage);

    if (_repaired > 0.05) then {
        [player, _vehicle, _repaired] remoteExecCall ["SC_fnc_rewardRepair", 2];
    };
};

// server: repair XP scaled by the repaired damage, at most once per vehicle within SC_var_repairXpCooldown
SC_fnc_rewardRepair = {
    params ["_unit", "_vehicle", ["_repaired", 0, [0]]];

    if ((isNull _vehicle) || {isRemoteExecuted && {(owner _unit) != remoteExecutedOwner}}) exitWith {};
    if ((time - (_vehicle getVariable ["SC_var_lastRepairXpTime", -1e9])) < SC_var_repairXpCooldown) exitWith {};

    _vehicle setVariable ["SC_var_lastRepairXpTime", time];

    [
        _unit,
        (10 max (SC_var_repairXp * (1 min _repaired))),
        "repaired",
        (side (group _unit)),
        ([typeOf _vehicle] call SC_fnc_getDisplayName)
    ] call SC_fnc_giveTeamplayXp;
};
