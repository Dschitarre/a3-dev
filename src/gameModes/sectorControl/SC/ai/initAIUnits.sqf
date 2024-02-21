SC_var_suspendedUnitsWest = playableUnits select {(side _x) == west};
SC_var_suspendedUnitsEast = playableUnits select {(side _x) == east};
SC_var_suspendedUnitsGuer = playableUnits select {(side _x) == independent};

{
    _side = [west, east, independent] select _forEachIndex;

    {
        [_x, ([_x] call SC_fnc_getAiNameArr)] remoteExecCall ["setName", 0, _x];

        _x setVariable ["SC_var_groupUnits", [_x], true];
        _x setVariable ["SC_var_unitId", _forEachIndex];
        _x setVariable ["SC_var_aiSkill", 0.6 + random 0.3];
        _x setVariable ["ais_side", _side, true];

        _cutoff = ceil ((random 1) * 35);
        _rank = 1 max (if ((random 1) < 0.2) then {
            ceil ((random 1) * _cutoff)
        } else {
            _cutoff + (ceil ((random (1000 - _cutoff))*(random 1)*(random 1)*(random 1)*(random 1)))
        });
        _x setVariable ["SC_var_rank", _rank, true];

        _newName = "[" + (str _rank) + "] " + ([_x] call SC_fnc_getName);
        _x setVariable ["TDI_var_name", _newName, true];
        _x setVariable ["MM_var_name", _newName, true];

        [[_x], grpNull] remoteExecCall ["join", (groupOwner (group _x))];
    } forEach _x;
} forEach [SC_var_suspendedUnitsWest, SC_var_suspendedUnitsEast, SC_var_suspendedUnitsGuer];