SC_fnc_suspendAiLoop = {
    waitUntil {
        _hdls = [];

        {
            _side = _x;
            
            _sideStr = str _side;
            _numSidesUnitsAlive = call (compile ("{(alive _x) && {local _x}} count SC_var_Units" + (str _side)));

            if (_numSidesUnitsAlive > SC_var_wantedUnitAmount) then {
                _sidesUnits = [_side] call SC_fnc_getSidesUnits;

                for "_i" from (SC_var_wantedUnitAmount + 1) to _numSidesUnitsAlive do {
                    _unit = objNull;
                    _pos = _sidesUnits findIf {!(isPlayer _x) && {local _x} && {simulationEnabled _x} && {alive _x} && {isNull (objectParent _x)}};

                    if (_pos == -1) then {
                        _pos = _sidesUnits findIf {!(isPlayer _x) && {local _x} && {simulationEnabled _x} && {alive _x}};
                    };

                    if (_pos != -1) then {
                        _unit = _sidesUnits select _pos;
                        _sidesUnits deleteAt _pos;
                    };

                    if (isNull _unit) exitWith {};
                    [_unit] call SC_fnc_suspendUnit;

                    sleep (1/3);
                };
            };

            if (_numSidesUnitsAlive < SC_var_wantedUnitAmount) then {
                _suspendedUnits = call (compile ("SC_var_suspendedUnits" + _sideStr));

                if !(_suspendedUnits isEqualTo []) then {
                    for "_i" from (_numSidesUnitsAlive + 1) to SC_var_wantedUnitAmount do {
                        _unit = objNull;
                        _posUnitInGroup = _suspendedUnits findIf {!(isNull _x) && {!(isPlayer _x)} && {local _x} && {!(simulationEnabled _x)} && {(([_x] call SC_fnc_getGroupUnits) findIf {isPlayer _x}) != -1}};

                        if (_posUnitInGroup != -1) then {
                            _unit = _suspendedUnits select _posUnitInGroup;
                            _suspendedUnits deleteAt _posUnitInGroup;
                        } else {
                            _posUnit = _suspendedUnits findIf {!(isNull _x) && {!(isPlayer _x)} && {local _x} && {!(simulationEnabled _x)}};

                            if (_posUnit != -1) then {
                                _unit = _suspendedUnits select _posUnit;
                                _suspendedUnits deleteAt _posUnit;
                            }
                        };
                        
                        if (isNull _unit) exitWith {};

                        if ((random 1) < 0.01) then {
                            _unit call (compile ("SC_var_suspendedUnits" + _sideStr + " = SC_var_suspendedUnits" + _sideStr + " - [objNull];"));
                        };

                        _unit call (compile ("SC_var_suspendedUnits" + _sideStr + " deleteAt (SC_var_suspendedUnits" + _sideStr + " find _this);"));
                        _hdl = [_unit] spawn SC_fnc_spawnAi;

                        waitUntil {
                            sleep (1/3);
                            (scriptDone _hdl)
                        };
                    };
                };
            };

            sleep 1;
        } forEach SC_var_sides;

        false
    };
};

SC_fnc_aiGroupLoop = {
    waitUntil {
        {
            _side = _x;

            _sleepTime = 1 / (1 max (call (compile ("SC_var_numUnits" + (str _side)))));
            
            [_side] call {
                params ["_side"];

                _sidesUnits = [_side] call SC_fnc_getSidesUnits;

                {
                    _unit = _x;

                    if (isNull _unit) then {
                        _unit setVariable ["SC_var_groupUnits", [_unit]];
                    } else {
                        _group = _unit getVariable ["SC_var_groupUnits", [_unit]];

                        if ((_group find objNull) != -1) then {
                            _group = _group - [objNull];

                            {
                                _x setVariable ["SC_var_groupUnits", _group];
                            } forEach _group;
                        };

                        {
                            [_x, _unit] call SC_fnc_switchGroup;
                        } forEach (((units (group _unit)) - [_unit]) select {!(_x in _group)});

                        _group = _unit getVariable ["SC_var_groupUnits", [_unit]];

                        if ((count _group) < 4) then {
                            for "_i" from ((count _group) + 1) to 4 do {
                                _pos = _sidesUnits findIf {
                                    !(isNull _x) &&
                                    {!(isPlayer _x)} &&
                                    {!(_x in _group)} &&
                                    {(count (_x getVariable ["SC_var_groupUnits", [_x]])) != 4}
                                };

                                if ((_pos == -1) && {isPlayer _unit}) then {
                                    _pos = _sidesUnits findIf {
                                        !(isNull _x) &&
                                        {!(isPlayer _x)} &&
                                        {!(_x in _group)}
                                    };
                                };

                                if (_pos == -1) exitWith {};

                                [(_sidesUnits select _pos), _unit] call SC_fnc_switchGroup;
                                _group = _unit getVariable ["SC_var_groupUnits", [_unit]];
                            };
                        };

                        _unit setVariable ["SC_var_groupUnits", _group];
                    };
                } forEach _sidesUnits;

                {
                    _x setVariable ["SC_var_groupUnits", (_x getVariable ["SC_var_groupUnits", [_x]]), true];
                } forEach _sidesUnits;
            };

            sleep 1;
        } forEach SC_var_sides;

        false
    };
};