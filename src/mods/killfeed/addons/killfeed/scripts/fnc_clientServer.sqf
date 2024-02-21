KF_var_nextProjectileId = 0;

KF_fnc_getMineMagazine = {
    params ["_mine"];

    _mineConfig = configOf _mine;
    _mineMagazine = getText (_mineConfig >> "defaultMagazine");

    if (_mineMagazine == "") then {
        {
            _mineMagazine = getText (_x >> "defaultMagazine");

            if (_mineMagazine != "") exitWith {};
        } forEach ([_mineConfig] call BIS_fnc_returnParents);
    };

    _mineMagazine
};

KF_fnc_deregisterProjectile = {
    params ["_shooter", "_vehicle", "", "_projectileId"];

    _projectilesShooter = _shooter getVariable ["KF_var_firedProjectiles", []];
    _projectilesShooter deleteAt (_projectilesShooter findIf {(_x select 0) isEqualTo _projectileId});
    _shooter setVariable ["KF_var_firedProjectiles", _projectilesShooter];

    if !(isNull _vehicle) then {
        _projectilesVehicle = _vehicle getVariable ["KF_var_firedProjectiles", []];
        _projectilesVehicle deleteAt (_projectilesVehicle findIf {(_x select 0) isEqualTo _projectileId});
        _vehicle setVariable ["KF_var_firedProjectiles", _projectilesVehicle];
    };
};

KF_fnc_projectileDeleted = {
    params ["_projectile"];

    _shooter = _projectile getVariable ["KF_var_shooter", objNull];
    _vehicle = _projectile getVariable ["KF_var_vehicle", objNull];
    _timeUntilDeletion = _projectile getVariable ["KF_var_timeUntilDeletion", -1];
    _projectileId = _projectile getVariable ["KF_var_projectileId", -1];

    [_shooter, _vehicle, _timeUntilDeletion, _projectileId] spawn {
        params ["", "", "_timeUntilDeletion"];
        sleep _timeUntilDeletion;
        _this call KF_fnc_deregisterProjectile;
    };
};

KF_fnc_firedMan = {
    if (isNil {(_this select 6) getVariable "KF_var_shooter"}) then {
        params ["_unit", "_weapon", "", "", "_ammo", "_magazine", "_projectile", "_vehicle"];
        
        _vehicleType = typeOf _vehicle;

        if (isNull _projectile) then {
            _projectile = nearestObject [(if (isNull _vehicle) then {_unit} else {_vehicle}), _ammo];
        };

        _shooter = _unit;
        _shotParents = getShotParents _projectile;

        if !(_shotParents isEqualTo []) then {
            _shooter = _shotParents select 1;
        };

        ([_weapon] call BIS_fnc_itemType) params ["_weaponCategory", "_weaponType"];

        _timeUntilDeletion = if ((_weaponCategory == "Weapon") && {_weaponType == "Shotgun"}) then {10} else {2};
        
        _projectileId = KF_var_nextProjectileId;
        KF_var_nextProjectileId = KF_var_nextProjectileId + 1;

        _projectile setVariable ["KF_var_shooter", _shooter];
        _projectile setVariable ["KF_var_vehicle", _vehicle];
        _projectile setVariable ["KF_var_timeUntilDeletion", _timeUntilDeletion];
        _projectile setVariable ["KF_var_projectileId", _projectileId];

        _projectile addEventHandler ["Deleted", {_this call KF_fnc_projectileDeleted;}];

        _projectilesShooter = _shooter getVariable ["KF_var_firedProjectiles", []];
        _projectilesShooter pushBack [_projectileId, _projectile, _weapon, _ammo, _magazine, _vehicleType, objNull];
        _shooter setVariable ["KF_var_firedProjectiles", _projectilesShooter];

        if !(isNull _vehicle) then {
            _projectilesVehicle = _vehicle getVariable ["KF_var_firedProjectiles", []];
            _projectilesVehicle pushBack [_projectileId, _projectile, _weapon, _ammo, _magazine, _vehicleType, _shooter];
            _vehicle setVariable ["KF_var_firedProjectiles", _projectilesVehicle];
        };
    };
};

KF_fnc_isTypeUnmanned = {
    params ["_type"];

    ("UAV" in _type) || {"UGV" in _type}
};

KF_fnc_isUavAi = {
    params ["_unit"];

    "UAV_AI" in (typeOf _unit)
};

