// Auto heal (server and clients): a unit heals itself after not being damaged for a while. Healing runs where
// the unit is local; the "Hit" / "Local" event handlers on every machine follow it through locality changes.

AH_var_clientRunning = false;
AH_var_entityCreatedEhId = -1;

AH_var_hitPointCount = 10;   // the first hit points of a CAManBase (head ... legs) are healed
AH_var_healStep = 0.03;      // damage healed per second at heal speed 1

AH_fnc_setDamageClientServer = {
    params ["_unit", "_newDamage", "_newHitPointsDamage"];

    _unit setDamage _newDamage;

    {
        _unit setHitIndex [_forEachIndex, _x, false];
    } forEach _newHitPointsDamage;
};

AH_fnc_hitPointsDamage = {
    params ["_unit"];

    ((getAllHitPointsDamage _unit) select 2) select [0, AH_var_hitPointCount]
};

AH_fnc_isDamaged = {
    params ["_unit"];

    damage _unit != 0 || {([_unit] call AH_fnc_hitPointsDamage) findIf {_x > 0} != -1}
};

// damage plus the damage of the healed hit points: rises with every kind of damage, also without a "Hit" event
AH_fnc_totalDamage = {
    params ["_unit"];

    private _totalDamage = damage _unit;

    {
        _totalDamage = _totalDamage + _x;
    } forEach ([_unit] call AH_fnc_hitPointsDamage);

    _totalDamage
};

AH_fnc_isConscious = {
    params ["_unit"];

    !(lifeState _unit in ["INCAPACITATED", "UNCONSCIOUS"]) && {!(_unit getVariable ["ais_unconscious", false])}
};

// Changes the damage of a unit by _change (negative heals), spread over its hit points. A unit that is not local
// is changed on its owner, so the cooldown and the hit points are set there. Returns the new damage (for a unit
// that is not local the current one).
AH_fnc_changeDamage = {
    params ["_unit", "_change"];

    if (!local _unit) exitWith {
        [_unit, _change] remoteExecCall ["AH_fnc_changeDamage", _unit];
        damage _unit
    };

    private _oldDamage = damage _unit;

    if (_change == 0 || {_change < 0 && {!([_unit] call AH_fnc_isDamaged)}}) exitWith {_oldDamage};

    private _hitPointsDamage = [_unit] call AH_fnc_hitPointsDamage;
    private _newHitPointsDamage = [];
    private _newDamage = 0;

    if (_change > 0) then {
        [_unit] call AH_fnc_onDamaged;

        private _min = selectMin _hitPointsDamage;

        if (_min + _change >= 1) then {
            _newHitPointsDamage = _hitPointsDamage apply {1};
        } else {
            private _changeFactor = _change / (1 - _min);
            _newHitPointsDamage = _hitPointsDamage apply {_x + ((1 - _x) * _changeFactor)};
        };
    } else {
        private _max = selectMax _hitPointsDamage;

        if (_max + _change <= 0) then {
            _newHitPointsDamage = _hitPointsDamage apply {0};
        } else {
            private _changeFactor = (_max + _change) / _max;
            _newHitPointsDamage = _hitPointsDamage apply {_x * _changeFactor};
        };
    };

    {
        _newDamage = _newDamage + _x;
    } forEach _newHitPointsDamage;

    _newDamage = _newDamage / AH_var_hitPointCount;

    if (_oldDamage != 0) then {
        _newDamage = if (_change > 0) then {_newDamage max _oldDamage} else {_newDamage min _oldDamage};
    };

    [_unit, _newDamage, _newHitPointsDamage] call AH_fnc_setDamageClientServer;

    // fully healed: the killfeed forgets the hits (assists) on the unit
    if (_change < 0 && {_newDamage == 0} && {!isNil "KF_var_running"}) then {
        [_unit] remoteExecCall ["KF_fnc_entityHealed", 2];
    };

    _newDamage
};

AH_fnc_cooldownActive = {
    params ["_unit"];

    private _cooldown = [AH_var_healCooldown, AH_var_healCooldownMedic] select (_unit getUnitTrait "Medic");

    (time - (_unit getVariable ["AH_var_notDamagedSince", 0])) < _cooldown
};

