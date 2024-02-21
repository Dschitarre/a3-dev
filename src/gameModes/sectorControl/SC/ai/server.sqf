SC_fnc_isUavAi = {
    params ["_unit"];

    "UAV_AI" in (typeOf _unit)
};

SC_fnc_getAiNameArr = {
    params ["_unit"];

    _name = [];
    _ss = (name _unit) splitString " ";
    _sss = (_ss select 0) splitString "-";

    if ((count _sss) > 1) then {
        _name = [
            (((_sss select 0) select [0,1]) + ".-" + ((_sss select 1) select [0,1]) + "."),
            ((_ss select 1) + " (AI)")
        ];
    } else {
        _name = [
            (((_ss select 0) select [0,1]) + "."),
            ((_ss select 1) + " (AI)")
        ];
    };

    ([(_name select 0) + " " + (_name select 1)] + _name)
};

SC_fnc_groupSpawn = {
    params ["_unit", "_groupMate"];

    _parGroupMate = objectParent _groupMate;
    _freeSeats = [];

    if (!(isNull _parGroupMate) && {
        _freeSeats = (fullCrew [_parGroupMate, "", true]) select {isNull (_x select 0)};

        !(_freeSeats isEqualTo [])
    }) then {
        {
            _role = _x;
            _pos = if ((locked _parGroupMate) > 1) then {-1} else {(_freeSeats apply {_x select 1}) find _role};

            if (_pos != -1) exitWith {
                (_freeSeats select _pos) params ["", "", "_cargoIndex", "_turretPath", "_personTurret"];

                switch _role do {
                    case "driver": {[_unit, _parGroupMate] remoteExecCall ["moveInDriver", _unit];};
                    case "gunner": {[_unit, _parGroupMate] remoteExecCall ["moveInGunner", _unit];};
                    case "turret": {[_unit, [_parGroupMate, _turretPath]] remoteExecCall ["moveInTurret", _unit];};
                    case "commander": {[_unit, _parGroupMate] remoteExecCall ["moveInCommander", _unit];};
                    case "cargo": {[_unit, [_parGroupMate, _cargoIndex]] remoteExecCall ["moveInCargo", _unit];};
                };

                if !(isPlayer _unit) then {
                    [_unit] spawn SC_fnc_sendUnitToAnySector;
                };

                if (isPlayer _groupMate) then {
                    _groupMatesInVeh = (([_unit] call SC_fnc_getGroupUnits) - [_unit]) select {(alive _x) && {(objectParent _x) isEqualTo _parGroupMate}};
                    ["groupMateSpawned", [(_unit getVariable "SC_var_name"), ("in your " + ([(typeOf _parGroupMate)] call SC_fnc_getDisplayName))]] remoteExec ["BIS_fnc_showNotification", _groupMatesInVeh];
                };
            };
        } forEach ["driver", "gunner", "turret", "commander", "cargo"];
    } else {
        _safePos = [0, 0];
        _rad = 1;

        waitUntil {
            _pos = getPosWorld _groupMate;
            _pos set [2, 0];

            waitUntil {_pos findEmptyPositionReady [0, _rad]};
            _safePos = _pos findEmptyPosition [0, _rad, "B_soldier_F"];
            _rad = _rad + 1;

            !(_safePos isEqualTo [])
        };

        _unit setPos _safePos;

        if (isPlayer _groupMate) then {
            ["groupMateSpawned", [(_unit getVariable "SC_var_name"), "on your position"]] remoteExec ["BIS_fnc_showNotification", _groupMate];
        };
    };
};
publicVariable "SC_fnc_groupSpawn";

SC_fnc_sendUnitToAnySector = {
    params ["_unit"];

    sleep 0.5;

    _destination = [];
    _movingToSector = _unit getVariable ["SC_var_movingToSector", objNull];

    if (isNull _movingToSector) then {
        _possibleSectors = SC_var_sectors select {(missionNamespace getVariable ("SC_var_owner" + _x)) != (side (group _unit))};
        
        if (_possibleSectors isEqualTo []) then {
            _possibleSectors = SC_var_sectors;
        };

        _destination = getMarkerPos ("SC_var_sector" + (selectRandom _possibleSectors));
    } else {
        _destination = getPosATL _movingToSector;
    };

    //[(group _unit), _destination] remoteExecCall ["move", _unit];
    [_unit, _destination] remoteExecCall ["doMove", (groupOwner (group _unit))];
};

SC_fnc_zoneTimeOut = {
    params ["_unit", "_marker", "_insideForbidden", "_tMax"];

    _t = 0;
    _running = true;
    _unit setVariable ["SC_var_isWatched", true];

    _unitToNotify = if (isplayer _unit) then {
        _unit
    } else {
        _uavControl = [(objectParent _unit), "DRIVER", "GUNNER"] call SC_fnc_UAVControl;

        if (isPlayer _uavControl) then {
            _uavControl
        } else {
            objNull
        }
    };

    if !(isNull _unitToNotify) then {
        _text = if _insideForbidden then {"inEnemyBase"} else {"outsidePlayzone"};
        [_text] remoteExec ["BIS_fnc_showNotification", _unitToNotify];
    };

    while {_running && (alive _unit)} do {
        if (((getPosWorld _unit) inArea _marker) isEqualTo _insideForBidden) then {
            if (_t < _tMax) then {
                _t = _t + 1;
                sleep 1;
            } else {
                if ([_unit] call SC_fnc_isUavAi) then {
                    (objectParent _unit) setDamage 1;
                } else {
                    _unit setDamage 1;
                };
                _running = false;
            };
        } else {
            if !(isNull _unitToNotify) then {
                ["backInPlayzone"] remoteExec ["BIS_fnc_showNotification", _unitToNotify];
            };

            _running = false;
        };
    };

    _unit setVariable ["SC_var_isWatched", false];
};

SC_fnc_suspendUnit = {
    params ["_unit"];

    {_unit leaveVehicle _x;} forEach (assignedVehicles (group _unit));
    unassignVehicle _unit;
    [_unit] join grpNull;
    [_unit] call SC_fnc_deregisterEntityServer;

    [_unit] spawn {
        params ["_unit"];

        waitUntil {
            if (
                [_unit] call {
                    params ["_unit"];
                    
                    if (isNull _unit) exitWith {false};
                    [_unit, [0, 0, 10]] remoteExecCall ["setPos", -2];
                    _unit setPos [0, 0, 10];

                    if ((_unit distance [0, 0, 0]) > 100) then {
                        true
                    } else {
                        while {simulationEnabled _unit} do {
                            _unit enableSimulationGlobal false;
                        };
                        
                        if (_unit in playableUnits) then {
                            _sideStr = str (side (group _unit));

                            if ((random 1) < 0.01) then {
                                _unit call (compile ("SC_var_suspendedUnits" + _sideStr + " = SC_var_suspendedUnits" + _sideStr + " - [objNull];"));
                            };

                            _unit call (compile ("SC_var_suspendedUnits" + _sideStr + " pushBackUnique _this;"));
                            call (compile ('SC_var_suspendedUnits' + _sideStr + ' = [SC_var_suspendedUnits' + _sideStr + ', [], {_x getVariable "SC_var_unitId"}, "ASCEND"] call BIS_fnc_sortBy;'));
                        } else {
                            [_unit] call SC_fnc_removeFromGroup;
                            [_unit] remoteExecCall ["deleteVehicle", _unit];
                        };
                        false
                    }
                }
            ) then {
                sleep 1;
                false
            } else {
                true
            }
        };
    };
};