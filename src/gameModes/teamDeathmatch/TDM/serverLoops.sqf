DM_fnc_gameModeLoop = {
    _sides = [west, east];
    _winSide = civilian;
    _id = false;
    _vehicleHdl = scriptNull;
    DM_fnc_playZoneLoopHdl = [] spawn DM_fnc_playZoneLoop;

    // set map
    if DM_var_alternatingMaps then {
        [(selectRandom (DM_var_randomMapRotation select [1, ((count DM_var_randomMapRotation) - 1)])) , (selectRandom [true, false])] call DM_fnc_applyMap;
    };

    // set loadouts
    if DM_var_loadoutsRestricted then {
        _id = [[2 * DM_var_minPointsToWin, ([2 * DM_var_minPointsToWin] call DM_fnc_calculateItems)], {
            if hasInterface then {
                waitUntil {!(isNil "DM_fnc_applyItemsOnArsenal")};
                _this spawn DM_fnc_applyItemsOnArsenal;
            };
        }] remoteExecCall ["spawn", 0, true];
    };

    [4] call DM_fnc_setRespawnTimeTo;

    // prepare warmup and spawn vehicles
    _aiWarmupHdl = [] spawn DM_fnc_aiWarmup;
    if DM_var_vehiclesEnabled then {
        call DM_fnc_spawnVehiclesForSides;
        _vehicleHdl = [] spawn DM_fnc_vehicleLoop;
    };

    // wait until players are ready
    waitUntil {[false, true] call DM_fnc_allPlayersReady};

    // start warmup
    DM_var_timerHdl = ["warmupTime" call BIS_fnc_getParamValue] spawn DM_fnc_timer;
    ["teamDeathmatch", ["Warmup started"]] call DM_fnc_showNotificationGlobal;

    // wait for end of warmup
    waitUntil {scriptDone DM_var_timerHdl};

    //stop warmup
    terminate _aiWarmupHdl;
    call DM_fnc_resetPlayerScores;

    // start gameMode
    waitUntil {
        // switch to new round
        terminate DM_fnc_playZoneLoopHdl;

        if DM_var_alternatingMaps then {
            (call DM_fnc_getCurrentMap) call DM_fnc_applyMap;
        } else {
            if (DM_var_roundNumber == DM_var_minPointsToWin && {DM_var_minPointsToWin != 1}) then {
                call DM_fnc_switchSides;
            };
        };

        [false] call DM_fnc_movement;
        call DM_fnc_setAllPlayersToSpawn;
        
        sleep 1;

        call DM_fnc_despawnAi;
        call DM_fnc_cleanUp;
        [4] call DM_fnc_setRespawnTimeTo; // respawns dead players
        _relRoundNumber = [DM_var_roundNumber] call DM_fnc_relativeRoundNumber;
        [[2 * DM_var_minPointsToWin, _relRoundNumber] select DM_var_loadoutsRestricted] spawn DM_fnc_balanceAi;
        ["teamDeathmatch", ["Waiting for other players"]] call DM_fnc_showNotificationGlobal;
        DM_fnc_playZoneLoopHdl = [] spawn DM_fnc_playZoneLoop;

        // wait until players are ready
        waitUntil {[false, true] call DM_fnc_allPlayersReady};

        // start equip phase
        [DM_var_roundNumber] call DM_fnc_roundStartedNotification;
        _id = [_relRoundNumber] call DM_fnc_spawnSpawnSpawnGlobal;
        DM_var_timerHdl = [30] spawn DM_fnc_timer;

        sleep 2;

        // spawn vehicles
        if DM_var_vehiclesEnabled then {
            call DM_fnc_spawnVehiclesForSides;
            _vehicleHdl = [] spawn DM_fnc_vehicleLoop;
        };

        sleep 3;

        // start round after equip phase is over or all players are ready
        waitUntil {(scriptDone DM_var_timerHdl) || ([true, true] call DM_fnc_allPlayersReady)};

        if !(scriptDone DM_var_timerHdl) then {
            terminate DM_var_timerHdl;
        };

        [true] call DM_fnc_gameRunning;
        [true] call DM_fnc_movement;

        if !(_id isEqualType true) then {
            remoteExec ["", _id];
        };

        ["teamDeathmatch", ["Round started. Zone shrinks in 30 seconds"]] call DM_fnc_showNotificationGlobal;
        [9999] call DM_fnc_setRespawnTimeTo; // disables respawn

        // start zone shrinking
        if DM_var_zoneShrinkEnabled then {
            DM_var_timerHdl = [30] spawn DM_fnc_timer;

            waitUntil {
                if (scriptDone DM_var_timerHdl) then {
                    ["zone"] call DM_fnc_showNotificationGlobal;
                    DM_var_roundHdl = [] spawn DM_fnc_zoneShrink;

                    true
                } else {
                    call DM_fnc_oneTeamDead
                }
            };
        };
        call DM_fnc_setTimerTo0;

        // wait until round is over
        waitUntil {call DM_fnc_oneTeamDead};
        if !(scriptDone DM_var_roundHdl) then {
            terminate DM_var_roundHdl;
        };
        if !(scriptDone _vehicleHdl) then {
            terminate _vehicleHdl;
        };

        // get winner of round
        _winSide = call DM_fnc_getWinSide;
        [_winSide] call DM_fnc_increaseSidesScore;

        // end round
        [([_winSide] call DM_fnc_getSidestring) + "wonThisRound"] call DM_fnc_showNotificationGlobal;
        [false] call DM_fnc_gameRunning;
        call DM_fnc_resetPlayZone;
        call DM_fnc_setTimerTo0;

        // wait another 3 seconds
        if !(scriptDone DM_var_timerHdl) then {
            terminate DM_var_timerHdl;
        };
        DM_var_timerHdl = [3] spawn DM_fnc_timer;

        waitUntil {scriptDone DM_var_timerHdl};

        // end mission
        if (((DM_var_westPoints max DM_var_eastPoints) >= DM_var_minPointsToWin) && (!DM_var_requireLeadOfTwoPoints || ((abs (DM_var_westPoints - DM_var_eastPoints)) >= 2))) then {
            (toLower (str _winSide)) call BIS_fnc_endMissionServer;
            true
        } else {
            DM_var_roundNumber = DM_var_roundNumber + 1;
            publicVariable "DM_var_roundNumber";
            false
        }
    };
};

