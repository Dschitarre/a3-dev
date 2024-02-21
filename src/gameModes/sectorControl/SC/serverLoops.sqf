SC_fnc_aiLoop = {
    waitUntil {
        _sleepTime = 6 / (1 max (SC_var_numunitsWest + SC_var_numunitsEast + SC_var_numunitsGuer + SC_var_numuavAiUnitsWest + SC_var_numuavAiUnitsEast + SC_var_numuavAiUnitsGuer));

        {
            _x params ["_side"];

            {
                _x params ["_unit"];
                
                scopeName "unitLoop";

                if (alive _unit) then {
                    if !(isPlayer _unit) then {
                        if (_unit getVariable ["AIS_unconscious", false]) then {
                            _unconsciousSince = _unit getVariable ["AIS_unconscious_since", -999];

                            if ((_unconsciousSince >= 0) && {(random 10) < ((time - _unconsciousSince) / AIS_BLEEDOUT_TIME)}) then {
                                _unit setDamage 1;
                            };
                        } else {
                            _par = objectParent _unit;
                            _group = group _unit;

                            /*
                            
                            if ((isNull _par) && {(combatBehaviour _group) != "COMBAT"}) then {
                                _group setCombatBehaviour "COMBAT";
                            } else {
                                if (!(isNull _par) && {(combatBehaviour _group) != "AWARE"}) then {
                                    _group setCombatBehaviour "AWARE";
                                };
                            };

                            if ((isNull _par) && {(combatBehaviour _unit) != "COMBAT"}) then {
                                _unit setCombatBehaviour "COMBAT";
                            } else {
                                if (!(isNull _par) && {(combatBehaviour _unit) != "AWARE"}) then {
                                    _unit setCombatBehaviour "AWARE";
                                };
                            };

                            if ((combatMode _group) != "RED") then {
                                _group setCombatMode "RED";
                            };

                            if ((unitCombatMode _unit) != "RED") then {
                                _unit setUnitCombatMode "RED";
                            };

                            */

                            if (!([_unit] call SC_fnc_isUavAi) && {!(" (AI)" in (name _unit))}) then {
                                if (isNull _par) then {
                                    [_unit] remoteExecCall ["deleteVehicle", 2];
                                } else {
                                    [_par, _unit] remoteExecCall ["deleteVehicleCrew", 2];
                                };

                                breakTo "unitLoop";
                            };

                            if (_unit inArea "SC_var_spawnArea") then {
                                [_unit] call SC_fnc_suspendUnit;
                                breakTo "unitLoop";
                            };

                            if (([_unit] call SC_fnc_isUavAi)) then {
                                _enableAI = (([_par] call SC_fnc_UAVControlUnits) findIf {isplayer _x}) == -1;

                                {
                                    if ((_x checkAIFeature "MOVE") != _enableAI) then {
                                        [_x, ["ALL", _enableAI]] remoteExecCall ["enableAIFeature", (owner _x)];
                                    };
                                } forEach (crew _par);

                                if !_enableAI then {
                                    breakTo "unitLoop";
                                };
                            };
                            
                            if (isNull (_unit getVariable ["AIS_isHelper", objNull])) then {
                                if !([_unit] call SC_fnc_isUavAi) then {
                                    (_unit getVariable "SC_var_posAtServerTime") params ["_lastPos", "_lastTime"];

                                    if ((serverTime - _lastTime) > 60) then {
                                        _pos = getPosWorld _unit;

                                        if ((_pos distance _lastPos) < 2) then {
                                            [_unit] call SC_fnc_suspendUnit;
                                            breakTo "unitLoop";
                                        } else {
                                            _unit setVariable ["SC_var_posAtServerTime", [_pos, serverTime]];
                                        };
                                    };
                                };

                                (expectedDestination _unit) params ["_currentDestination", "_planningMode"];
                                
                                _currentDestination = _currentDestination select [0, 2];
                                _oldSector = _unit getVariable ["SC_var_movingToSector", objNull];
                                _destination = [];

                                if (
                                    (isNull _oldSector) ||
                                    {(currentCommand _unit) != "MOVE"} ||
                                    {(missionNamespace getVariable [("SC_var_owner" + (_oldSector getVariable "SC_var_sectorInd")), civilian]) == _side} ||
                                    {_currentDestination isEqualTo [0, 0]} ||
                                    {!(_currentDestination inArea ("SC_var_sector" + (_oldSector getVariable "SC_var_sectorInd")))}
                                ) then {
                                    _possibleSectors = [];
                                    _wantedSector = "";

                                    {
                                        _sectorInd = _x;
                                        _sectorFlag = missionNameSpace getVariable ("SC_var_flag" + _sectorInd + "3d");
                                        _owner = missionNamespace getVariable ("SC_var_owner" + _sectorInd);

                                        if (_owner != _side) then {
                                            _possibleSectors pushBack _sectorFlag;
                                        };
                                    } forEach SC_var_sectors;

                                    if !(_possibleSectors isEqualTo []) then {
                                        if ((count _possibleSectors) > 1) then {
                                            _possibleSectors = [_possibleSectors, [], {_x distance _unit}, "ASCEND"] call BIS_fnc_sortBy;
                                            _wantedSector = if ((_unit distance (_possibleSectors select 0)) < 30) then {
                                                _possibleSectors select 0;
                                            } else {
                                                _possibleSectors select (floor (random [0, 0.5, ((count _possibleSectors) - 1)]))
                                            };
                                        } else {
                                            _wantedSector = _possibleSectors select 0;
                                        };
                                    } else {
                                        _wantedSector = missionNameSpace getVariable ("SC_var_flag" + (selectRandom SC_var_sectors) + "3d");
                                    };

                                    _unit setVariable ["SC_var_movingToSector", _wantedSector];
                                    _unit setVariable ["SC_var_movingToSectorInd", (_wantedSector getVariable "SC_var_sectorInd")];
                                    _wantedSectorMarker = "SC_var_sector" + (_wantedSector getVariable "SC_var_sectorInd");

                                    while {((count _destination) < 3) || {surfaceIsWater _destination}} do {
                                        _destination = [_wantedSectorMarker] call BIS_fnc_randomPosTrigger;
                                    };
                                } else {
                                    _oldSectorMarker = "SC_var_sector" + (_oldSector getVariable "SC_var_sectorInd");
                                    _maxOldSectorSize = selectMax (getMarkerSize _oldSectorMarker);

                                    if (((getpos _unit) distance2D _currentDestination) < (12 min (0.07 * _maxOldSectorSize))) then {
                                        _destination = [];

                                        while {
                                            ((count _destination) < 3) ||
                                            {surfaceIsWater _destination} ||
                                            {(_destination distance2D _currentDestination) < (0.3 * _maxOldSectorSize)}
                                        } do {
                                            _destination = [_oldSectorMarker] call BIS_fnc_randomPosTrigger;
                                        };
                                    } else {
                                        _destination = _currentDestination;
                                    };
                                };

                                if (!(isNull _par) && {_unit isEqualTo (driver _par)} && {!((effectiveCommander _par) isEqualTo _unit)}) then {
                                    _par setEffectiveCommander _unit;
                                };

                                if !([_unit] call SC_fnc_isUavAi) then {
                                    _group = group _unit;
                                    _nearestAssignedVehicle = objNull;
                                    _distanceToNearestAssignedVehicle = 99999;

                                    if (isNull _par) then {
                                        {
                                            _vehicle = _x;
                                            _distanceToVehicle = -1;

                                            if ((alive _vehicle) && {(locked _vehicle) <= 1} && {
                                                ((fullCrew _vehicle) findIf {
                                                    _x params ["", "", "", "", "", "_assignedUnit"];
                                                    
                                                    (_unit isEqualTo _assignedUnit)
                                                }) != -1} && {
                                                    _distanceToVehicle = _unit distance _vehicle;
                                                    (_distanceToVehicle < _distanceToNearestAssignedVehicle)
                                                }
                                            ) then {
                                                _distanceToNearestAssignedVehicle = _distanceToVehicle;
                                                _nearestAssignedVehicle = _vehicle;
                                            };
                                        } forEach (assignedVehicles _group);
                                    } else {
                                        _nearestAssignedVehicle = _par;
                                        
                                        if !(_par in (assignedVehicles _group)) then {
                                            _group addVehicle _par;
                                            _fullCrew = fullCrew _par;
                                            _posUnit = _fullCrew findIf {(_x select 0) isEqualTo _unit};

                                            (_fullCrew select _posUnit) params ["", "_role", "", "_turretPath"];

                                            switch _role do {
                                                case {"driver"}: {_unit assignAsDriver _par;};
                                                case {"commander"}: {_unit assignAsCommander _par;};
                                                case {"gunner"}: {_unit assignAsGunner _par;};
                                                case {"turret"}: {_unit assignAsTurret [_par, _turretPath];};
                                            };

                                            [_unit] allowGetIn true;
                                            [_unit] orderGetIn true;
                                        };
                                    };

                                    {_group leaveVehicle _x;} forEach ((assignedVehicles _group) - [_nearestAssignedVehicle]);

                                    _targetSectorMarker = "SC_var_sector" + (_unit getVariable "SC_var_movingToSectorInd");
                                    _maxTargetSectorSize = selectMax (getMarkerSize _targetSectorMarker);
                                    _distanceToSector = (_unit distance2D (getMarkerPos _targetSectorMarker)) - _maxTargetSectorSize;

                                    if (isNull _par) then {
                                        if (_distanceToSector > (1.3 * SC_var_minDistanceFromTargetSectorForUnitToUseVehicle)) then {
                                            // should but doesnt use vehicle

                                            _nearGroundVehicles = (getPosATL _unit) nearEntities [["Car_F", "Tank_F"], (_distanceToSector min SC_var_maxDistanceToUseableGroundVehicle)];
                                            _bestVehicleYet = objNull;
                                            _distanceToBestVehicleYet = 99999;

                                            {
                                                _vehicle = _x;
                                                _distance = -1;

                                                if (
                                                    (alive _vehicle) &&
                                                    {(locked _vehicle) <= 1} &&
                                                    {((crew _vehicle) findIf {(side (group _x)) != _side}) == -1} &&
                                                    {((fullCrew [_vehicle, "", true]) findIf {!(alive (_x select 0)) && {isNull (_x select 5)}}) != -1} &&
                                                    {
                                                        _distance = _unit distance _vehicle;
                                                        (_distance < _distanceToBestVehicleYet)
                                                    }
                                                ) then {
                                                    _distanceToBestVehicleYet = _distance;
                                                    _bestVehicleYet = _vehicle;
                                                };
                                            } forEach _nearGroundVehicles;

                                            if ((isNull _bestVehicleYet) || {_nearestAssignedVehicle isKindOf "Helicopter_Base_F"}) then {
                                                _nearHelicopters = (getPosATL _unit) nearEntities [["Helicopter_Base_F"], (_distanceToSector min SC_var_maxDistanceToUseableHelicopter)];

                                                {
                                                    _vehicle = _x;
                                                    _distance = -1;

                                                    if (
                                                        (alive _vehicle) &&
                                                        {(locked _vehicle) <= 1} &&
                                                        {((crew _vehicle) findIf {(side (group _x)) != _side}) == -1} &&
                                                        {((fullCrew [_vehicle, "", true]) findIf {!(alive (_x select 0)) && {isNull (_x select 5)}}) != -1} &&
                                                        {
                                                            _distance = _unit distance _vehicle;
                                                            (_distance < _distanceToBestVehicleYet)
                                                        }
                                                    ) then {
                                                        _distanceToBestVehicleYet = _distance;
                                                        _bestVehicleYet = _vehicle;
                                                    };
                                                } forEach _nearGroundVehicles;
                                            };

                                            if (_distanceToBestVehicleYet < _distanceToNearestAssignedVehicle) then {
                                                // there is another better vehicle available, so switch to this one

                                                _group leaveVehicle _nearestAssignedVehicle;
                                                doGetOut _unit;
                                                _group addVehicle _bestVehicleYet;

                                                _fullCrew = fullCrew [_bestVehicleYet, "", true];
                                                _posRole = _fullCrew findIf {!(alive (_x select 0)) && {isNull (_x select 5)}};

                                                (_fullCrew select _posRole) params ["", "_role", "", "_turretPath"];

                                                switch _role do {
                                                    case {"driver"}: {_unit assignAsDriver _bestVehicleYet;};
                                                    case {"commander"}: {_unit assignAsCommander _bestVehicleYet;};
                                                    case {"gunner"}: {_unit assignAsGunner _bestVehicleYet;};
                                                    case {"turret"}: {_unit assignAsTurret [_bestVehicleYet, _turretPath];};
                                                };

                                                [_unit] allowGetIn true;
                                                [_unit] orderGetIn true;
                                            } else {
                                                if (
                                                    SC_var_hugeMap &&
                                                    {(_unit distance2D (getMarkerPos ("SC_var_" + (str _side) + "Respawn"))) > 100} &&
                                                    {
                                                        (isNull _nearestAssignedVehicle) ||
                                                        {
                                                            _distanceToNearestAssignedVehicle >
                                                            (if ((_nearestAssignedVehicle isKindOf "Car_F") || {_nearestAssignedVehicle isKindOf "Tank_F"}
                                                            ) then {SC_var_maxDistanceToUseableGroundVehicle} else {SC_var_maxDistanceToUseableHelicopter})
                                                        }
                                                    }
                                                ) then {
                                                    [_unit] call SC_fnc_suspendUnit;
                                                };
                                            };
                                        };
                                    } else {
                                        if (
                                            (_par isKindOf "Helicopter_Base_F") &&
                                            {(random 1) < 0.2} &&
                                            {((assignedVehicleRole _unit) select 0) == "cargo"} &&
                                            {((getPosAtl _par) select 2) > 100} &&
                                            {_par inArea "SC_var_playZone"}
                                        ) then {
                                            [_unit, _par] spawn SC_fnc_heliParachuteJump;
                                        };

                                        if (SC_var_hugeMap && {_distanceToSector < SC_var_minDistanceFromTargetSectorForUnitToUseVehicle}) then {
                                            // should not but does use vehicle

                                            _group leaveVehicle _nearestAssignedVehicle;
                                            doGetOut _unit;
                                        };
                                    };
                                };

                                if (!(_destination isEqualTo []) && {!(_destination isEqualTo _currentDestination)}) then {
                                    //[(group _unit), _destination] remoteExecCall ["move", (owner _unit)];
                                    [_unit, _destination] remoteExecCall ["doMove", (groupOwner _group)];
                                };
                            };
                        };
                    };
                } else {
                    if !([_unit] call SC_fnc_isUavAi) then {
                        _timeRemaining = _unit getVariable "SC_var_timeRemaining";

                        if (!(isNil "_timeRemaining") && {_timeRemaining > 0}) then {
                            _isInBase = (getPosWorld _unit) inArea ("SC_var_" + (str (side (group _unit))) + "Base");
                            _minDistanceFromUnitToDespawn = [SC_var_minDistanceFromUnitToDespawn, 1] select _isInBase;

                            _distanceNearest = [_unit, ["CAManBase"], 3 * _minDistanceFromUnitToDespawn] call SC_fnc_distanceOfNearestObject;

                            if (_distanceNearest < _minDistanceFromUnitToDespawn) then {
                                _timeRemaining = SC_var_unitDespawnTime min (_timeRemaining + (4 * (_minDistanceFromUnitToDespawn - _distanceNearest)));
                            } else {
                                _timeRemaining = 0 max (_timeRemaining - (_distanceNearest - _minDistanceFromUnitToDespawn));
                            };

                            if (_timeRemaining <= 0) then {
                                if (isPlayer _unit) then {
                                    _unit enableSimulationGlobal false;
                                    _unit setPos [0, 0, 10];
                                } else {
                                    [_unit] call SC_fnc_suspendUnit;
                                };
                            } else {
                                _unit setVariable ["SC_var_timeRemaining", _timeRemaining];
                            };
                        };
                    };
                };

                sleep _sleepTime;
            } forEach (([_side] call SC_fnc_getSidesUnits) + ([_side] call SC_fnc_getSidesUavAiUnits));
        } forEach SC_var_sides;

        _newNumVehiclesSides = [0, 0, 0];
        _sleepTime = 3 / (1 max SC_var_numVehicles);

        {
            _vehicle = _x;
            
            _crew = crew _vehicle;
            _checkIfAlone = false;
            _deleted = false;

            if ((speed _vehicle) > (switch true do {
                case (_vehicle isKindOf "Car_F"): {400};
                case (_vehicle isKindOf "Tank_F"): {200};
                case (_vehicle isKindOf "Helicopter_F"): {600};
                default {1000};
            })) then {
                {
                    if (isPlayer _x) then {
                        _x enableSimulationGlobal false;
                        _x setPosWorld [0, 0, 10];

                        if (alive _x) then {
                            forceRespawn _x;
                        };
                    } else {
                        [_x] call SC_fnc_suspendUnit;
                    };
                } forEach _crew;

                [_vehicle] remoteExec ["SC_fnc_safelyDeleteVehicle", (owner _vehicle)];
                
                _deleted = true;
            };

            if !_deleted then {
                if !(alive _vehicle) then {
                    _checkIfAlone = true;
                } else {
                    _pos = getPos _vehicle;

                    if (_vehicle isKindOf "Helicopter") then {
                        if (!(unitIsUAV _vehicle) && {
                            _var = (effectiveCommander _vehicle) getVariable "SC_var_movingToSectorInd";

                            (_vehicle distance ((effectiveCommander _vehicle) getVariable ["SC_var_movingToSector", objNull])) <
                            (if ((isNil "_var") || {_var == ""}) then {0} else {(selectMax getMarkerSize ("SC_var_sector" + _var)) + 100})
                        }) then {
                            _vehicle land "LAND";
                        } else {
                            _vehicle land "NONE";
                        };

                        if ((((vectorUp _vehicle) select 2) < 0) && {(_pos select 2) < 10}) then {
                            _surfaceNormal = surfaceNormal _pos;

                            [[_vehicle, _pos, _surfaceNormal], {
                                params ["_vehicle", "_pos", "_surfaceNormal"];

                                _vehicle setVectorUp _surfaceNormal;
                                _vehicle setPos _pos;
                                _vehicle setVelocity [0, 0, 0];

                                sleep 0.1;

                                _vehicle setVectorUp _surfaceNormal;
                                _vehicle setPos _pos;
                                _vehicle setVelocity [0, 0, 0];
                            }] remoteExecCall ["spawn", (owner _vehicle)];
                        };
                    } else {
                        if ((_vehicle isKindOf "Plane_Base_F") || {_vehicle isKindOf "Plane"}) then {
                            _vehicle land "NONE";
                        };
                    };

                    _crewAlive = _crew select {alive _x};
                    (_vehicle getVariable "SC_var_posAtServerTime") params ["_lastPos", "_lastTime"];

                    if ((serverTime - _lastTime) > SC_var_timeToDeleteNotMovingVehicle) then {
                        if (((_pos distance _lastPos) < 10) && {(_crewAlive findIf {isPlayer _x}) == -1} && {(([_vehicle] call SC_fnc_UAVControlUnits) findIf {isPlayer _x}) == -1}) then {
                            if !(_crew isEqualTo []) then {
                                if ((_pos select 2) > 5) then {
                                    {
                                        if (isPlayer _x) then {
                                            _x enableSimulationGlobal false;
                                            _x setPosWorld [0, 0, 10];
                                        } else {
                                            [_x] call SC_fnc_suspendUnit;
                                        };
                                    } forEach _crew;
                                } else {
                                    _pos set [2, 0];

                                    {
                                        _unit = _x;

                                        _safePos = [];
                                        _rad = 3;

                                        waitUntil {
                                            waitUntil {_pos findEmptyPositionReady [0, _rad]};
                                            _safePos = _pos findEmptyPosition [0, _rad, "box_NATO_equip_F"];
                                            _rad = _rad + 1;

                                            !(_safePos isEqualTo [])
                                        };

                                        _unit setPos _safePos;
                                    } forEach _crew;
                                };
                            };

                            [_vehicle] remoteExec ["SC_fnc_safelyDeleteVehicle", (owner _vehicle)];
                            
                            _deleted = true;
                        } else {
                            _vehicle setVariable ["SC_var_posAtServerTime", [_pos, serverTime]];
                        };
                    };
                    
                    if !_deleted then {
                        if ((_crewAlive isEqualTo []) || {(((getPosATL _vehicle) select 2) < 5) && {!(canMove _vehicle)}}) then {
                            _checkIfAlone = true;
                        };

                        {
                            _x params ["_crewUnit", "", "", "", "", "_assignedUnit"];

                            if ((alive _crewUnit) && {!(_assignedUnit isEqualTo _crewUnit)}) then {
                                (group _assignedUnit) leaveVehicle _vehicle;
                            };
                        } forEach (fullCrew _vehicle);

                        /*
                        _rolePriority = ["driver", "gunner", "turret", "commander"];

                        {
                            _targetRole = _x;
                            _emptyPositions = (fullCrew [_vehicle, _targetRole, true]) - (fullCrew [_vehicle, _targetRole, false]);

                            
                        } forEach _rolePriority;
                        */

                        if !(_crewAlive isEqualTo []) then {
                            _sideIndex = SC_var_sides find (side (group (_crewAlive select 0)));
                            _newNumVehiclesSides set [_sideIndex, (_newNumVehiclesSides select _sideIndex) + 1];
                        };                        
                    };
                };

                if (!_deleted && {_checkIfAlone}) then {
                    _timeRemaining = _vehicle getVariable "SC_var_timeRemaining";

                    if !(isNil "_timeRemaining") then {
                        _posVehicle = getPosWorld _vehicle;
                        _isInBase = (SC_var_sides findIf {_posVehicle inArea ("SC_var_" + (str _x) + "Base")}) != -1;
                        _minDistanceFromVehicleToDespawn = [SC_var_minDistanceFromVehicleToDespawn, 1] select _isInBase;
                        _despawnTimeDepletionFactor = [1, 5] select _isInBase;

                        _distanceNearest = [_vehicle, ["CAManBase"], 2 * _minDistanceFromVehicleToDespawn] call SC_fnc_distanceOfNearestObject;

                        if (_distanceNearest < _minDistanceFromVehicleToDespawn) then {
                            _timeRemaining = SC_var_vehicleDespawnTime min (_timeRemaining + (4 * (_minDistanceFromVehicleToDespawn - _distanceNearest)));
                        } else {
                            _timeRemaining = 0 max (_timeRemaining - (_despawnTimeDepletionFactor * (_distanceNearest - _minDistanceFromVehicleToDespawn)));
                        };

                        if (_timeRemaining <= 0) then {
                            _posVehicle = getPos _vehicle;

                            {
                                _x setPos _posVehicle;
                            } forEach _crew;

                            [_vehicle] remoteExec ["SC_fnc_safelyDeleteVehicle", (owner _vehicle)];
                        } else {
                            _vehicle setVariable ["SC_var_timeRemaining", _timeRemaining];
                        };
                    };
                };
            };

            sleep _sleepTime;
        } forEach SC_var_vehicles;

        SC_var_numVehiclesSides = _newNumVehiclesSides;
        publicVariable "SC_var_numVehiclesSides";

        false
    };
};