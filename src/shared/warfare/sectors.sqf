// Sectors: capturing, sector state, tickets, ticket rates and the game mode loop (server; the sector units are also
// counted on the client for the HUD).

// ---- sectors ----
SC_fnc_sectorRespawnAllowed = {true};

// the capture XP of the players on sectors is collected and sent every SC_var_captureXpSendInterval seconds
// (one message per player instead of one per player and sector tick)
SC_var_captureXpSendInterval = 10;

// Game rules may restrict the capturable front; SC permits every sector.
SC_fnc_canCaptureSector = {true};
// SC neutralizes a sector as soon as its flag is lowered; other rules may retain it until full neutralization.
SC_fnc_sectorOwnerForFlag = {
    params ["_sectorInd", "_holder", "_flag", "_owner"];
    [civilian, _holder] select (_flag == 100)
};
SC_fnc_getRoundWinner = {
    private _index = SC_var_tickets findIf {(floor _x) >= 100};
    [sideUnknown, SC_var_sides param [_index, sideUnknown]] select (_index >= 0)
};

// units of SC_var_sides that count for capturing a sector, as hashmap side -> units
SC_fnc_getUnitsOnSector = {
    params ["_sectorMarker"];

    private _unitsOnSector = createHashMap;

    {
        _unitsOnSector set [_x, []];
    } forEach SC_var_sides;

    {
        // suspended AI (alive, not simulated, waiting outside the game) doesn't count
        if ((alive _x) && {simulationEnabled _x} && {!(_x getVariable ["AIS_unconscious", false])}) then {
            private _pos = getPosATL _x;

            if (((_pos select 2) <= 25) && {_pos inArea _sectorMarker}) then {
                private _sidesUnits = _unitsOnSector get (side (group _x));

                if !(isNil "_sidesUnits") then {
                    if (_x isKindOf "CAManBase") then {
                        _sidesUnits pushBack _x;
                    } else {
                        private _uavControlUnits = if (unitIsUAV _x) then {[_x, true] call SC_fnc_uavControlUnits} else {[]};
                        private _driver = driver _x;

                        _sidesUnits append (if (_uavControlUnits isNotEqualTo []) then {_uavControlUnits} else {
                            (crew _x) select {!([_x] call SC_fnc_isUavAi) || {_x isEqualTo _driver}}
                        });
                    };
                };
            };
        };
    } forEach (nearestObjects [((getMarkerPos _sectorMarker) select [0, 2]),["AllVehicles"],
        ((selectMax (getMarkerSize _sectorMarker)) *(if((markerShape _sectorMarker) == "RECTANGLE") then {
        sqrt 2} else {1})), false]);

    _unitsOnSector
};

SC_fnc_setSectorVar = {
    params ["_name", "_sectorInd", "_value"];

    missionNamespace setVariable [(_name + _sectorInd), _value];
    publicVariable (_name + _sectorInd);
};

// capture XP of one sector tick, collected per player UID in _pendingXp
SC_fnc_addCaptureTickXp = {
    params ["_units", "_pendingXp"];

    {
        if (isPlayer _x) then {
            private _uid = getPlayerUID _x;
            private _xp = [4, 6] select (_x getVariable ["SC_var_hasExprPerk", false]);

            _pendingXp set [_uid, (_pendingXp getOrDefault [_uid, 0]) + _xp];
        };
    } forEach _units;
};

// sends the collected capture XP to the players that are still connected
SC_fnc_sendCaptureXp = {
    params ["_pendingXp"];

    {
        [_x, (_pendingXp getOrDefault [(getPlayerUID _x), 0])] call SC_fnc_giveXp;
    } forEach (allPlayers select {!(_x isKindOf "HeadlessClient_F")});
};

