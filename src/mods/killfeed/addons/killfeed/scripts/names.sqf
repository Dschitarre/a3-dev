// Killfeed names (server): display names and pictures of units, weapons and vehicles, unit bookkeeping (name, side and
// controller of every unit kept up to date). Included by fnc_server.sqf.

// ---- names, display names and pictures ----

// [display name, picture, kind] of a weapon, vehicle, magazine or ammo class;
// kind: "vehicle", "grenadeLauncher", "launcher" or "weapon"
KF_fnc_getClassInfo = {
    params ["_class"];

    private _info = KF_var_classInfo get _class;

    if (isNil "_info") then {
        private _config = configNull;

        {
            if (isClass (configFile >> _x >> _class)) exitWith {
                _config = configFile >> _x >> _class;
            };
        } forEach ["CfgMagazines", "CfgAmmo", "CfgVehicles", "CfgWeapons"];

        private _kind = "weapon";

        if (isClass (configFile >> "CfgVehicles" >> _class)) then {
            _kind = "vehicle";
        } else {
            if (isClass (configFile >> "CfgWeapons" >> _class)) then {
                private _weaponType = ([_class] call BIS_fnc_itemType) select 1;

                if (_weaponType == "GrenadeLauncher") then {
                    _kind = "grenadeLauncher";
                };

                if (_weaponType in ["RocketLauncher", "MissileLauncher"]) then {
                    _kind = "launcher";
                };
            };
        };

        _info = [getText (_config >> "displayName"), getText (_config >> "picture"), _kind];
        KF_var_classInfo set [_class, _info];
    };

    _info
};

KF_fnc_getDisplayName = {
    params ["_class"];

    ([_class] call KF_fnc_getClassInfo) select 0
};

KF_fnc_getPicture = {
    params ["_class"];

    ([_class] call KF_fnc_getClassInfo) select 1
};

// size factor of a vehicle picture that makes the colored areas of all vehicle pictures equal (KF_var_vehiclePictureInfo,
// vehicleSymbols.sqf; key: lower case, no leading backslash, ".paa" when without extension); 1 for unknown pictures
KF_fnc_vehiclePictureScale = {
    params ["_picture"];

    private _key = toLowerANSI _picture;

    if ((_key select [0, 1]) == "\") then {
        _key = _key select [1];
    };

    if ((_key find ".") == -1) then {
        _key = _key + ".paa";
    };

    (KF_var_vehiclePictureInfo getOrDefault [_key, [2, 1]]) select 1
};

// the name shown in the feeds: "J. Doe (AI)" for AI, the vehicle name for UAVs
KF_fnc_getName = {
    params ["_unit"];

    private _aiSuffix = ["", KF_var_aiNameSuffix] select KF_var_showAiInNames;

    if (unitIsUAV _unit) exitWith {([typeOf _unit] call KF_fnc_getDisplayName) + _aiSuffix};

    private _name = name _unit;

    if (isPlayer _unit) exitWith {_name};

    private _words = _name splitString " ";

    if (count _words > 1) then {
        private _initials = (((_words select 0) splitString "-") select [0, 2]) apply {(_x select [0, 1]) + "."};
        _name = (_initials joinString "-") + " " + (_words select 1);
    };

    _name + _aiSuffix
};

// the name in its side's color key, cut and escaped (the clients highlight their own names by this exact text)
KF_fnc_nameTag = {
    params ["_name", "_side"];

    format ["<t color='%1'>%2</t>", [_side] call KF_fnc_sideColorKey, [_name] call KF_fnc_formatName]
};

KF_fnc_unitTag = {
    params ["_unit"];

    [_unit getVariable ["KF_var_name", "Error: no unit"], [_unit] call KF_fnc_unitSide] call KF_fnc_nameTag
};

// the side of a unit now (its group's side changes when it joins a group of another side); a dead unit keeps the side
// it had at its death
KF_fnc_unitSide = {
    params ["_unit"];

    if (alive _unit && {!isNull group _unit}) exitWith {side group _unit};

    _unit getVariable ["KF_var_side", sideUnknown]
};

// ---- units ----

KF_fnc_onEntityCreated = {
    params ["_entity"];

    if ((_entity isKindOf "CAManBase") || {unitIsUAV _entity}) then {
        [_entity] spawn KF_fnc_initEntityServer;
    };
};

KF_fnc_initEntityServer = {
    params ["_entity"];

    // the name of a new unit can be empty for a moment; KF_fnc_watchUnitsLoop initializes it once it has one
    private _timeout = time + 3;
    waitUntil {isNull _entity || {(name _entity) != ""} || {time > _timeout}};

    if (isNull _entity || {(name _entity) == ""}) exitWith {};

    [_entity] call KF_fnc_initUnit;
};

