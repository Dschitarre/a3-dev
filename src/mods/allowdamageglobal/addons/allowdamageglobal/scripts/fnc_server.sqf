// allowDamage that survives locality changes (server): applies the state on the other machines and adds the
// "Local" event handler there (also for JIP, removed with the entity).

ADG_fnc_allowDamageServer = {
    params ["_entity", "_allow", "_remoteExecutedOwner"];

    if (isNil "_entity" || {isNull _entity}) exitWith {};

    [_entity, _allow] remoteExecCall ["allowDamage", -_remoteExecutedOwner];
};

ADG_fnc_initEntityServer = {
    params ["_entity", "_remoteExecutedOwner"];

    if (isNil "_entity" || {isNull _entity}) exitWith {};

    // the state is read when the message runs, so a JIP client applies the current one, not the first
    [[_entity], {
        params ["_entity"];

        waitUntil {!isNil "ADG_var_clientServerInitDone"};

        if (isNull _entity) exitWith {};

        [_entity] call ADG_fnc_initEntityClientServer;
        _entity allowDamage ([_entity] call ADG_fnc_isDamageAllowed);
    }] remoteExecCall ["spawn", -_remoteExecutedOwner, _entity];
};

ADG_var_serverInitDone = true;
