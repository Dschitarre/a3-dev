// allowDamage that survives locality changes (server and clients): the allowed state is stored on the
// entity and re-applied by a "Local" event handler wherever the entity becomes local.

ADG_fnc_allowDamage = {
    params ["_entity", "_allow"];

    if (isNil "_entity" || {isNull _entity}) exitWith {};

    private _isInitialized = !isNil {_entity getVariable "ADG_var_isDamageAllowed"};

    _entity allowDamage _allow;
    // public object variable: synced to every machine and to JIP, and removed together with the object
    _entity setVariable ["ADG_var_isDamageAllowed", _allow, true];
    [_entity, _allow, clientOwner] remoteExecCall ["ADG_fnc_allowDamageServer", 2];

    if (!_isInitialized) then {
        [_entity] call ADG_fnc_initEntityClientServer;
        [_entity, clientOwner] remoteExecCall ["ADG_fnc_initEntityServer", 2];
    };
};

// the state set by ADG_fnc_allowDamage (synced to every machine), else the engine's local one
ADG_fnc_isDamageAllowed = {
    params ["_entity"];

    _entity getVariable ["ADG_var_isDamageAllowed", isDamageAllowed _entity]
};

ADG_fnc_initEntityClientServer = {
    params ["_entity"];

    if (isNil "_entity" || {isNull _entity}) exitWith {};

    _entity addEventHandler ["Local", {
        params ["_entity", "_isLocal"];

        // only the new owner applies the state again: every other machine already has it
        if (_isLocal) then {
            _entity allowDamage ([_entity] call ADG_fnc_isDamageAllowed);
        };
    }];
};

ADG_var_clientServerInitDone = true;