KF_fnc_initUnit = {
    params ["_unit"];

    // a respawned unit keeps the variables of its predecessor
    if (_unit getVariable ["KF_var_initDone", false]) exitWith {};

    _unit setVariable ["KF_var_initDone", true];
    _unit setVariable ["KF_var_killsInARow", 0];
    _unit setVariable ["KF_var_calledKilled", false];
    _unit setVariable ["KF_var_initTime", time];
    _unit setVariable ["KF_var_hits", []];

    [_unit] call KF_fnc_updateUnit;
    [_unit] call KF_fnc_addHandleScore;
};

// the shown name ("(AI)" while no player controls the unit) and the side of a unit
KF_fnc_updateNameAndSide = {
    params ["_unit"];

    if (!isNull group _unit) then {
        _unit setVariable ["KF_var_side", side group _unit];
    };

    private _nameSource = [name _unit, isPlayer _unit];

    if ((_nameSource select 0) != "" && {_nameSource isNotEqualTo (_unit getVariable ["KF_var_nameSource", []])}) then {
        _unit setVariable ["KF_var_nameSource", _nameSource];
        _unit setVariable ["KF_var_name", [_unit] call KF_fnc_getName, true];
    };
};

// A player can take over an AI unit and hand it back (the same unit object): the new controller starts without the
// kill streak and the hits of the old one (KF_var_controlTime also drops the hits the old one dealt).
KF_fnc_updateUnit = {
    params ["_unit"];

    private _isPlayer = isPlayer _unit;

    if (_isPlayer isNotEqualTo (_unit getVariable ["KF_var_isPlayer", _isPlayer])) then {
        _unit setVariable ["KF_var_killsInARow", 0];
        _unit setVariable ["KF_var_hits", []];
        _unit setVariable ["KF_var_controlTime", time];
    };

    _unit setVariable ["KF_var_isPlayer", _isPlayer];
    [_unit] call KF_fnc_updateNameAndSide;

    // up again (revived): the hits count from now on again (KF_fnc_hitsSince)
    private _downTime = _unit getVariable ["KF_var_downTime", -1];

    if (_downTime != -1 && {time - _downTime > 5} && {!([_unit] call KF_fnc_isDown)}) then {
        _unit setVariable ["KF_var_downTime", nil];
    };
};

// refreshes the living units every KF_var_unitCheckInterval seconds and initializes units that got their name late
KF_fnc_watchUnitsLoop = {
    waitUntil {
        {
            if (_x getVariable ["KF_var_initDone", false]) then {
                [_x] call KF_fnc_updateUnit;
            } else {
                if ((name _x) != "") then {
                    [_x] call KF_fnc_initUnit;
                };
            };
        } forEach (allUnits + allUnitsUAV);

        sleep KF_var_unitCheckInterval;
        false
    };
};

KF_fnc_entityRespawned = {
    params ["_newEntity", "_oldEntity"];

    _oldEntity setVariable ["KF_var_respawnedEntity", _newEntity];
    _newEntity setVariable ["KF_var_wasKilled", nil];
    _newEntity setVariable ["KF_var_calledKilled", false];
    _newEntity setVariable ["KF_var_downTime", nil];
    _newEntity setVariable ["KF_var_hits", []];
    _newEntity setVariable ["KF_var_zoneDeath", nil, true];
    _newEntity setVariable ["KF_var_damageContext", nil];

    // HandleScore does not stay on remote units after respawn
    if (_newEntity isKindOf "CAManBase") then {
        [_newEntity] call KF_fnc_addHandleScore;
    };
};

// the engine's scoring is disabled, kills add player scores instead (KF_fnc_addKillScores)
KF_fnc_addHandleScore = {
    params ["_unit"];

    [_unit, "HandleScore", {
        params ["_unit"];

        [_unit, "HandleScore", _thisEventHandler] call KF_fnc_isCurrentHandler;
        false
    }] call KF_fnc_setEventHandler;
};

// an initialized soldier or UAV (not the AI inside a UAV)
KF_fnc_unitIsValid = {
    params [["_unit", objNull]];

    !isNull _unit && {_unit getVariable ["KF_var_initDone", false]} && {!([_unit] call KF_fnc_isUavAi)}
};

KF_fnc_getRespawnedEntity = {
    params ["_entity"];

    private _next = _entity getVariable ["KF_var_respawnedEntity", objNull];

    while {!isNull _next} do {
        _entity = _next;
        _next = _entity getVariable ["KF_var_respawnedEntity", objNull];
    };

    _entity
};
