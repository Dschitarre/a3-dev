// Killfeed kills and scores (server): killer and assistants of a kill, score handling.
// Included by fnc_server.sqf.

// ---- scores ----

// adds the player scores and rating of a kill; returns the type of the vehicle destroyed with it ("" if none)
KF_fnc_addKillScores = {
    params ["_unit", "_vehicle", "_killer", "_isTeamKill", "_isUnitDeath"];

    private _scores = [0, 0, 0, 0, 0];   // infantry, soft vehicle, armor, air, total (see addPlayerScores)
    private _killedVehicle = objNull;

    if (unitIsUAV _unit) then {
        if !(_unit getVariable ["KF_var_wasKilled", false]) then {
            _killedVehicle = _unit;
        };

        _unit setVariable ["KF_var_wasKilled", true];
    } else {
        _scores set [0, 1];

        // the first crew member killed with its vehicle gets the vehicle kill
        if (!isNull _vehicle && {!alive _vehicle} && {!(_vehicle getVariable ["KF_var_wasKilled", false])}) then {
            _vehicle setVariable ["KF_var_wasKilled", true];
            _killedVehicle = _vehicle;
        };
    };

    private _killedVehicleType = "";

    if (!isNull _killedVehicle) then {
        private _index = switch (true) do {
            case (_killedVehicle isKindOf "Car_F"): {1};
            case ((_killedVehicle isKindOf "Tank_F") || {_killedVehicle isKindOf "StaticWeapon"} || {_killedVehicle isKindOf "Ship_F"}): {2};
            case ((_killedVehicle isKindOf "Helicopter_Base_F") || {_killedVehicle isKindOf "Plane_Base_F"}): {3};
            default {-1};
        };

        if (_index != -1) then {
            _scores set [_index, 1];
        };

        if (_index != -1 || {!unitIsUAV _unit}) then {
            _killedVehicleType = typeOf _killedVehicle;
        };
    };

    if (!_isUnitDeath || KF_var_addScoreForUnitDeaths) then {
        private _sign = [1, -1] select _isTeamKill;
        private _rating = 0;

        _scores = _scores apply {_sign * _x};

        {
            _rating = _rating + 1000 * _x;
        } forEach _scores;

        _killer addPlayerScores _scores;
        [_killer, _rating] remoteExecCall ["addRating", _killer];
    };

    _killedVehicleType
};

// ---- kills ----

// friendly fire: same side, unless the victim was a renegade
KF_fnc_isTeamKill = {
    params ["_hitter", "_unit"];

    (([_hitter] call KF_fnc_unitSide) == ([_unit] call KF_fnc_unitSide)) && {(rating _unit) >= -2000}
};

// the players controlling a UAV
KF_fnc_getUavOperators = {
    params ["_uav"];

    private _control = UAVControl _uav;
    private _operators = [];

    {
        if ((_x isEqualType "") && {_x != ""}) then {
            _operators pushBack (_control select (_forEachIndex - 1));
        };
    } forEach _control;

    _operators
};

// "EntityKilled" mission event handler; game modes call it with _isExternal for their own kills (e.g. unconscious)
KF_fnc_entityKilled = {
    params ["_unit", "_killer", "_instigator", ["_isExternal", false]];

    // Ordinary vehicles do not produce a unit feed, but their destroyer can cause a secondary explosion.
    if (!(_unit isKindOf "CAManBase") && {!alive _unit}) then {
        private _destroyer = [_killer, _instigator, _unit] call KF_fnc_getInstigator;
        if ([_destroyer] call KF_fnc_unitIsValid) then {
            _unit setVariable ["KF_var_destroyer", [_destroyer, time]];
        };
    };

    if !([_unit] call KF_fnc_unitIsValid) exitWith {};

    // units killed right after their creation
    if (time - (_unit getVariable ["KF_var_initTime", time]) <= 2) exitWith {};

    if (
        !KF_var_handleUnitDeaths &&
        {_unit isKindOf "CAManBase"} &&
        {!_isExternal || {_unit getVariable ["KF_var_calledKilled", false]}}
    ) exitWith {};

    _instigator = [_killer, _instigator, _unit] call KF_fnc_getInstigator;

    // the killer's health at the kill for the death feed: his vehicle's (a UAV's) or his own; -1 without another killer
    private _healthSource = vehicle ([_killer, _instigator] select (isNull _killer));
    private _killerHealth = -1;

    if (!isNull _healthSource && {_instigator isNotEqualTo _unit} && {_healthSource isNotEqualTo (vehicle _unit)}) then {
        _killerHealth = 1 - damage _healthSource;
    };

    if (unitIsUAV _killer) then {
        _killer = _instigator;
    };

    if !([_instigator] call KF_fnc_unitIsValid) then {
        _instigator = _unit;
    };

    private _uavOperators = if (unitIsUAV _unit) then {[_unit] call KF_fnc_getUavOperators} else {[]};

    // name and side at the moment of the death (KF_fnc_watchUnitsLoop refreshes only living units)
    [_unit] call KF_fnc_updateNameAndSide;

    // gone down (unconscious): the hits before count for its final death as well (KF_fnc_hitsSince)
    if (_isExternal && {alive _unit} && {(_unit getVariable ["KF_var_downTime", -1]) == -1}) then {
        _unit setVariable ["KF_var_downTime", time];
    };

    _unit setVariable ["KF_var_calledKilled", true];

    [
        _unit,
        [_killer] call KF_fnc_getRespawnedEntity,
        [_instigator] call KF_fnc_getRespawnedEntity,
        objectParent _unit,
        _isExternal,
        _uavOperators,
        _killerHealth
    ] spawn {
        sleep KF_var_killDelay;
        _this call KF_fnc_onKill;
    };
};