// heals the unit step by step until it is healthy, dead, no longer local, or auto heal is stopped
AH_fnc_watchUnit = {
    params ["_unit"];

    private _lastTotalDamage = [_unit] call AH_fnc_totalDamage;

    waitUntil {
        if (!AH_var_clientRunning || {!alive _unit} || {!local _unit} || {!([_unit] call AH_fnc_isDamaged)}) exitWith {true};

        // damage without a "Hit" event (scripts, e.g. a zone) and unconsciousness restart the cooldown
        if (([_unit] call AH_fnc_totalDamage) > _lastTotalDamage || {!([_unit] call AH_fnc_isConscious)}) then {
            _unit setVariable ["AH_var_notDamagedSince", time];
        };

        if (!([_unit] call AH_fnc_cooldownActive)) then {
            [_unit, -AH_var_healStep * AH_var_healSpeed] call AH_fnc_changeDamage;
        };

        _lastTotalDamage = [_unit] call AH_fnc_totalDamage;
        sleep 1;
        false
    };
};

// one heal loop per unit and machine: a loop that is still running (also from before a restart) goes on
AH_fnc_startWatching = {
    params ["_unit"];

    private _watchScript = _unit getVariable ["AH_var_watchScript", scriptNull];

    if (!isNull _watchScript && {!scriptDone _watchScript}) exitWith {};

    _unit setVariable ["AH_var_watchScript", [_unit] spawn AH_fnc_watchUnit];
};

AH_fnc_onDamaged = {
    params ["_unit"];

    _unit setVariable ["AH_var_notDamagedSince", time];
    [_unit] call AH_fnc_startWatching;
};

AH_fnc_entityInitClientServer = {
    params ["_unit"];

    _unit setVariable ["AH_var_notDamagedSince", time - AH_var_healCooldown];

    if (isNil {_unit getVariable "AH_var_hitEhId"}) then {
        _unit setVariable ["AH_var_hitEhId", _unit addEventHandler ["Hit", {
            params ["_unit"];
            [_unit] call AH_fnc_onDamaged;
        }]];
    };

    if (isNil {_unit getVariable "AH_var_localEhId"}) then {
        _unit setVariable ["AH_var_localEhId", _unit addEventHandler ["Local", {
            params ["_unit", "_isLocal"];

            // a unit that became local while damaged starts healing right away
            if (_isLocal && {[_unit] call AH_fnc_isDamaged}) then {
                _unit setVariable ["AH_var_notDamagedSince", time - AH_var_healCooldown];
                [_unit] call AH_fnc_startWatching;
            };
        }]];
    };
};

AH_fnc_startAutoHealClientServer = {
    if (AH_var_clientRunning) exitWith {};

    AH_var_clientRunning = true;

    {
        [_x] call AH_fnc_entityInitClientServer;
    } forEach entities [["CAManBase"], [], true, false];

    AH_var_entityCreatedEhId = addMissionEventHandler ["EntityCreated", {
        params ["_entity"];

        if (_entity isKindOf "CAManBase") then {
            [_entity] spawn AH_fnc_entityInitClientServer;
        };
    }];

    // a loaded singleplayer savegame has lost the event handlers: add them again
    if (!isMultiplayer) then {
        AH_var_loadedEhId = addMissionEventHandler ["Loaded", {
            call AH_fnc_stopAutoHealClientServer;

            [] spawn {
                waitUntil {!AH_var_clientRunning};
                call AH_fnc_startAutoHealClientServer;
            };
        }];
    };
};

// running heal loops end by themselves within a second (they check AH_var_clientRunning)
AH_fnc_stopAutoHealClientServer = {
    if (!AH_var_clientRunning) exitWith {};

    AH_var_clientRunning = false;

    {
        private _hitEhId = _x getVariable "AH_var_hitEhId";
        private _localEhId = _x getVariable "AH_var_localEhId";

        if (!isNil "_hitEhId") then {
            _x removeEventHandler ["Hit", _hitEhId];
        };

        if (!isNil "_localEhId") then {
            _x removeEventHandler ["Local", _localEhId];
        };

        _x setVariable ["AH_var_hitEhId", nil];
        _x setVariable ["AH_var_localEhId", nil];
    } forEach entities [["CAManBase"], [], true, false];

    removeMissionEventHandler ["EntityCreated", AH_var_entityCreatedEhId];
    AH_var_entityCreatedEhId = -1;

    if (!isMultiplayer) then {
        removeMissionEventHandler ["Loaded", AH_var_loadedEhId];
        AH_var_loadedEhId = nil;
    };
};

AH_var_clientServerInitDone = true;