KF_fnc_UAVControl = {
    params ["_unit", "_mode", ["_altMode", ""]];
    _ret = objNull;

    _UAVControl = UAVControl _unit;
    _UAVControls = [_UAVControl select [0, 2]];

    if ((count _UAVControl) == 4) then {
        _UAVControls pushBack (_UAVControl select [2, 2]);
    };

    _pos = (_UAVControls apply {_x select 1}) find _mode;

    if (_pos != -1) then {
        _ret = (_UAVControls select _pos) select 0;
    } else {
        if (_altMode != "") then {
            _pos = (_UAVControls apply {_x select 1}) find _altMode;

            if (_pos != -1) then {
                _ret = (_UAVControls select _pos) select 0;
            };
        };
    };

    _ret
};

KF_fnc_HitPart = {
    params ["_target", "_shooter", "_bullet", "_selections", "_ammo"];
    
    _magazine = "";
    _distance = -1;
    _source = "";

    if (!(isNull _shooter) && {!(_target isEqualTo _shooter)}) then {
        _distance = _target distance _shooter;
    };

    if !(isNull _bullet) then {
        (getShotParents _bullet) params ["_vehicle", "_instigator"];

        if (_ammo == "") then {
            _ammo = typeOf _bullet;
        };

        if !(isNull _instigator) then {
            _shooter = _instigator;
        } else {
            if (!(isNull _vehicle) && {isNull _shooter}) then {
                _shooter = _vehicle;
            };
        };

        if (!(isNull _vehicle) && {!(_vehicle isKindOf "CAManBase")}) then {
            _source = typeOf _vehicle;
        };
    };

    if (_bullet isKindOf "TimeBombCore") then {
        if (isNull _shooter) then {
            _shooter = _target;
        };

        _magazine = [_bullet] call KF_fnc_getMineMagazine;
        _source = "Put";
    };

    if (isNull _shooter) exitWith {};

    _parOrParShooter = if (_shooter isKindOf "CAManBase") then {objectParent _shooter} else {_shooter};

    if ((unitIsUav _parOrParShooter) && {(_parOrParShooter isEqualTo _shooter) || {[_shooter] call KF_fnc_isUavAi}}) then {
        _source = typeOf _parOrParShooter;
        _uavCtrlVehicleShooter = [_parOrParShooter, "GUNNER", "DRIVER"] call KF_fnc_UAVControl;

        if (isNull _uavCtrlVehicleShooter) then {
            _shooter = _parOrParShooter;
        } else {
            _shooter = _uavCtrlVehicleShooter;
        };
    };

    if ((_distance == -1) && {!(isNull _parOrParShooter)} && {!(_target isEqualTo _parOrParShooter)})then {
        _distance = _target distance _parOrParShooter;
    };

    _shooterIsUnitOrUav = (_shooter isKindOf "CAManBase") || {unitIsUav _shooter};

    if ((_source == "") || {_ammo == ""} || {_magazine == ""} || {!_shooterIsUnitOrUav}) then {
        _projectiles = _shooter getVariable ["KF_var_firedProjectiles", []];

        if (!_shooterIsUnitOrUav && {!(_parOrParShooter isEqualTo _shooter)}) then {
            _projectiles = _projectiles + (_parOrParShooter getVariable ["KF_var_firedProjectiles", []]);
        };

        _uavUnitShooter = getConnectedUAVUnit _shooter;
    
        if !(isNull _uavUnitShooter) then {
            _projectiles = _projectiles + (_uavUnitShooter getVariable ["KF_var_firedProjectiles", []]);
        };

        _foundProjectile = [];

        if !(isNull _bullet) then {
            _pos = _projectiles findIf {(_shooterIsUnitOrUav || {!(isNull (_x select 6))}) && {!(isNull (_x select 1)) && {(_x select 1) isEqualTo _bullet}}};

            if (_pos != -1) then {
                _foundProjectile = _projectiles select _pos;
            };
        };

        if ((_foundProjectile isEqualTo []) && {_ammo != ""}) then {
            _pos = _projectiles findIf (if ("Bomb" in _ammo) then {
                {(_shooterIsUnitOrUav || {!(isNull (_x select 6))}) && {"Bomb" in (_x select 3)}};
            } else {
               {(_shooterIsUnitOrUav || {!(isNull (_x select 6))}) && {(_ammo in (_x select 3)) || {(_x select 3) in _ammo}}};
            });

            if (_pos != -1) then {
                _foundProjectile = _projectiles select _pos;
            };
        };

        if !(_foundProjectile isEqualTo []) then {
            _foundProjectile params ["", "", "_newWeapon", "_newAmmo", "_newMagazine", "_vehicleType", "_newShooter"];

            if (_source == "") then {
                if (_vehicleType != "") then {
                    _source = _vehicleType;
                } else {
                    _source = _newWeapon;
                };
            };

            if (_ammo == "") then {
                _ammo = _newAmmo;
            };

            if (_magazine == "") then {
                _magazine = _newMagazine;
            };

            if (!_shooterIsUnitOrUav && {!(isNull _newShooter)}) then {
                _shooter = _newShooter;
            };
        };
    };

    if ((_source != "") && {_ammo != ""} && {_magazine != ""} && {(_shooter isKindOf "CAManBase") || {unitIsUav _shooter}}) then {
        [_target, _shooter, _ammo, _magazine, _selections, _distance, _source] remoteExecCall ["KF_fnc_OnHit", 2];
    };
};

