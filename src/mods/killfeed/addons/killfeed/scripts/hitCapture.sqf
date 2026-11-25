// Killfeed hit capture (every machine): hits recorded on the shooter's machine via projectile event handlers, and
// damage without a projectile on the victim's machine. Included by fnc_clientServer.sqf.

// ---- hits: captured on the shooter's machine ----
// FiredMan attaches the hit context [shooter, firer, magazine, source] to the projectile. Its event handlers report
// every unit or vehicle it hits directly (HitPart) or with its explosion (HitExplosion); submunitions (shotgun
// pellets, cluster bombs) and placed explosives (weapon "Put") carry the same context.

KF_fnc_firedMan = {
    params ["_unit", "_weapon", "", "", "", "_magazine", "_projectile", "_vehicle"];

    if (isNull _projectile) exitWith {};

    private _shooter = _unit;
    private _firer = _unit;
    private _source = _weapon;

    if (!isNull _vehicle) then {
        _firer = _vehicle;
        _source = typeOf _vehicle;

        if (unitIsUAV _vehicle) then {
            _shooter = [_vehicle, _unit] call KF_fnc_getUavOperator;
        };
    };

    [_projectile, [_shooter, _firer, _magazine, _source]] call KF_fnc_trackProjectile;
};

KF_fnc_getAmmoTraits = {
    params ["_ammo"];

    private _traits = KF_var_ammoTraits get _ammo;

    if (isNil "_traits") then {
        private _config = configFile >> "CfgAmmo" >> _ammo;
        private _submunition = _config >> "submunitionAmmo";

        _traits = [
            (getNumber (_config >> "indirectHit")) > 0,
            (isArray _submunition) || {(getText _submunition) != ""}
        ];
        KF_var_ammoTraits set [_ammo, _traits];
    };

    _traits
};

KF_fnc_trackProjectile = {
    params ["_projectile", "_context"];

    _projectile setVariable ["KF_var_hitContext", _context];
    _projectile addEventHandler ["HitPart", {call KF_fnc_onProjectileHitPart}];

    ([typeOf _projectile] call KF_fnc_getAmmoTraits) params ["_explodes", "_hasSubmunitions"];

    if (_explodes) then {
        _projectile addEventHandler ["HitExplosion", {call KF_fnc_onProjectileHitExplosion}];
    };

    if (_hasSubmunitions) then {
        _projectile addEventHandler ["SubmunitionCreated", {
            params ["_projectile", "_submunition"];

            [_submunition, _projectile getVariable "KF_var_hitContext"] call KF_fnc_trackProjectile;
        }];
    };
};

KF_fnc_onProjectileHitPart = {
    params ["_projectile", "_target", "", "", "", "", "_components"];

    [_projectile, _target, _components apply {[_x, true]}] call KF_fnc_queueHit;
};

KF_fnc_onProjectileHitExplosion = {
    params ["_projectile", "_target", "", "_components"];

    private _selections = [];

    {
        // the component's named selection(s), documented as a string while the entity HitPart gives an array
        private _names = _x select 2;

        if (_names isEqualType "") then {
            _names = [_names];
        };

        {
            _selections pushBackUnique [_x, false];
        } forEach _names;
    } forEach _components;

    [_projectile, _target, _selections] call KF_fnc_queueHit;
};

// Hits of the same shot type on the same target within a frame (direct hit and explosion of a shell, shotgun pellets)
// are merged; all hits of a frame go to the server in one message.
KF_fnc_queueHit = {
    params ["_projectile", "_target", "_selections"];

    if (isNull _target || {!(_target isKindOf "AllVehicles")} || {_target isKindOf "Animal"} || {!isDamageAllowed _target}) exitWith {};

    (_projectile getVariable "KF_var_hitContext") params ["_shooter", "_firer", "_magazine", "_source"];

    // explosives without a known owner (e.g. placed in the editor) count as self-inflicted
    if (isNull _shooter) then {
        _shooter = _target;
    };

    private _key = [_target, _shooter, typeOf _projectile, _magazine, _source];
    private _index = KF_var_pendingHits findIf {(_x select [0, 5]) isEqualTo _key};

    if (_index != -1) exitWith {
        private _pendingSelections = (KF_var_pendingHits select _index) select 6;

        {
            _pendingSelections pushBackUnique _x;
        } forEach _selections;
    };

    if (KF_var_pendingHits isEqualTo []) then {
        addMissionEventHandler ["EachFrame", {
            removeMissionEventHandler ["EachFrame", _thisEventHandler];
            [KF_var_pendingHits] remoteExecCall ["KF_fnc_onHits", 2];
            KF_var_pendingHits = [];
        }];
    };

    private _distance = if (isNull _firer || {_target isEqualTo _firer}) then {-1} else {_target distance _firer};

    KF_var_pendingHits pushBack (_key + [_distance, _selections, objNull, serverTime]);
};

