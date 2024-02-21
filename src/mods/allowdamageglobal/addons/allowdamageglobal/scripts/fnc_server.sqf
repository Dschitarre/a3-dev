ADG_fnc_allowDamageServer = {
    params ["_entity", "_allow", "_remoteExecutedOwner"];

    if ((isNil "_entity") || {isNull _entity}) exitWith {};

    [_entity, ["ADG_var_isDamageAllowed", _allow]] remoteExecCall ["setVariable", -_remoteExecutedOwner, true];
    [_entity, _allow] remoteExecCall ["allowDamage", -_remoteExecutedOwner];
};

ADG_fnc_initEntityServer = {
    params ["_entity", "_allow", "_remoteExecutedOwner"];

    if ((isNil "_entity") || {isNull _entity}) exitWith {};

    [[_entity, _allow], {
        waitUntil {!(isNil "ADG_var_clientServerInitDone")};
        _this call ADG_fnc_initEntityClientServer;
    }] remoteExec ["call", -_remoteExecutedOwner, _entity];
};

ADG_var_serverInitDone = true;