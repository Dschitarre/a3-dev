GG_fnc_suspendAiLoop = {
    waitUntil {
        _hdls = [];

        _aliveUnits = (entities [["CAManBase"], [], true, false]) select {(alive _x) && {simulationEnabled _x}};
        _numUnitsAlive = count _aliveUnits;

        if (_numUnitsAlive > GG_var_wantedUnitAmount) then {
            for "_i" from (GG_var_wantedUnitAmount + 1) to _numUnitsAlive do {
                _unit = objNull;
                _pos = _aliveUnits findIf {!(isPlayer _x) && {local _x} && {simulationEnabled _x} && {alive _x}};

                if (_pos != -1) then {
                    _unit = _aliveUnits select _pos;
                    _aliveUnits deleteAt _pos;
                };

                if (isNull _unit) exitWith {};
                [_unit] call GG_fnc_suspendUnit;

                sleep (1/3);
            };
        };

        if (_numUnitsAlive < GG_var_wantedUnitAmount) then {
            if !(GG_var_suspendedUnits isEqualTo []) then {
                for "_i" from (_numUnitsAlive + 1) to GG_var_wantedUnitAmount do {
                    _unit = objNull;
                    _pos = GG_var_suspendedUnits findIf {!(isNull _x) && {local _x} && {!(isPlayer _x)} && {!(simulationEnabled _x)}};

                    if (_pos != -1) then {
                        _unit = GG_var_suspendedUnits select _pos;
                        GG_var_suspendedUnits deleteAt _pos;
                    };
                    
                    if (isNull _unit) exitWith {};

                    if ((random 1) < 0.01) then {
                        GG_var_suspendedUnits = GG_var_suspendedUnits - [objNull];
                    };

                    GG_var_suspendedUnits deleteAt (GG_var_suspendedUnits find _unit);
                    _hdl = [_unit] spawn GG_fnc_spawnAi;

                    waitUntil {
                        sleep (1/3);
                        (scriptDone _hdl)
                    };
                };
            };
        };

        false
    };
};