SC_fnc_gameModeLoop = {
    private _ended = false;
    private _sleepTime = 1 / (count SC_var_sectors);
    private _pendingCaptureXp = createHashMap;
    private _lastCaptureXpSendTime = time;
    private _lastTicketTime = time;

    waitUntil {
        {
            private _startTime = time;
            private _sectorInd = _x;
            private _sectorMarker = "SC_var_sector" + _sectorInd;

            private _unitsOnSector = [_sectorMarker] call SC_fnc_getUnitsOnSector;
            private _numUnitsOnSector = 0;
            {_numUnitsOnSector = _numUnitsOnSector + (count _y);} forEach _unitsOnSector;

            private _holder = missionNamespace getVariable ("SC_var_holder" + _sectorInd);
            private _flag = missionNamespace getVariable ("SC_var_flag" + _sectorInd);
            private _lastDecapturingSide = missionNamespace getVariable [("SC_var_lastDecapturingSide" + _sectorInd), civilian];

            {
                private _side = _x;
                private _sidesUnitsOnSector = _unitsOnSector get _side;
                private _numSidesUnitsOnSector = count _sidesUnitsOnSector;
                private _sidesRelativeUnitAmount = (if (_numSidesUnitsOnSector == _numUnitsOnSector) then {
                    1.001 * _numSidesUnitsOnSector
                } else {
                    _numSidesUnitsOnSector / (_numUnitsOnSector - _numSidesUnitsOnSector)
                });

                if (_sidesRelativeUnitAmount > 1 && {[_sectorInd, _side] call SC_fnc_canCaptureSector}) then {
                    if (_flag == 0) then {
                        _holder = _side;
                        ["SC_var_holder", _sectorInd, _holder] call SC_fnc_setSectorVar;

                        _lastDecapturingSide = _side;
                        ["SC_var_lastDecapturingSide", _sectorInd, _lastDecapturingSide] call SC_fnc_setSectorVar;
                    };

                    if ((_flag <= 100) && {_flag > 0} && {_holder != _side}) then {
                        _flag = 0 max (_flag - ((_sidesRelativeUnitAmount ^ 0.7) * SC_var_sectorCaptureRate));
                        ["SC_var_flag", _sectorInd, _flag] call SC_fnc_setSectorVar;
                        [_sidesUnitsOnSector, _pendingCaptureXp] call SC_fnc_addCaptureTickXp;
                    };

                    if ((_flag < 100) && {_flag >= 0} && {_holder == _side}) then {
                        _flag = 100 min (_flag + ((_sidesRelativeUnitAmount ^ 0.7) * SC_var_sectorCaptureRate));
                        ["SC_var_flag", _sectorInd, _flag] call SC_fnc_setSectorVar;
                        [_sidesUnitsOnSector, _pendingCaptureXp] call SC_fnc_addCaptureTickXp;

                        if (_flag == 100) then {
                            [_side, _sectorInd] remoteExecCall ["SC_fnc_addSectorCapturedLine", 0];

                            if (_lastDecapturingSide == _side) then {
                                {
                                    if (isPlayer _x) then {
                                        private _xp = [200, 300] select (_x getVariable ["SC_var_hasExprPerk", false]);
                                        [_x, _xp] call SC_fnc_giveXp;
                                        [_x, "captured", _holder, _sectorInd, _xp] call SC_fnc_sendMidFeedXpLine;
                                        remoteExecCall ["SC_fnc_addCapturedSector", _x];
                                    } else {
                                        // AI in the leaderboard (SC\roundEnd.sqf)
                                        [_x, "xp", SC_var_aiRoundStatCaptureXp] call SC_fnc_addRoundStat;
                                    };

                                    [_x, "captures"] call SC_fnc_addRoundStat;
                                } forEach _sidesUnitsOnSector;

                                [_sidesUnitsOnSector, _sectorInd] call SC_fnc_rewardTransportCapture;

                                _lastDecapturingSide = civilian;
                                ["SC_var_lastDecapturingSide", _sectorInd, _lastDecapturingSide] call SC_fnc_setSectorVar;
                            };
                        };
                    };

                    private _owner = [_sectorInd, _holder, _flag,
                        missionNamespace getVariable ("SC_var_owner" + _sectorInd)] call SC_fnc_sectorOwnerForFlag;

                    if (_owner isNotEqualTo (missionNamespace getVariable ("SC_var_owner" + _sectorInd))) then {
                        ["SC_var_owner", _sectorInd, _owner] call SC_fnc_setSectorVar;
                    };
                };
            } forEach SC_var_sides;

            private _finalSleepTime = _sleepTime - (time - _startTime);

            if (_finalSleepTime > 0) then {
                sleep _finalSleepTime;
            };
        } forEach SC_var_sectors;

        if ((time - _lastCaptureXpSendTime) >= SC_var_captureXpSendInterval) then {
            [_pendingCaptureXp] call SC_fnc_sendCaptureXp;
            _pendingCaptureXp = createHashMap;
            _lastCaptureXpSendTime = time;
        };

        {
            _sectorInd = _x;
            _owner = missionNamespace getVariable ("SC_var_owner" + _sectorInd);
            private _lastOwner = missionNamespace getVariable ("SC_var_lastOwner" + _sectorInd);

            if (_lastOwner != _owner) then {
                private _respawnPos = missionNamespace getVariable ("SC_var_" + _sectorInd + "RespawnPos");
                _respawnPos call BIS_fnc_removeRespawnPosition;
                _respawnPos = [];
                _flag = missionNamespace getVariable ("SC_var_flag" + _sectorInd);

                if (_flag == 100 && {[_sectorInd] call SC_fnc_sectorRespawnAllowed}) then {
                    private _flag3d = missionNamespace getVariable ("SC_var_flag" + _sectorInd + "3d");
                    _respawnPos = [_owner, (getPosATL _flag3d), _sectorInd] call BIS_fnc_addRespawnPosition;
                    private _sideString = [_owner] call SC_fnc_getSideString;

                    if (SC_var_sectorCapturedMessages != 0) then {
                        if (SC_var_sectorCapturedMessages == 1) then {
                            ["captured", [_sideString, _sectorInd]] remoteExec ["SC_fnc_showNotificationIfHudIsEnabled", 0];
                        } else {
                            (_sideString + " captured " + _sectorInd) remoteExecCall ["systemChat", 0];
                        };
                    };
                };

                missionNamespace setVariable [("SC_var_" + _sectorInd + "RespawnPos"), _respawnPos];
            };
        } forEach SC_var_sectors;

        sleep 0.1;

        // tickets and the ticket rate per minute of every side (HUD: rates and expected round end)
        private _ticketInterval = 0.1 max (time - _lastTicketTime);
        private _ticketRates = [];
        _lastTicketTime = time;

        {
            private _side = _x;
            private _sidesRelativeSectors =({(missionNamespace getVariable ("SC_var_owner" + _x)) == _side}
                count SC_var_sectors) /(count SC_var_sectors);
            private _ticketGain = _sidesRelativeSectors * SC_var_ticketGainFactor;

            SC_var_tickets set [_forEachIndex, (SC_var_tickets select _forEachIndex) + _ticketGain];
            _ticketRates pushBack ((round (600 * _ticketGain / _ticketInterval)) / 10);
        } forEach SC_var_sides;

        publicVariable "SC_var_tickets";

        if (_ticketRates isNotEqualTo SC_var_ticketRates) then {
            SC_var_ticketRates = _ticketRates;
            publicVariable "SC_var_ticketRates";
        };

        call SC_fnc_checkAirDrops;

        private _winner = call SC_fnc_getRoundWinner;

        if (_winner != sideUnknown) then {
            [_pendingCaptureXp] call SC_fnc_sendCaptureXp;
            _pendingCaptureXp = createHashMap;

            // the killfeed's kill info is shown on the end screen (SC_fnc_endRound)
            [_winner] call SC_fnc_endRound;
            _ended = true;
        };

        sleep 0.1;

        {
            missionNamespace setVariable ["SC_var_lastOwner" + _x, (missionNamespace getVariable ("SC_var_owner" + _x))];
        } forEach SC_var_sectors;

        _ended
    };
};

// map / 3D icon color of a sector: white blended towards the holder's side color (player's map colors) by the
// capture progress (_colorIntensity 0 - 1)
SC_fnc_getSectorColor = {
    params ["_side", "_alpha", "_colorIntensity"];

    private _sideColor = if (_side in SC_var_sides) then {([_side] call UI_fnc_sideColor) select [0, 3]} else {[1, 1, 1]};

    ([1, 1, 1] vectorDiff (([1, 1, 1] vectorDiff _sideColor) vectorMultiply _colorIntensity)) + [_alpha]
};
