ADG_fnc_allowDamage = {
    params ["_entity", "_allow"];

    if ((isNil "_entity") || {isNull _entity}) exitWith {};

    _var = _entity getVariable "ADG_var_isDamageAllowed";

    _entity allowDamage _allow;
    _entity setVariable ["ADG_var_isDamageAllowed", _allow];
    [_entity, _allow, clientOwner] remoteExecCall ["ADG_fnc_allowDamageServer", 2];

    if (isNil "_var") then {
        [_entity, _allow] call ADG_fnc_initEntityClientServer;
        [_entity, _allow, clientOwner] remoteExecCall ["ADG_fnc_initEntityServer", 2];
    };
};

ADG_fnc_initEntityClientServer = {
    params ["_entity", "_allow"];

    if ((isNil "_entity") || {isNull _entity}) exitWith {};

    _entity addEventHandler ["Local", {
        params ["_entity", "_isLocal"];

        if _isLocal then {
            _allow = _entity getVariable "ADG_var_isDamageAllowed";
            [_entity, _allow] call ADG_fnc_allowDamage;
        };
    }];
};

ADG_var_clientServerInitDone = true;