DM_fnc_vehicleLoop = {
    waitUntil {
        _vehicles = vehicles;
        _sleepTime = 5 / (1 + (count _vehicles));
        
        {
            _vehicle = _x;

            _crew = (crew _vehicle) select {alive _x};

            _unitsInArea = (getPosATL _vehicle) nearEntities (if (_crew isEqualTo []) then {50} else {[(
                switch (side (group (_crew select 0))) do {
                    case west: {"B_Soldier_F"};
                    case east: {"O_Soldier_F"};
                    case independent: {"I_Soldier_F"};
            }), 20]});

            _assignedUnits = _unitsInArea select {(assignedVehicle _x) isEqualTo _vehicle};
            _assignedUnitsCargo = _assignedUnits select {((assignedVehicleRole _x) select 0) == "cargo"};

            {
                unassignVehicle _x;
            } forEach _assignedUnitsCargo;

            _assignedUnits = _assignedUnits - _assignedUnitsCargo;
            _freeUnitsInArea = _unitsInArea select {!(isPlayer _x) && {isNull (assignedVehicle _x)}};
            _numFreeUnitsInArea = count _freeUnitsInArea;

            _neededCrew = (fullCrew [_vehicle, "", true]) select {(isNull (_x select 0)) && {(_x select 1) != "cargo"}};
            _neededCrew = _neededCrew select {!((_x select 0) in _assignedUnits)};
            _numNeededCrew = count _neededCrew;

            if (_numFreeUnitsInArea < _numNeededCrew) then {
                _neededCrew = _neededCrew select [0, _numFreeUnitsInArea];
            };

            {
                _x params ["", "_role", "_turretPath", "_personTurret"];

                _unit = _freeUnitsInArea select 0;
                _freeUnitsInArea deleteAt 0;

                (group _unit) addVehicle _vehicle;

                switch _role do {
                    case {"driver"}: {
                        _unit assignAsDriver _vehicle;
                    };
                    case {"commander"}: {
                        _unit assignAsCommander _vehicle;
                    };
                    case {"gunner"}: {
                        _unit assignAsGunner _vehicle;
                    };
                    case {"turret"}: {
                        _unit assignAsTurret [_vehicle, _turretPath];
                    };
                };
            } forEach _neededCrew;

            sleep _sleepTime;
        } forEach _vehicles;

        false
    };
};

DM_fnc_playZoneLoop = {
    waitUntil {
        if (DM_var_gameRunning) then {
            {
                DM_var_watchedUnits pushBack _x;

                [_x] spawn {
                    params ["_unit"];

                    if (isPlayer _unit) then {
                        ["outsidePlayzone"] remoteExecCall ["bis_fnc_shownotification", _unit];
                    };

                    _running = true;

                    while {_running && (alive _unit)} do {
                        if !((getPosWorld _unit) inArea "DM_mrk_playZone") then {
                            [_unit, 0.02] call AH_fnc_changeDamage;
                        } else {
                            if (isPlayer _unit) then {
                                ["backInPlayzone"] remoteExecCall ["bis_fnc_shownotification", _unit];
                            };

                            _running = false;
                        };

                        sleep 1;
                    };

                    DM_var_watchedUnits deleteAt (DM_var_watchedUnits find _unit);
                };
            } forEach (
                (entities [["CAManBase"], [], true, true]) select {
                    (simulationEnabled _x) &&
                    {!(isPlayer _x) || {!(_x getVariable "DM_var_isLoading")}} && 
                    {!((getPosWorld _x) inArea "DM_mrk_playZone") && {!(_x in DM_var_watchedUnits)}}
                }
            );
        };

        false
    };
};