LD_fnc_playerinit = {
    params ["_player"];
    waitUntil {
        !(isNull _player)
    };
    _player setVariable ["LD_var_Suspect", [false, nil, nil]];
};

LD_fnc_EntityKilled = {
    params ["_unit", "_killer", "_instigator"];

    if (isNull _instigator) then {
        _instigator = UAVControl vehicle _killer select 0;
    };

    if (isNull _instigator) then {
        _instigator = _killer;
    };

    if !(objNull in [_unit, _instigator]) then {
        if (({!(isplayer _x)} count [_unit, _instigator]) == 0) then {
            if !(_unit isEqualto _instigator) then {
                _starttime = servertime;

                waitUntil {
                    sleep (1/20);

                    (
                        ((servertime - _starttime) > 10) ||
                        {isnil "_instigator"} ||
                        {
                            if (({isnil "_x"} count (_instigator getVariable "LD_var_Suspect")) == 0) then {
                                (_instigator getVariable "LD_var_Suspect") params ["", "_LCT", "_TtRC"];

                                _KaRT = servertime - (_LCT + _TtRC);

                                {diag_log _x;} forEach [
                                    "################### Possible LAGswitch DETECTED ###################",
                                    (
                                        format [
                                            " Suspect %1 (%2) killed %3 from %4m",
                                            (name _instigator),
                                            (getplayerUID _instigator),
                                            (name _unit),
                                            ([(_unit distance _instigator), 1] call BIS_fnc_cutDecimals)
                                        ]
                                    ),
                                    (
                                        format [
                                            " LCT: %1s, TtRC: %2s, KaRT: %3s",
                                            _LCT,
                                            _TtRC,
                                            _KaRT
                                        ]
                                    ),
                                    "##########################################################"
                                ];

                                true
                            } else {
                                false
                            }
                        }
                    )
                };
            };
        };
    };
};

LD_fnc_onLag = {
    params ["_player"];

    _starttime = servertime;
    _player setVariable ["LD_var_Suspect", [true, (_starttime - 3), nil]];

    waitUntil {
        sleep (1/20);

        if !(isnil "_player") then {
            if ((servertime - (_player getVariable "LD_var_servertime")) < 3) then {
                _arr = _player getVariable "LD_var_Suspect";
                _LCT = _arr select 1;
                _TtRC = servertime - _LCT;
                _arr set [2, _TtRC];
                _player setVariable ["LD_var_Suspect", _arr];

                waitUntil {
                    sleep (1/20);

                    if !(isnil "_player") then {
                        if (((servertime - (_player getVariable "LD_var_servertime")) > 3) || ((servertime - (_LCT + _TtRC)) > 10)) then {
                            _player setVariable ["LD_var_Suspect", [false, nil, nil]];
                            true
                        } else {
                            false
                        }
                    } else {
                        true
                    }
                };
                true
            } else {
                false
            }
        } else {
            true
        }
    };
};

[] spawn {
    waitUntil {
        {
            _player = _x;

            if (
                (isplayer _x) &&
                {_expr = _player getVariable "LD_var_Suspect"; !(isnil "_expr")} &&
                {!((_player getVariable "LD_var_Suspect") select 0)} &&
                {(servertime - (_player getVariable "LD_var_servertime")) > 3}
            ) then {
                [_x] spawn LD_fnc_onLag;
            };

            sleep (1/20);
        } forEach allPlayers;

        false
    };
};

addMissionEventHandler ["EntityKilled", {_this spawn LD_fnc_EntityKilled;}];

LD_var_serverInitDone = true;
publicVariable "LD_var_serverInitDone";