// placed explosives (mines, charges; weapon "Put") or artillery: the killer's last hit (the kill cam skips such kills)
KF_fnc_isIndirectKill = {
    params ["_hits", "_killer"];

    private _killerHits = _hits select {(_x select 0) isEqualTo _killer};

    if (_killerHits isEqualTo []) exitWith {false};

    (_killerHits select (count _killerHits - 1)) params ["", "_ammo", "", "_source"];

    (_source == "Put") ||
    {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "artilleryLock")) == 1} ||
    {(getNumber (configFile >> "CfgVehicles" >> _source >> "artilleryScanner")) == 1}
};

KF_fnc_onKill = {
    params ["_unit", "_killer", "_instigator", "_vehicle", "_isExternal", "_uavOperators", "_killerHealth"];

    private _zoneDeath = serverTime - (_unit getVariable ["KF_var_zoneDeath", -100]) < 2;
    if (_zoneDeath) then {_killer = _unit; _instigator = _unit; _killerHealth = -1};

    if !([_killer] call KF_fnc_unitIsValid) then {
        _killer = _instigator;
    };

    private _hits = [_unit, _vehicle] call KF_fnc_getHits;
    _hits = _hits apply {
        private _hit = +_x;
        if ((_hit select 1) == "vehExpl") then {
            private _sourceEntity = _hit param [7, objNull];
            (_sourceEntity getVariable ["KF_var_destroyer", [objNull, -100]]) params ["_destroyer", "_destroyedAt"];
            if (!isNull _destroyer && {abs ((_hit select 6) - _destroyedAt) < 2}) then {
                _hit set [0, _destroyer];
                if (!_zoneDeath && {_killer == _unit || {isNull _killer}}) then {_killer = _destroyer; _instigator = _destroyer};
            };
        };
        _hit
    };

    private _isUav = unitIsUAV _unit;
    private _isUnitDeath = !_isUav && !_isExternal;
    private _isTeamKill = [_killer, _unit] call KF_fnc_isTeamKill;
    private _killedVehicleType = "";

    if ((_killer isNotEqualTo _unit) && {_killer isKindOf "CAManBase"}) then {
        _killedVehicleType = [_unit, _vehicle, _killer, _isTeamKill, _isUnitDeath] call KF_fnc_addKillScores;
    };

    private _hitData = [_hits, _killer] call KF_fnc_aggregateHits;
    // A victim's own fall/fire record is a cause, never an assist for killing themselves.
    if (_killer != _unit) then {_hitData = _hitData select {(_x select 0) != _unit}};
    if (_zoneDeath) then {_hitData = [[_unit, [["Restricted Zone", "", []]], -1]]};
    private _killerIndex = _hitData findIf {(_x select 0) isEqualTo _killer};

    // the victim's kill cam is decided at the death on his client, only this kind of the kill is known here
    if (isPlayer _unit && {_killer isNotEqualTo _unit}) then {
        ["KF_fnc_setKillCamIndirect", [[_hits, _killer] call KF_fnc_isIndirectKill], _unit] call KF_fnc_callClients;
    };

    // a killer without hits is shown with a tombstone
    if (_killerIndex == -1) then {
        _killerIndex = count _hitData;
        _hitData pushBack [_killer, [["Tombstone", "", []]], -1];
    };

    if (!_zoneDeath && {_hits isNotEqualTo []}) then {
        private _last = _hits select (count _hits - 1);
        if ((_last select 1) in ["fall", "fire", "drown"] && {time - (_last select 6) < 2}) then {
            private _causes = (_hitData select _killerIndex) select 1;
            private _type = [_last select 1, [], ""] call KF_fnc_getHitType;
            _causes = _causes select {(_x select 0) != _type && {(_x select 0) != "Tombstone"}};
            _causes insert [0, [[_type, "", []]]];
            (_hitData select _killerIndex) set [1, _causes];
        };
    };

    private _kill =[_unit, _killer, _isTeamKill, _hitData, _hitData select _killerIndex, _killedVehicleType,
        _isExternal, _isUav, _isUnitDeath, _uavOperators, _killerHealth, _vehicle];

    _kill call KF_fnc_sendMidFeed;
    _kill call KF_fnc_sendKillFeed;
    _kill call KF_fnc_sendDeathFeed;
    _kill call KF_fnc_updateKillInfo;
};

// runs a client function on the target machines that have the client part loaded
KF_fnc_callClients = {
    params ["_function", "_args", "_targets"];

    [[_function, _args], {
        params ["_function", "_args"];

        if (!isNil _function) then {
            _args call (missionNamespace getVariable _function);
        };
    }] remoteExecCall ["call", _targets];
};