KF_fnc_GatherHitPart = {
    _target = objNull;
    _shooter = objNull;
    _bullet = objNull;
    _selections = [];
    _ammo = "";

    {
        if ((isNull _target) && {!(isNull (_x select 0))}) then {
            _target = _x select 0;
        };

        if ((isNull _shooter) && {!(isNull (_x select 1))}) then {
            _shooter = _x select 1;
        };

        if ((isNull _bullet) && {!(isNull (_x select 2))}) then {
            _bullet = _x select 2;
        };

        _isDirect = _x select 10;

        {
            _selections pushBackUnique [_x, _isDirect];
        } forEach (_x select 5);

        if ((_ammo == "") && {((_x select 6) select 4) != ""}) then {
            _ammo = (_x select 6) select 4;
        };
    } forEach _this;

    if (isDamageAllowed _target) then {
        [_target, _shooter, _bullet, _selections, _ammo] call KF_fnc_HitPart;
    };
};

KF_fnc_AddHitPartClientServer = {
    params ["_entity"];

    _id = _entity getVariable ["KF_var_hitPartEhId", -1];
    if (_id != -1) then {_entity removeEventHandler ["HitPart", _id]};
    _id = _entity addEventHandler ["HitPart", {_this call KF_fnc_GatherHitPart;}];
    _entity setVariable ["KF_var_hitPartEhId", _id];
};

KF_fnc_isVectorLessThan = {
    params ["_v1", "_v2"];

    _n = count _v1;
    _isLess = false;

    for "_i" from 0 to _n - 1 do {
        if (_v1 select _i < _v2 select _i) exitWith {
            _isLess = true;
        };
    };

    _isLess
};

KF_fnc_handleHeal = {
    params ["_entity"];

    _arr = getAllHitPointsDamage _entity;
    if (_arr isEqualTo []) exitWith {};
    _oldHitPointsDamage = _arr select 2;

    waitUntil {
        _arr = getAllHitPointsDamage _entity;
        if (_arr isEqualTo []) exitWith {true};

        if (!((_arr select 2) isEqualTo _oldHitPointsDamage) && {[(_arr select 2), _oldHitPointsDamage] call KF_fnc_isVectorLessThan}) exitWith {
            [_entity] remoteExecCall ["KF_fnc_entityHealed", 2];
            true
        };
        
        false
    };
};

KF_fnc_EntityInitClientServer = {
    params ["_entity"];

    if (isNil {_entity getVariable "KF_var_firedProjectiles"}) then {
        _entity setVariable ["KF_var_firedProjectiles", []];
    };
    
    _id = _entity getVariable ["KF_var_handleHealEhId", -1];
    if (_id != -1) then {_entity removeEventHandler ["HandleHeal", _id]};
    _id = _entity addEventHandler ["HandleHeal", {if (local (_this select 0)) then {_this spawn KF_fnc_handleHeal;}; false}];
    _entity setVariable ["KF_var_handleHealEhId", _id];

    if (_entity isKindOf "CAManBase") then {
        _id = _entity getVariable ["KF_var_firedManEhId", -1];
        if (_id != -1) then {_entity removeEventHandler ["FiredMan", _id]};
        _id = _entity addEventHandler ["FiredMan", {if (local (_this select 0)) then {_this call KF_fnc_firedMan;};}];
        _entity setVariable ["KF_var_firedManEhId", _id];

        _id = _entity getVariable ["KF_var_handleRatingEhId", -1];
        if (_id != -1) then {_entity removeEventHandler ["HandleRating", _id];};
        _id = _entity addEventHandler ["HandleRating", {0}];
        _entity setVariable ["KF_var_handleRatingEhId", _id];
    };

    [_entity] call KF_fnc_AddHitPartClientServer;
};

[] spawn {
    waitUntil {!(isNil "KF_var_running")};

    call {
        if KF_var_running then {
            {
                [_x] call KF_fnc_EntityInitClientServer;
            } forEach (entities [["AllVehicles"], ["Animal"], true, false]);
        };

        KF_var_clientServerInitDone = true;
    };
};