// ---- damage without a projectile: "Hit" event handler on the victim's machine ----
// Collisions, crashes, falls, fire and drowning. The server drops ambiguous collision reports when the same hitter has a
// projectile hit on the victim around the same time, so vehicle weapons and own grenades keep their real cause.

// [hitter, kind ("vehHit", "vehExpl" or "fall"), source] or [] when the damage is not of such a kind
KF_fnc_getDamageWithoutProjectile = {
    params ["_unit", "_causedBy", "_instigator"];

    private _context = _unit getVariable ["KF_var_damageContext", [-10, "", objNull]];
    if (diag_frameNo - (_context select 0) <= 1 && {(_context select 1) != ""}) exitWith {[]};
    if (_unit isKindOf "CAManBase" && {isNull _causedBy || {_causedBy == _unit}}) exitWith {
        switch (true) do {
            case (isBurning _unit): {[_unit, "fire", ""]};
            case ((eyePos _unit select 2) < 0 && {getOxygenRemaining _unit < 0.1}): {[_unit, "drown", ""]};
            case (isNull objectParent _unit): {[_unit, "fall", ""]};
            default {[_unit, "vehExpl", typeOf vehicle _unit]};
        }
    };
    if (isNull _causedBy) exitWith {[]};
    if (_causedBy isKindOf "AllVehicles" && {!(_causedBy isKindOf "CAManBase")} && {isNull driver _causedBy}) exitWith {
        [_unit, ["vehExpl", "vehHit"] select alive _causedBy, typeOf _causedBy]
    };

    _instigator = [_causedBy, _instigator, _unit] call KF_fnc_getInstigator;

    if (unitIsUAV _causedBy) exitWith {
        if (_instigator isEqualTo _causedBy) then {[]} else {[_instigator, "vehHit", typeOf _causedBy]}
    };

    private _vehicle = objectParent _instigator;

    if (isNull _vehicle) exitWith {
        if ((_unit isEqualTo _causedBy) && {_unit isKindOf "CAManBase"}) then {[_unit, "fall", "Fall Damage"]} else {[]}
    };

    if (alive _vehicle && {!unitIsUAV _unit} && {(objectParent _unit) isNotEqualTo _vehicle}) exitWith {
        [_instigator, "vehHit", typeOf _vehicle]
    };

    [_instigator, "vehExpl", typeOf _vehicle]
};

// Call immediately BEFORE scripted lethal zone damage. Nonfatal ticks must not override a later weapon death.
KF_fnc_tagZoneDamage = {
    params ["_unit", ["_lethal", true]];
    if (_lethal) then {_unit setVariable ["KF_var_zoneDeath", serverTime, true]};
};

KF_fnc_onDamage = {
    params ["_unit", "_causedBy", "", "_instigator"];

    if (!isDamageAllowed _unit) exitWith {};

    private _damage = [_unit, _causedBy, _instigator] call KF_fnc_getDamageWithoutProjectile;

    if (_damage isEqualTo []) exitWith {};

    _damage params ["_hitter", "_kind", "_source"];

    private _distance = if (_unit isEqualTo _causedBy) then {-1} else {_unit distance _causedBy};

    [[[_unit, _hitter, _kind, "", _source, _distance, [], _causedBy, serverTime]]] remoteExecCall ["KF_fnc_onHits", 2];
};
